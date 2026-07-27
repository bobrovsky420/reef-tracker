import 'dart:async';

import 'package:reeftracker/data/hanna_meter_link.dart';
import 'package:reeftracker/domain/hanna_meter.dart';

/// The scripted stand-in for the Hanna checker's BLE transport, shared by the
/// session tests and the meter-screen widget tests — the override story
/// `hannaMeterLinkFactoryProvider` exists for.
const kFakeHannaInfo =
    'I,HI97115,06150128,FW,v1.07,nRF FW,v1.01,SN,906150128111,RCL,130,English,v5.0';
const kFakeHannaSetup =
    'GS,2069,0,0,backlight,50,contrast,50,tformat,24h,dformat,YYYY_MM_DD,'
    'decsep,dot,language,EN.LNG,beep,on,tutorial,on,BLE PAIR,locmax,10,';

/// A `…,R` result frame for [code] carrying [value] at meter time [ts]
/// (`yyyyMMddHHmmss`).
String hannaResultFrame(int code, String value, String ts) =>
    'M,$code, ,$value,0,200G2,0,06150128,$ts,STATUS,11,Z,R';

/// Answers every command the way the real meter did in the capture. Delivery
/// is asynchronous (plain broadcast controllers), matching real BLE — the
/// session reacts to a line by sending the next command, which must not
/// re-enter a dispatch in progress.
class FakeHannaMeterLink implements HannaMeterLink {
  final _lines = StreamController<String>.broadcast();
  final _disc = StreamController<void>.broadcast();
  final List<String> sent = [];

  /// Overrides keyed by exact command; anything absent uses [_autoReply].
  final Map<String, List<String>> replies = {};

  HannaLinkException? connectError;

  @override
  Stream<String> get lines => _lines.stream;

  @override
  Stream<void> get onDisconnected => _disc.stream;

  @override
  Future<String> connect() async {
    final err = connectError;
    if (err != null) throw err;
    return 'HI97115 06150128';
  }

  @override
  Future<void> send(String command) async {
    sent.add(command);
    for (final line in replies[command] ?? _autoReply(command)) {
      _lines.add(line);
    }
  }

  List<String> _autoReply(String cmd) {
    if (cmd == hannaCmdInfo) return const [kFakeHannaInfo];
    if (cmd.startsWith('set time')) return const ['ST,Ack'];
    if (cmd == hannaCmdGetBattery) return const ['GB,75,%'];
    if (cmd == hannaCmdGetSetup) return const [kFakeHannaSetup];
    if (cmd == hannaCmdGetTanks) return const ['GL,200G2,TANK2,TANK3,'];
    if (cmd == hannaCmdMeasOn) return const ['SM,Ack'];
    if (cmd == hannaCmdStart) return const ['SS,Ack'];
    if (cmd.startsWith('set setup method')) return const ['SD,Ack'];
    if (cmd == hannaCmdExit) return const ['SE,Ack'];
    return const [];
  }

  void emit(String line) => _lines.add(line);

  void dropConnection() => _disc.add(null);

  /// Kills the transport without announcing it: the next request fails as
  /// soon as it is sent, the way a meter that has gone to sleep or been
  /// walked off its measurement screen behaves.
  Future<void> goSilent() => _lines.close();

  @override
  Future<void> dispose() async {}
}
