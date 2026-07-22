import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/database.dart';
import '../../domain/hanna_checker.dart';
import '../../domain/parameter_catalog.dart';
import '../../domain/setup_type.dart';
import '../../domain/seven_segment.dart';
import '../../domain/units.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../../widgets/experimental_chip.dart';
import '../../widgets/reef_card.dart';
import '../../widgets/reef_settings.dart';
import '../../widgets/reef_value_row.dart';
import '../../widgets/section_header.dart';
import 'scan_frame.dart';

/// Checker camera scan (U34, experimental): read a Hanna pocket checker's
/// seven-segment LCD with the camera and save the value as a measurement.
/// One route hosts the whole flow: model picker → live viewfinder (the
/// on-device [decodeSevenSegment] + a consecutive-frames agreement vote) →
/// confirm & save. Never auto-saves: the accepted readout is always shown
/// for confirmation first.
class CheckerScanScreen extends ConsumerStatefulWidget {
  const CheckerScanScreen({super.key});

  @override
  ConsumerState<CheckerScanScreen> createState() => _CheckerScanScreenState();
}

enum _ScanPhase { pick, scanning, confirm }

enum _CameraError { denied, unavailable, failed }

/// The viewfinder guide box: centered horizontally, sized to the shape of a
/// pocket checker's LCD window (~2.3:1) so "fit the display into the frame"
/// works in both dimensions — a wider box invites the case/bezel into the
/// decoded crop. The box height depends on the preview's aspect ratio, so
/// the rect is computed per frame; the overlay and [_decodeFrame] use the
/// same [_guideRect], which is what keeps them aligned.
const _guideWidthFrac = 0.62;
const _guideLcdAspect = 2.3;
const _guideCenterY = 0.44;

/// [previewAspect] is the upright (as-displayed) preview aspect, w/h.
FracRect _guideRect(double previewAspect) {
  final heightFrac = _guideWidthFrac * previewAspect / _guideLcdAspect;
  return (
    left: (1 - _guideWidthFrac) / 2,
    top: _guideCenterY - heightFrac / 2,
    right: (1 + _guideWidthFrac) / 2,
    bottom: _guideCenterY + heightFrac / 2,
  );
}

