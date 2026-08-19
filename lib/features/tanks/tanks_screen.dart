import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/database.dart';
import '../../domain/clock.dart';
import '../../domain/health_score.dart';
import '../../domain/pro_features.dart';
import '../../domain/setup_type.dart';
import '../../domain/units.dart';
import '../../domain/zones.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../../widgets/pro_feature_dialog.dart';
import '../../widgets/reef_card.dart';
import '../../widgets/reef_menu.dart';
import '../../widgets/reef_value_row.dart';
import '../../widgets/tank_health_badge.dart';
import '../../widgets/zone_visuals.dart';

/// Lists all aquariums with add / edit / delete / switch actions, each row
/// carrying that tank's status (U7 overview).
///
/// Layout per REDESIGN #19: the tanks collapse into one `ReefCard` of
/// hairline-divided rows (#11 row pattern) — health ring, name + active tag,
/// "volume · type · date" sub with mono numerals, a freshness line, trailing
/// overflow menu. Tapping a row activates that tank and returns to wherever
/// the screen was opened from.
class TanksScreen extends ConsumerWidget {
  const TanksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final tanksAsync = ref.watch(tanksProvider);
    final overviewAsync = ref.watch(tanksOverviewProvider);
    final active = ref.watch(activeTankProvider);
    final volumeUnit = ref.watch(unitPrefsProvider).volume;
    // A user who switched the health score off (Settings → Dashboard) gets the
    // plain waves glyph back; the freshness line is not a score and stays.
    final showRing =
        (ref.watch(healthDisplayProvider).value ?? HealthDisplay.both)
            .showBadge;

