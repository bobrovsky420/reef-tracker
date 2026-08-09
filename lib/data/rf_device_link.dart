// Transport for ReefFactory local devices: opens a WebSocket, performs the
// config→join handshake, and returns one decoded snapshot per manual refresh.
//
// A refresh is a transient connect-read-close (not a persistent subscription):
// it matches the "manual refresh" UX, disturbs nothing (the device tolerates
// several simultaneous clients — its own cloud app is usually connected too),
// and costs no battery between taps. Auto-refresh, when added later, just calls
// [RfDeviceLink.readOnce] on a timer.
//
// The link is abstracted so a fake can be injected in widget tests (mirrors
// `HannaMeterLink`); [RfWebSocketLink] is the real `dart:io` implementation.

import 'dart:async';
import 'dart:io';

import 'rf_protocol.dart';

/// Why a refresh failed — surfaced to the UI for a specific message rather than
/// a raw exception string.
enum RfLinkError {
  /// Couldn't reach the device (offline, wrong IP, different network).
  unreachable,

  /// Connected, but no readable value arrived in time.
  timeout,

  /// Connected and got a serial, but it's a model we don't parse yet.
  unsupportedModel,

  /// The frames arrived but didn't decode to the expected shape.
  protocol,
}

class RfLinkException implements Exception {
  const RfLinkException(this.error, [this.detail]);
  final RfLinkError error;
  final String? detail;
  @override
  String toString() => 'RfLinkException($error${detail == null ? '' : ': $detail'})';
}

abstract class RfDeviceLink {
  /// Connects to the device at [host], reads one live snapshot, and closes.
  /// Throws [RfLinkException] on any failure.
  Future<RfSnapshot> readOnce(String host);
}

/// What a ReefFactory device says about itself in the `refresh/config` reply,
/// before any model-specific `join`.
class RfIdentity {
  const RfIdentity({
    required this.serial,
    required this.modelPrefix,
    this.modelName,
    this.displayName,
  });

  /// The device's 16-character serial ("RFSG012110010070").
  final String serial;

  /// Its leading 6 characters, which identify the model ("RFSG01").
  final String modelPrefix;

  /// Internal and friendly model names — both null for a model this app has no
  /// parser for. Unlike [RfDeviceLink.readOnce], an unknown model is *not* an
  /// error here: LAN discovery reports it as found-but-unsupported.
  final String? modelName;
  final String? displayName;

  bool get supported => modelName != null;
}

/// The cheap identity-only probe LAN discovery uses: the `get/config`
/// handshake and nothing more — no `join`, no settings frame. Kept separate
/// from [RfDeviceLink] so the dashboard's test fakes don't have to implement it.
abstract class RfIdentityProbe {
  /// Reads just the identity of the device at [host]. Throws
  /// [RfLinkException] when the host isn't a ReefFactory device at all.
  Future<RfIdentity> identify(String host);
}

/// Real transport over `ws://<host>/controler`, subprotocol `arduino`, binary.
class RfWebSocketLink implements RfDeviceLink, RfIdentityProbe {
  const RfWebSocketLink({this.timeout = const Duration(seconds: 6)});

  final Duration timeout;

  @override
  Future<RfIdentity> identify(String host) async {
    final socket = await _connect(host);
    final result = Completer<RfIdentity>();

    late final StreamSubscription<dynamic> sub;
    sub = socket.listen(
      (data) {
        if (data is! List<int>) return;
        final frame = RfFrame.decode(data);
        if (frame.command != 'refresh' || frame.subcommand != 'config') return;
        final serial = readCString(frame.payload);
        // The serial is the discovery dedupe key *and* `Devices.identifier`,
        // the row's primary key. Anything shorter than a model prefix is not
        // an identity: it would hide the next such host behind the first, and
        // could never match a rediscovery of either. An *unknown* 16-character
        // prefix is a different matter and is still reported (unsupported).
        if (serial.length < 6) {
          if (!result.isCompleted) {
            result.completeError(
              const RfLinkException(RfLinkError.protocol, 'no usable serial'),
            );
          }
          return;
        }
        final spec = rfModelForSerial(serial);
        if (!result.isCompleted) {
          result.complete(
            RfIdentity(
              serial: serial,
              modelPrefix: serial.length >= 6 ? serial.substring(0, 6) : '',
              modelName: spec?.name,
              displayName: spec?.displayName,
            ),
          );
        }
      },
      onError: (Object e) {
        if (!result.isCompleted) {
          result.completeError(
            RfLinkException(RfLinkError.protocol, e.toString()),
          );
        }
      },
      onDone: () {
        if (!result.isCompleted) {
          result.completeError(
            const RfLinkException(RfLinkError.protocol, 'closed early'),
          );
        }
      },
      cancelOnError: true,
    );

    socket.add(RfFrame.encode(command: 'get', subcommand: 'config'));
    try {
      return await result.future.timeout(timeout);
    } on TimeoutException {
      throw const RfLinkException(RfLinkError.timeout);
    } finally {
      await sub.cancel();
      await socket.close();
    }
  }