class _CheckerScanScreenState extends ConsumerState<CheckerScanScreen>
    with WidgetsBindingObserver {
  _ScanPhase _phase = _ScanPhase.pick;
  HannaChecker? _checker;

  CameraController? _controller;
  _CameraError? _cameraError;
  final _vote = SevenSegmentVote();
  bool _decoding = false;
  DateTime _lastDecode = DateTime.fromMillisecondsSinceEpoch(0);

  /// Raw decode of the most recent readable frame — live feedback under the
  /// guide box so the user sees the decoder locking on.
  SevenSegmentReading? _candidate;

  SevenSegmentReading? _reading;
  int? _saveTankOverride;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controller?.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The camera must be released when the app goes to background and
    // reacquired on return (the camera plugin's documented lifecycle).
    if (state == AppLifecycleState.inactive) {
      unawaited(_stopCamera());
    } else if (state == AppLifecycleState.resumed &&
        _phase == _ScanPhase.scanning &&
        _controller == null) {
      unawaited(_startCamera());
    }
  }

  // --- camera ----------------------------------------------------------------

  Future<void> _startCamera() async {
    setState(() {
      _phase = _ScanPhase.scanning;
      _cameraError = null;
      _candidate = null;
      _reading = null;
      _vote.reset();
    });
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _cameraError = _CameraError.unavailable);
        return;
      }
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted || _phase != _ScanPhase.scanning) {
        await controller.dispose();
        return;
      }
      _controller = controller;
      await controller.startImageStream(_onFrame);
      if (mounted) setState(() {});
    } on CameraException catch (e) {
      if (mounted) {
        setState(
          () => _cameraError = e.code.contains('AccessDenied')
              ? _CameraError.denied
              : _CameraError.failed,
        );
      }
    } catch (_) {
      if (mounted) setState(() => _cameraError = _CameraError.failed);
    }
  }

  Future<void> _stopCamera() async {
    final controller = _controller;
    _controller = null;
    if (mounted) setState(() {});
    await controller?.dispose();
  }

  void _onFrame(CameraImage image) {
    if (_decoding || _phase != _ScanPhase.scanning || _checker == null) return;
    // ~6 fps is plenty for a static readout and keeps the UI thread light.
    final now = DateTime.now();
    if (now.difference(_lastDecode) < const Duration(milliseconds: 160)) {
      return;
    }
    _lastDecode = now;
    _decoding = true;
    try {
      final reading = _decodeFrame(image);
      // Only readouts in the selected model's exact display format (decimal
      // position + range) count toward acceptance — a glare misread or the
      // wrong checker can't win the vote.
      if (reading != null && _checker!.matches(reading)) {
        _vote.add(reading);
      }
      final winner = _vote.winner;
      if (winner != null) {
        _reading = winner;
        _phase = _ScanPhase.confirm;
        // Deferred: disposing the controller from inside its own image
        // stream callback is unsafe on some devices.
        unawaited(Future(_stopCamera));
        return;
      }
      if (reading?.text != _candidate?.text && mounted) {
        setState(() => _candidate = reading);
      }
    } finally {
      _decoding = false;
    }
  }

  SevenSegmentReading? _decodeFrame(CameraImage image) {
    final controller = _controller;
    if (controller == null) return null;
    final turns = (controller.description.sensorOrientation ~/ 90) & 3;
    // The guide box is drawn over the preview; the analysis stream may have
    // a different aspect ratio — correct the fractions so both look at the
    // same part of the scene.
    final analysisAspect = turns.isOdd
        ? image.height / image.width
        : image.width / image.height;
    final rect = adjustForAnalysisAspect(
      _guideRect(1 / controller.value.aspectRatio),
      1 / controller.value.aspectRatio,
      analysisAspect,
    );
    final crop = mapUprightRectToImage(
      rect.left,
      rect.top,
      rect.right,
      rect.bottom,
      image.width,
      image.height,
      turns,
    );
    final plane = image.planes.first;
    final gray = switch (image.format.group) {
      // The first plane is luma in every YUV layout.
      ImageFormatGroup.yuv420 ||
      ImageFormatGroup.nv21 => grayFromLumaPlane(
        plane.bytes,
        plane.bytesPerRow,
        crop,
      ),
      ImageFormatGroup.bgra8888 => grayFromBgraPlane(
        plane.bytes,
        plane.bytesPerRow,
        crop,
      ),
      _ => null,
    };
    return gray == null ? null : decodeSevenSegment(gray);
  }

  // --- build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PopScope(
      // Back from the viewfinder or the confirm step returns to the model
      // picker instead of leaving the flow.
      canPop: _phase == _ScanPhase.pick,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(_stopCamera());
        setState(() => _phase = _ScanPhase.pick);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(l.hannaScanTitle, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              const ExperimentalChip(),
            ],
          ),
        ),
        body: switch (_phase) {
          _ScanPhase.pick => _pickView(l),
          _ScanPhase.scanning => _scanView(l),
          _ScanPhase.confirm => _confirmView(l),
        },
      ),
    );
  }

  // --- model picker ----------------------------------------------------------

  String _checkerLabel(AppLocalizations l, HannaChecker c) {
    final name = l.paramName(c.paramKey);
    return c.tag == null
        ? '${c.model} · $name'
        : '${c.model} · $name ${c.tag}';
  }

  String _checkerRange(HannaChecker c) =>
      '${c.min.toStringAsFixed(c.decimals)}–'
      '${c.max.toStringAsFixed(c.decimals)} ${c.unit}';

  Widget _pickView(AppLocalizations l) {
    final tokens = ReefTokens.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
          child: Text(
            l.hannaScanPickHint,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: tokens.textDim),
          ),
        ),
        SectionHeader(l.hannaScanPickTitle),
        ReefCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              for (final c in kHannaCheckers)
                ListTile(
                  dense: true,
                  title: Text(
                    _checkerLabel(l, c),
                    style: TextStyle(fontSize: 15, color: tokens.text),
                  ),
                  subtitle: Text(
                    _checkerRange(c),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: tokens.textDim),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: tokens.textFaint,
                  ),
                  onTap: () {
                    _checker = c;
                    unawaited(_startCamera());
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // --- viewfinder ------------------------------------------------------------

  Widget _scanView(AppLocalizations l) {
    final tokens = ReefTokens.of(context);
    final error = _cameraError;
    if (error != null) {
      final message = switch (error) {
        _CameraError.denied => l.hannaScanCameraDenied,
        _CameraError.unavailable => l.hannaScanNoCamera,
        _CameraError.failed => l.hannaScanCameraFailed,
      };
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.no_photography_outlined, size: 40, color: tokens.textDim),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: tokens.text),
              ),
              const SizedBox(height: 24),
              if (error != _CameraError.unavailable)
                FilledButton.icon(
                  onPressed: () => unawaited(_startCamera()),
                  icon: const Icon(Icons.refresh),
                  label: Text(l.hannaTryAgain),
                ),
            ],
          ),
        ),
      );
    }

    final controller = _controller;
    final checker = _checker!;
    return Column(
      children: [
        Expanded(
          child: controller == null || !controller.value.isInitialized
              ? const Center(child: CircularProgressIndicator())
              : Center(
                  child: AspectRatio(
                    aspectRatio: 1 / controller.value.aspectRatio,
                    child: LayoutBuilder(
                      builder: (context, box) {
                        // The guide box — the exact region the decoder
                        // crops (same _guideRect).
                        final guide = _guideRect(
                          1 / controller.value.aspectRatio,
                        );
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            CameraPreview(controller),
                            Positioned(
                              left: box.maxWidth * guide.left,
                              top: box.maxHeight * guide.top,
                              width:
                                  box.maxWidth * (guide.right - guide.left),
                              height:
                                  box.maxHeight * (guide.bottom - guide.top),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: tokens.caution,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                _checkerLabel(l, checker),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: tokens.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${l.hannaScanGuide} · ${l.hannaScanGlareHint}',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: tokens.textDim),
              ),
              const SizedBox(height: 8),
              // Live decode feedback: what the last readable frame said.
              // The unit only appears once the readout matches the selected
              // model's display format — a stray misread (wrong decimal
              // position, out of range) shows dimmed, digits only.
              Builder(
                builder: (_) {
                  final cand = _candidate;
                  final matches = cand != null && checker.matches(cand);
                  return SizedBox(
                    height: 28,
                    child: Text(
                      cand == null
                          ? '· · ·'
                          : matches
                          ? '${cand.text} ${checker.unit}'
                          : cand.text,
                      style: ReefTokens.monoTextStyle.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: matches ? tokens.text : tokens.textFaint,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- confirm ---------------------------------------------------------------

  double get _canonicalValue => _reading!.value * _checker!.factor;

  Widget _confirmView(AppLocalizations l) {
    final tokens = ReefTokens.of(context);
    final checker = _checker!;
    final reading = _reading!;
    final prefs = ref.watch(unitPrefsProvider);
    final tanks = ref.watch(tanksProvider).value ?? const <Tank>[];
    final tank = tanks.isEmpty ? null : _resolveSaveTank(tanks);

    final def = kParameterByKey[checker.paramKey];
    final pres = presentationForKey(checker.paramKey, def?.unit ?? '', prefs);
    final canonical = _canonicalValue;
    final raw = '${reading.text} ${checker.unit}';
    final presented = '${pres.format(canonical)} ${pres.unitLabel}';
    final check = checkParamValue(checker.paramKey, canonical);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ReefCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _checkerLabel(l, checker),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: tokens.text,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    raw,
                    style: ReefTokens.monoTextStyle.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: tokens.text,
                    ),
                  ),
                  if (presented != raw) ...[
                    const SizedBox(width: 12),
                    Text(
                      '= $presented',
                      style: ReefTokens.monoTextStyle.copyWith(
                        fontSize: 16,
                        color: tokens.textDim,
                      ),
                    ),
                  ],
                ],
              ),
              if (check != ParamValueCheck.ok)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 18,
                        color: check == ParamValueCheck.impossible
                            ? tokens.critical
                            : tokens.caution,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          check == ParamValueCheck.impossible
                              ? l.hannaScanImpossibleNote
                              : l.hannaScanImplausibleNote,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: tokens.textDim),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (tank != null) ...[
          SectionHeader(l.hannaSaveTo),
          ReefCard(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
            child: Row(
              children: [
                const ReefIconChip(Icons.waves),
                const SizedBox(width: 12),
                Expanded(
                  child: ReefSettingsDropdown<int>(
                    value: tank.id,
                    enabled: !_saving,
                    items: [for (final t in tanks) (t.id, t.name)],
                    onChanged: (id) => setState(() => _saveTankOverride = id),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed:
              _saving || tank == null || check == ParamValueCheck.impossible
              ? null
              : () => unawaited(_save(tank)),
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_done),
          label: Text(l.hannaSaveButton(1)),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _saving ? null : () => unawaited(_startCamera()),
          icon: const Icon(Icons.photo_camera_outlined, size: 18),
          label: Text(l.hannaScanRescan),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Tank _resolveSaveTank(List<Tank> tanks) {
    for (final t in tanks) {
      if (t.id == _saveTankOverride) return t;
    }
    return ref.read(activeTankProvider) ?? tanks.first;
  }

  Future<void> _save(Tank tank) async {
    final l = AppLocalizations.of(context);
    final checker = _checker!;
    final canonical = _canonicalValue;

    // Same #31 sanity gate as the BLE flow: implausible needs an explicit
    // confirm (impossible never reaches here — the button is disabled).
    if (checkParamValue(checker.paramKey, canonical) ==
        ParamValueCheck.implausible) {
      final proceed = await _confirmImplausible(l, checker, canonical);
      if (proceed != true || !mounted) return;
    }

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final db = ref.read(dbProvider);
    try {
      await db.addTrackedParameter(
        tank.id,
        checker.paramKey,
        SetupType.fromName(tank.setupType),
      );
      await db.insertReadingGroup(
        tankId: tank.id,
        takenAt: DateTime.now(),
        values: [(paramKey: checker.paramKey, value: canonical)],
      );
      messenger.showSnackBar(SnackBar(content: Text(l.hannaSavedSnack(1))));
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l.saveFailed(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool?> _confirmImplausible(
    AppLocalizations l,
    HannaChecker checker,
    double canonical,
  ) {
    final def = kParameterByKey[checker.paramKey];
    if (def?.plausibleMin == null || def?.plausibleMax == null) {
      return Future.value(true);
    }
    final prefs = ref.read(unitPrefsProvider);
    final pres = presentationForKey(def!.key, def.unit, prefs);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.implausibleTitle),
        content: Text(
          '${l.implausibleIntro}\n\n'
          '${l.implausibleValueLine(l.paramName(def.key), '${pres.format(canonical)} ${pres.unitLabel}', pres.format(def.plausibleMin!), '${pres.format(def.plausibleMax!)} ${pres.unitLabel}')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.saveAnyway),
          ),
        ],
      ),
    );
  }
}