    return Scaffold(
      appBar: AppBar(title: Text(l.aquariums)),
      body: overviewAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l.errorWith(e.toString()))),
        data: (overviews) {
          if (overviews.isEmpty) {
            return Center(child: Text(l.noAquariumsYet));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            children: [
              ReefCard(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: Column(
                  children: [
                    for (var i = 0; i < overviews.length; i++)
                      _row(
                        context,
                        ref,
                        l,
                        overviews[i],
                        volumeUnit,
                        showRing: showRing,
                        isActive: overviews[i].tank.id == active?.id,
                        isLast: i == overviews.length - 1,
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      // The tank cap (U21): a Standard install may hold at most kFreeTankLimit
      // live tanks — Pro/Founder lifts it. Gated at creation only, so tanks
      // beyond the cap (restored backup) stay fully usable. A still-loading
      // list counts as zero tanks, so the button stays enabled; _save() holds
      // the authoritative check.
      floatingActionButton: FloatingActionButton.extended(
        onPressed:
            canCreateTank(
              tanksAsync.value?.length ?? 0,
              unlimitedTanks: ref.watch(
                proCapabilityProvider(
                  ProCapabilityBoundary.unlimitedTankCreate,
                ),
              ),
            )
            ? () => context.push('/tanks/new')
            // Not `runProCapabilityGated`: the cap is a *count* check, not a plain gate,
            // so entitlement alone doesn't decide this button. Unlocking lifts
            // the cap, so the form is where the user wanted to be either way.
            : () async {
                if (await requestProCapability(
                      context,
                      ref,
                      ProCapabilityBoundary.unlimitedTankCreate,
                      body: l.tankLimitBody(kFreeTankLimit),
                    ) &&
                    context.mounted) {
                  await context.push('/tanks/new');
                }
              },
        icon: const Icon(Icons.add),
        label: Text(l.addAquarium),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
    TankOverview overview,
    VolumeUnit volumeUnit, {
    required bool showRing,
    required bool isActive,
    required bool isLast,
  }) {
    final t = overview.tank;
    final tokens = ReefTokens.of(context);
    final type = SetupType.fromName(t.setupType);
    // "volume · type · date" (§A.6 sub line): numeric spans in mono.
    const sep = TextSpan(text: ' · ');
    final mono = ReefTokens.monoTextStyle.copyWith(fontSize: 12);
    final sub = TextSpan(
      style: TextStyle(fontSize: 12, color: tokens.textDim),
      children: [
        if (t.volumeLiters != null) ...[
          TextSpan(
            text: l.volumeWithUnit(t.volumeLiters!, volumeUnit),
            style: mono,
          ),
          sep,
        ],
        TextSpan(text: l.setupLabel(type)),
        // The bare start date, no "since" — with the freshness line right
        // below it, the qualifier only cost width and pushed the year onto a
        // second line on a phone.
        if (t.startDate != null) ...[
          sep,
          TextSpan(text: DateFormat.yMMMd().format(t.startDate!), style: mono),
        ],
      ],
    );

    final health = overview.health;
    final ringColor = health.band.colorOf(context);

    // The rows ripple on the card's own Material (the InkWell ancestor).
    return InkWell(
      // Picking a tank is the point of this screen: activate and hand the user
      // back to where they came from (the app-bar selector, or Settings).
      // The overflow menu's "Make active" deliberately stays put — someone
      // mid-management shouldn't be thrown off the screen.
      onTap: () async {
        await ref.read(dbProvider).setActiveTank(t.id);
        if (context.mounted && context.canPop()) context.pop();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
        decoration: isLast
            ? null
            : BoxDecoration(
                border: Border(bottom: BorderSide(color: tokens.surfaceBorder)),
              ),
        child: Row(
          children: [
            if (showRing)
              Semantics(
                label:
                    '${l.healthTitle}: ${l.healthGradeLabel(health.grade)}'
                    '${health.hasData ? ', ${l.healthScoreOf(health.score!)}' : ''}',
                child: ScoreRing.withScore(
                  score: health.score,
                  color: ringColor,
                  size: 40,
                  stroke: 4,
                ),
              )
            else
              Icon(Icons.waves, size: 18, color: tokens.textDim),
            const SizedBox(width: 12),
            Expanded(
              // One node for the three text lines, so a screen reader announces
              // "<name>, active, 450 L · Mixed reef, last tested 2 d ago" in one
              // go; the ring and the overflow menu keep their own nodes.
              child: MergeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            t.name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: tokens.text,
                            ),
                          ),
                        ),
                        if (isActive) ...[
                          const SizedBox(width: 8),
                          _ActiveTag(label: l.active),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text.rich(sub),
                    const SizedBox(height: 2),
                    _LastTestedLine(lastTestedAt: overview.lastTestedAt),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            ReefMenuButton<String>(
              icon: Icons.more_vert,
              onSelected: (v) async {
                switch (v) {
                  case 'activate':
                    await ref.read(dbProvider).setActiveTank(t.id);
                  case 'edit':
                    unawaited(context.push('/tanks/${t.id}/edit', extra: t));
                  case 'delete':
                    await _confirmDelete(context, ref, t);
                }
              },
              entries: [
                if (!isActive)
                  ReefMenuItem(
                    value: 'activate',
                    icon: Icons.check_circle_outline,
                    label: l.makeActive,
                  ),
                ReefMenuItem(
                  value: 'edit',
                  icon: Icons.edit_outlined,
                  label: l.edit,
                ),
                ReefMenuItem(
                  value: 'delete',
                  icon: Icons.delete_outline,
                  label: l.delete,
                  destructive: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Tank tank,
  ) async {
    final l = AppLocalizations.of(context);
    final db = ref.read(dbProvider);
    final messenger = ScaffoldMessenger.of(context);
    final wasActive = ref.read(activeTankProvider)?.id == tank.id;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteTankTitle(tank.name)),
        content: Text(l.deleteTankBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    // Soft delete + undo SnackBar (U10): the rows survive in SQLite for the
    // SnackBar's lifetime, so the biggest possible loss in the app stays
    // reversible past the confirm dialog.
    await db.softDeleteTank(tank.id);
    messenger.clearSnackBars();
    final controller = messenger.showSnackBar(
      SnackBar(
        content: Text(l.tankDeleted(tank.name)),
        // An action makes a SnackBar persist by default; this one must
        // auto-close — its close is what finalizes the hard delete below.
        persist: false,
        duration: const Duration(seconds: 7),
        action: SnackBarAction(
          label: l.undo,
          onPressed: () async {
            final restored = await db.restoreTank(tank.id);
            // Hand the active slot back only if the row still existed (a
            // backup restore during the window replaces all tanks).
            if (restored && wasActive) await db.setActiveTank(tank.id);
          },
        ),
      ),
    );
    // The grace period is the SnackBar's lifetime: any close other than the
    // Undo tap finalizes the delete. hardDeleteTank only touches soft-deleted
    // rows, so a stale callback can't remove a live tank reusing the id. A
    // process kill before this fires is collected by the startup purge sweep.
    final reason = await controller.closed;
    if (reason != SnackBarClosedReason.action) {
      await db.hardDeleteTank(tank.id);
    }
  }
}

/// Tag marking the currently active aquarium (§A.6 tag geometry:
/// 11 w600, padding 4·10, r10 — `healthySoft` fill, `primary` text).
class _ActiveTag extends StatelessWidget {
  const _ActiveTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = ReefTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tokens.healthySoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: tokens.primary,
        ),
      ),
    );
  }
}

/// The freshness line of an aquarium row (U7): when one of the tank's **core**
/// parameters was last measured.
///
/// Under a week it reads as elapsed time ("Last tested 2 d ago"); past that a
/// relative label would decay into a bare date, so it switches to the health
/// sheet's own "Not tested in N d" wording — the elapsed span is the point.
/// It turns amber once the newest reading passes [kHealthFreshnessDays], the
/// exact moment the health score stops trusting it, so the colour change and
/// the ring going grey always happen together.
class _LastTestedLine extends StatelessWidget {
  const _LastTestedLine({required this.lastTestedAt});

  final DateTime? lastTestedAt;

  /// Below this the label stays relative ("2 d ago"); above it the elapsed
  /// span is spelled out instead ([relativeTimeLabel] falls back to an
  /// absolute date at exactly this age).
  static const int _relativeDays = 7;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tokens = ReefTokens.of(context);
    final at = lastTestedAt;

    final String text;
    final Color color;
    if (at == null) {
      text = l.healthNeverTested;
      color = tokens.textFaint;
    } else {
      final days = daysSince(at);
      if (days > kHealthFreshnessDays) {
        text = l.healthNotTestedDays(days);
        color = Zone.amber.colorOf(context);
      } else if (days >= _relativeDays) {
        text = l.healthNotTestedDays(days);
        color = tokens.textDim;
      } else {
        text = l.lastTestedAgo(relativeTimeLabel(l, at));
        color = tokens.textDim;
      }
    }

    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 12, color: color),
    );
  }
}

/// Create or edit a tank. Pass an existing [Tank] as `extra` to edit.
class TankEditScreen extends ConsumerStatefulWidget {
  const TankEditScreen({super.key, this.tank});

  final Tank? tank;

  @override
  ConsumerState<TankEditScreen> createState() => _TankEditScreenState();
}

class _TankEditScreenState extends ConsumerState<TankEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: widget.tank?.name ?? '',
  );
  late final TextEditingController _vendor = TextEditingController(
    text: widget.tank?.vendor ?? '',
  );
  late final TextEditingController _model = TextEditingController(
    text: widget.tank?.model ?? '',
  );
  late final TextEditingController _notes = TextEditingController(
    text: widget.tank?.notes ?? '',
  );
  late final TextEditingController _volume;
  late SetupType _type = widget.tank != null
      ? SetupType.fromName(widget.tank!.setupType)
      : SetupType.mixed;
  late DateTime? _startDate = widget.tank?.startDate;
  bool _saving = false;

  /// The volume unit captured when the screen opened, used for both the
  /// initial field value and the conversion back to canonical litres on save.
  late final VolumeUnit _volumeUnit = ref.read(unitPrefsProvider).volume;

  bool get _isEdit => widget.tank != null;

  @override
  void initState() {
    super.initState();
    final liters = widget.tank?.volumeLiters;
    _volume = TextEditingController(
      text: liters == null ? '' : formatVolume(liters, _volumeUnit),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _vendor.dispose();
    _model.dispose();
    _notes.dispose();
    _volume.dispose();
    super.dispose();
  }

  /// Trims [text] and returns null when nothing is left, so optional
  /// free-text fields are stored as NULL rather than empty strings.
  String? _trimToNull(String text) {
    final t = text.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) setState(() => _startDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    final db = ref.read(dbProvider);
    final typed = parseUserDouble(_volume.text);
    final volume = typed == null ? null : volumeToCanonical(typed, _volumeUnit);
    try {
      if (_isEdit) {
        await db.updateTank(
          widget.tank!.copyWith(
            name: _name.text.trim(),
            setupType: _type.name,
            volumeLiters: Value(volume),
            startDate: Value(_startDate),
            notes: Value(_trimToNull(_notes.text)),
            vendor: Value(_trimToNull(_vendor.text)),
            model: Value(_trimToNull(_model.text)),
          ),
        );
      } else {
        // Authoritative tank-cap check (U21). The FAB gate is only cosmetic —
        // deep links and restored routes reach this screen without it.
        final unlimited = ref.read(
          proCapabilityProvider(ProCapabilityBoundary.unlimitedTankCreate),
        );
        final tankCount = (await db.getTanks()).length;
        if (!canCreateTank(tankCount, unlimitedTanks: unlimited)) {
          if (!mounted) return;
          // Falls through to the create when the user unlocks from here —
          // otherwise they would have to retype the form they just filled in.
          if (!await requestProCapability(
            context,
            ref,
            ProCapabilityBoundary.unlimitedTankCreate,
            body: l.tankLimitBody(kFreeTankLimit),
          )) {
            return;
          }
          if (!mounted) return;
        }
        await db.createTankWithPreset(
          name: _name.text.trim(),
          type: _type,
          volumeLiters: volume,
          startDate: _startDate,
          notes: _trimToNull(_notes.text),
          vendor: _trimToNull(_vendor.text),
          model: _trimToNull(_model.text),
        );
      }
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? l.editAquarium : l.newAquarium)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: InputDecoration(
                labelText: l.name,
                hintText: l.nameHint,
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l.enterAName : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<SetupType>(
              initialValue: _type,
              decoration: InputDecoration(labelText: l.setupType),
              items: [
                for (final t in SetupType.values)
                  DropdownMenuItem(value: t, child: Text(l.setupLabel(t))),
              ],
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: 8),
            if (!_isEdit)
              Text(
                l.presetSeedNote,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            // Switching an existing tank to fish-only silently strips the
            // zone colouring from Alk/Ca/Mg/PO₄ (the preset defines no
            // bounds for them and #82 resolves bounds on read) — warn at
            // the moment of choice. Create mode needs no warning: those
            // parameters aren't tracked by default there at all.
            if (_isEdit && _type == SetupType.fishOnly)
              Text(
                l.fishOnlyPresetNote,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _volume,
              style: ReefTokens.monoInputStyle,
              decoration: InputDecoration(
                labelText: l.volumeOptional,
                suffixText: _volumeUnit.symbol,
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (v) {
                // Optional field: blank is fine, but a non-empty entry must be
                // a finite positive number.
                if (v == null || v.trim().isEmpty) return null;
                final parsed = parseUserDouble(v);
                return (parsed == null || parsed <= 0) ? l.invalidVolume : null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _vendor,
              decoration: InputDecoration(labelText: l.vendorOptional),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _model,
              decoration: InputDecoration(labelText: l.modelOptional),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            // Start date as the #12 footer pattern: value + inline
            // set / change / clear text actions.
            ReefValueRow(
              leading: Icon(
                Icons.event,
                size: 18,
                color: ReefTokens.of(context).textDim,
              ),
              value: _startDate == null
                  ? '${l.startDate}: ${l.notSet}'
                  : '${l.startDate}: '
                        '${DateFormat.yMMMd().format(_startDate!)}',
              actions: [
                if (_startDate != null)
                  ReefInlineButton(
                    l.clear,
                    onPressed: () => setState(() => _startDate = null),
                  ),
                ReefInlineButton(
                  _startDate == null ? l.setDate : l.change,
                  onPressed: _pickStartDate,
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notes,
              decoration: InputDecoration(
                labelText: l.notesOptional,
                alignLabelWithHint: true,
              ),
              textCapitalization: TextCapitalization.sentences,
              keyboardType: TextInputType.multiline,
              minLines: 3,
              maxLines: 6,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_isEdit ? l.save : l.createAquarium),
            ),
          ],
        ),
      ),
    );
  }
}