  Future<WebSocket> _connect(String host) async {
    try {
      return await WebSocket.connect(
        'ws://$host/controler',
        protocols: const ['arduino'],
        // No permessage-deflate (#72). The HTTP links cap their responses, but
        // dart:io's WebSocket client has no max-message-size and buffers a
        // whole message *before* our listener sees it — there is no knob on
        // `WebSocket.connect` to bound that. Compression is negotiated **on**
        // by default, so leaving it enabled would hand a hostile host a
        // decompression multiplier on top; a ReefFactory settings frame is a
        // few hundred bytes of binary and gains nothing from deflate anyway.
        // What remains — a host that completes a correct handshake at
        // /controler and then streams — is bounded only by [timeout]'s
        // teardown, and is not reachable by accident.
        compression: CompressionOptions.compressionOff,
      ).timeout(timeout);
    } on TimeoutException {
      throw const RfLinkException(RfLinkError.unreachable, 'connect timed out');
    } catch (e) {
      throw RfLinkException(RfLinkError.unreachable, e.toString());
    }
  }

  @override
  Future<RfSnapshot> readOnce(String host) async {
    final socket = await _connect(host);

    final result = Completer<RfSnapshot>();
    RfModelSpec? spec;
    var deviceSerial = '';
    var joined = false;

    late final StreamSubscription<dynamic> sub;
    sub = socket.listen(
      (data) {
        // Binary frames arrive as List<int>; ignore any stray text frames.
        if (data is! List<int>) return;
        final frame = RfFrame.decode(data);

        if (frame.command == 'refresh' && frame.subcommand == 'config') {
          final serial = readCString(frame.payload);
          deviceSerial = serial;
          spec = rfModelForSerial(serial);
          if (spec == null) {
            if (!result.isCompleted) {
              result.completeError(
                RfLinkException(RfLinkError.unsupportedModel, serial),
              );
            }
            return;
          }
          if (!joined) {
            joined = true;
            socket.add(
              RfFrame.encode(
                command: spec!.connectCommand,
                subcommand: 'join',
                serial: serial,
                msgId: 'join',
                payload: [...serial.codeUnits, 0],
              ),
            );
          }
        } else if (spec != null &&
            frame.command == spec!.refreshCommand &&
            frame.subcommand == 'settings') {
          final serial = deviceSerial.isNotEmpty ? deviceSerial : frame.serial;
          final readings = spec!.parse(frame.payload);
          if (readings.isEmpty) {
            if (!result.isCompleted) {
              result.completeError(
                const RfLinkException(RfLinkError.protocol, 'empty payload'),
              );
            }
            return;
          }
          if (!result.isCompleted) {
            result.complete(
              RfSnapshot(
                serial: serial,
                modelPrefix: serial.length >= 6 ? serial.substring(0, 6) : '',
                modelName: spec!.name,
                modelDisplayName: spec!.displayName,
                readings: readings,
                thermal: spec!.parseThermal?.call(frame.payload),
              ),
            );
          }
        }
      },
      onError: (Object e) {
        if (!result.isCompleted) {
          result.completeError(RfLinkException(RfLinkError.protocol, e.toString()));
        }
      },
      onDone: () {
        if (!result.isCompleted) {
          result.completeError(
            const RfLinkException(RfLinkError.protocol, 'closed early'),
          );
        }
      },
      cancelOnError: true,
    );

    // Kick off the handshake exactly as the device's web client does on open.
    socket.add(RfFrame.encode(command: 'get', subcommand: 'config'));

    try {
      return await result.future.timeout(timeout);
    } on TimeoutException {
      throw const RfLinkException(RfLinkError.timeout);
    } finally {
      await sub.cancel();
      await socket.close();
    }
  }
}
