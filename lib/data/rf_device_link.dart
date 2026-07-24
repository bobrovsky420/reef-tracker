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

/// Real transport over `ws://<host>/controler`, subprotocol `arduino`, binary.
class RfWebSocketLink implements RfDeviceLink {
  const RfWebSocketLink({this.timeout = const Duration(seconds: 6)});

  final Duration timeout;

  @override
  Future<RfSnapshot> readOnce(String host) async {
    WebSocket socket;
    try {
      socket = await WebSocket.connect(
        'ws://$host/controler',
        protocols: const ['arduino'],
      ).timeout(timeout);
    } on TimeoutException {
      throw const RfLinkException(RfLinkError.unreachable, 'connect timed out');
    } catch (e) {
      throw RfLinkException(RfLinkError.unreachable, e.toString());
    }

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
