import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/database.dart';
import '../../domain/supplement_catalog.dart';
import '../../domain/units.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import 'dosing_screen.dart';

/// Sentinel value for the "Other…" (custom free-text) choice in the vendor and
/// product dropdowns.
const String _kCustom = '__custom__';

/// Add/edit form for a single supplement-dosing plan entry. Cascades
/// Vendor → Product → Element, then optional dosage and a descriptive schedule.
/// Writes directly to the database and pops on save.
class DosingEditScreen extends ConsumerStatefulWidget {
  const DosingEditScreen({super.key, this.entry});

  /// The entry being edited, or null to add a new one.
  final DosingEntry? entry;

  @override
  ConsumerState<DosingEditScreen> createState() => _DosingEditScreenState();
}

class _DosingEditScreenState extends ConsumerState<DosingEditScreen> {
  final _formKey = GlobalKey<FormState>();

  // Selection: a vendor/product key, [_kCustom], or null for none chosen.
  String? _vendorSel;
  String? _productSel;
  final _vendorCtrl = TextEditingController();
  final _productCtrl = TextEditingController();

  String? _elementKey;

  final _amountCtrl = TextEditingController();
  DoseUnit _unit = DoseUnit.ml;
  DoseBasis _basis = DoseBasis.perDay;

  DoseFrequency? _frequency;
  final _intervalCtrl = TextEditingController();
  final Set<int> _weekdays = {};
  TimeOfDay? _time;

  final _noteCtrl = TextEditingController();

  /// True while a save is in flight; blocks re-entrant saves (double-tap).
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    if (e != null) _initFromEntry(e);
  }

  void _initFromEntry(DosingEntry e) {
    final key = e.productKey;
    if (key != null && kSupplementProductByKey.containsKey(key)) {
      _productSel = key;
      _vendorSel = kVendorKeyByProductKey[key];
    } else {
      // Custom product, possibly under a known vendor (matched by name).
      String? vendorKey;
      for (final v in kSupplementVendors) {
        if (v.name == e.vendor) vendorKey = v.key;
      }
      _vendorSel = vendorKey ?? (e.vendor != null ? _kCustom : null);
      _vendorCtrl.text = e.vendor ?? '';
      _productSel = _kCustom;
      _productCtrl.text = e.product;
    }
    _elementKey = e.elementKey;
    if (e.amount != null) _amountCtrl.text = formatDoseAmount(e.amount!);
    _unit = DoseUnit.fromName(e.amountUnit);
    _basis = DoseBasis.fromName(e.basis) ?? DoseBasis.perDay;
    _frequency = DoseFrequency.fromName(e.frequency);
    if (e.intervalDays != null) _intervalCtrl.text = '${e.intervalDays}';
    _weekdays.addAll(parseWeekdays(e.weekdays));
    final t = e.doseTime;
    if (t != null && t.contains(':')) {
      final p = t.split(':');
      _time = TimeOfDay(
        hour: int.tryParse(p[0]) ?? 0,
        minute: int.tryParse(p[1]) ?? 0,
      );
    }
    _noteCtrl.text = e.note ?? '';
  }

  @override
  void dispose() {
    _vendorCtrl.dispose();
    _productCtrl.dispose();
    _amountCtrl.dispose();
    _intervalCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  // --- Selection resolution ---------------------------------------------------

  SupplementVendor? get _vendor =>
      _vendorSel == null || _vendorSel == _kCustom
          ? null
          : kSupplementVendorByKey[_vendorSel];

  bool get _customVendor => _vendorSel == _kCustom;
  bool get _customProduct =>
      _vendorSel == _kCustom || _productSel == _kCustom || _productSel == null;

  String get _productName {
    if (_productSel != null && _productSel != _kCustom) {
      return kSupplementProductByKey[_productSel]?.name ?? '';
    }
    return _productCtrl.text.trim();
  }

  bool get _canSave {
    if (_saving) return false;
    if (_vendorSel == null) return false;
    if (_customVendor && _vendorCtrl.text.trim().isEmpty) return false;
    return _productName.isNotEmpty;
  }

  void _onVendorChanged(String? value) {
    setState(() {
      _vendorSel = value;
      _productSel = null;
      _productCtrl.clear();
    });
  }

  void _onProductChanged(String? value) {
    setState(() {
      _productSel = value;
      if (value != null && value != _kCustom) {
        final product = kSupplementProductByKey[value];
        if (product != null) {
          _elementKey = product.elementKey;
          _unit = product.defaultUnit;
        }
      }
    });
  }

  // --- Save -------------------------------------------------------------------

  Future<void> _save() async {
    // Re-entrancy guard: a double-tap while the first insert is in flight
    // would otherwise insert (or supersede) twice.
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    final tank = ref.read(activeTankProvider);
    if (tank == null) return;
    setState(() => _saving = true);
    final db = ref.read(dbProvider);

    final productKey =
        (_productSel != null && _productSel != _kCustom) ? _productSel : null;
    final vendorName =
        _customVendor ? _vendorCtrl.text.trim() : _vendor?.name;
    final program =
        productKey != null ? kProgramNameByProductKey[productKey] : null;

    final amount = parseUserDouble(_amountCtrl.text);

    final interval = _frequency == DoseFrequency.everyNDays
        ? int.tryParse(_intervalCtrl.text.trim())
        : null;
    final weekdays = _frequency == DoseFrequency.weekly && _weekdays.isNotEmpty
        ? (_weekdays.toList()..sort()).join(',')
        : null;
    final doseTime = _time == null
        ? null
        : '${_time!.hour.toString().padLeft(2, '0')}:'
            '${_time!.minute.toString().padLeft(2, '0')}';
    final note = _noteCtrl.text.trim();

    final companion = DosingEntriesCompanion(
      tankId: Value(tank.id),
      productKey: Value(productKey),
      vendor: Value(vendorName),
      program: Value(program),
      product: Value(_productName),
      elementKey: Value(_elementKey),
      amount: Value(amount),
      amountUnit: Value(amount == null ? null : _unit.name),
      basis: Value(amount == null ? null : _basis.name),
      frequency: Value(_frequency?.name),
      intervalDays: Value(interval),
      weekdays: Value(weekdays),
      doseTime: Value(doseTime),
      note: Value(note.isEmpty ? null : note),
    );

    try {
      final existing = widget.entry;
      if (existing == null) {
        await db.insertDosingEntry(companion);
      } else if (_doseAffectingChanged(existing, companion)) {
        // A dose change: retain the old dose as history and start a new
        // segment.
        await db.supersedeDosingEntry(existing, companion);
      } else {
        // Cosmetic-only edit (display name, note, time): update in place.
        await db.updateDosingEntry(existing.copyWith(
          product: _productName,
          doseTime: companion.doseTime,
          note: companion.note,
        ));
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Whether the edit changed any field that alters the dosed amount (and thus
  /// the dose-calculator boundary), requiring a new history segment. Cosmetic
  /// fields (display name, note, time) are excluded.
  bool _doseAffectingChanged(DosingEntry old, DosingEntriesCompanion next) =>
      old.productKey != next.productKey.value ||
      old.elementKey != next.elementKey.value ||
      old.amount != next.amount.value ||
      old.amountUnit != next.amountUnit.value ||
      old.basis != next.basis.value ||
      old.frequency != next.frequency.value ||
      old.intervalDays != next.intervalDays.value ||
      old.weekdays != next.weekdays.value;

  // --- Build ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.entry == null ? l.dosingNew : l.dosingEdit),
        actions: [
          // Non-swipe path to stop the supplement (#45): swipe-to-stop on the
          // Dosing tab is unusable with TalkBack/switch access.
          if (widget.entry != null)
            IconButton(
              icon: const Icon(Icons.stop_circle_outlined),
              tooltip: l.stop,
              onPressed: () async {
                final stopped =
                    await confirmStopDosing(context, ref, widget.entry!);
                if (stopped && context.mounted) Navigator.of(context).pop();
              },
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _vendorField(l),
            const SizedBox(height: 16),
            _productField(l),
            const SizedBox(height: 16),
            _elementField(l),
            const Divider(height: 32),
            _dosageSection(l),
            const Divider(height: 32),
            _scheduleSection(l),
            const Divider(height: 32),
            TextField(
              controller: _noteCtrl,
              decoration: InputDecoration(
                labelText: l.noteOptional,
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _canSave ? _save : null,
              child: Text(l.save),
            ),
          ],
        ),
      ),
    );
  }

  Widget _vendorField(AppLocalizations l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _vendorSel,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: l.dosingVendor,
            border: const OutlineInputBorder(),
          ),
          items: [
            for (final v in kSupplementVendors)
              DropdownMenuItem(value: v.key, child: Text(v.name)),
            DropdownMenuItem(value: _kCustom, child: Text(l.dosingCustom)),
          ],
          onChanged: _onVendorChanged,
        ),
        if (_customVendor) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _vendorCtrl,
            decoration: InputDecoration(
              labelText: l.dosingVendorName,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ],
    );
  }

  Widget _productField(AppLocalizations l) {
    final vendor = _vendor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (vendor != null)
          DropdownButtonFormField<String>(
            initialValue: _productSel,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l.dosingProduct,
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final p in vendor.allProducts)
                DropdownMenuItem(value: p.key, child: Text(p.name)),
              DropdownMenuItem(value: _kCustom, child: Text(l.dosingCustom)),
            ],
            onChanged: _onProductChanged,
          ),
        if (_customProduct) ...[
          if (vendor != null) const SizedBox(height: 12),
          TextField(
            controller: _productCtrl,
            decoration: InputDecoration(
              labelText: l.dosingProductName,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ],
    );
  }

  Widget _elementField(AppLocalizations l) {
    return DropdownButtonFormField<String?>(
      initialValue: _elementKey,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: l.dosingElement,
        border: const OutlineInputBorder(),
      ),
      items: [
        DropdownMenuItem(value: null, child: Text(l.dosingElementNone)),
        for (final key in kDosingElementKeys)
          DropdownMenuItem(value: key, child: Text(l.paramName(key))),
      ],
      onChanged: (v) => setState(() => _elementKey = v),
    );
  }

  Widget _dosageSection(AppLocalizations l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.dosingDosageOptional,
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: l.dosingAmount,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  // The dosage is optional, but a non-empty entry must be a
                  // positive number — garbage was silently dropped before (#8).
                  if (v == null || v.trim().isEmpty) return null;
                  final parsed = parseUserDouble(v);
                  return (parsed == null || parsed <= 0)
                      ? l.invalidPositiveNumber
                      : null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<DoseUnit>(
                initialValue: _unit,
                decoration: InputDecoration(
                  labelText: l.dosingUnit,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  for (final u in DoseUnit.values)
                    DropdownMenuItem(value: u, child: Text(u.symbol)),
                ],
                onChanged: (v) => setState(() => _unit = v ?? _unit),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<DoseBasis>(
          initialValue: _basis,
          decoration: InputDecoration(
            labelText: l.dosingBasis,
            border: const OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem(
                value: DoseBasis.perDay, child: Text(l.dosingPerDay)),
            DropdownMenuItem(
                value: DoseBasis.perDose, child: Text(l.dosingPerDose)),
          ],
          onChanged: (v) => setState(() => _basis = v ?? _basis),
        ),
      ],
    );
  }

  Widget _scheduleSection(AppLocalizations l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.dosingSchedule,
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 12),
        DropdownButtonFormField<DoseFrequency?>(
          initialValue: _frequency,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: l.dosingFrequency,
            border: const OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem(value: null, child: Text(l.dosingFreqNone)),
            DropdownMenuItem(
                value: DoseFrequency.daily, child: Text(l.dosingFreqDaily)),
            DropdownMenuItem(
                value: DoseFrequency.everyNDays,
                child: Text(l.dosingFreqEveryNDays)),
            DropdownMenuItem(
                value: DoseFrequency.weekly, child: Text(l.dosingFreqWeekly)),
          ],
          onChanged: (v) => setState(() => _frequency = v),
        ),
        if (_frequency == DoseFrequency.everyNDays) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _intervalCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l.dosingIntervalDays,
              border: const OutlineInputBorder(),
            ),
            validator: (v) {
              // "Every N days" needs a whole N ≥ 1 — 0/-3 used to be stored
              // and silently reinterpreted as daily by the calculator (#8).
              final parsed = int.tryParse((v ?? '').trim());
              return (parsed == null || parsed < 1)
                  ? l.invalidIntervalDays
                  : null;
            },
          ),
        ],
        if (_frequency == DoseFrequency.weekly) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (var d = 1; d <= 7; d++)
                FilterChip(
                  label: Text(_weekdayLabel(context, d)),
                  selected: _weekdays.contains(d),
                  onSelected: (sel) => setState(() {
                    if (sel) {
                      _weekdays.add(d);
                    } else {
                      _weekdays.remove(d);
                    }
                  }),
                ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.schedule),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _time == null
                    ? l.dosingTimeOptional
                    : MaterialLocalizations.of(context).formatTimeOfDay(_time!),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            if (_time != null)
              IconButton(
                icon: const Icon(Icons.clear),
                tooltip: l.cancel,
                onPressed: () => setState(() => _time = null),
              ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: l.change,
              onPressed: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _time ?? const TimeOfDay(hour: 20, minute: 0),
                );
                if (picked != null && mounted) setState(() => _time = picked);
              },
            ),
          ],
        ),
      ],
    );
  }

  String _weekdayLabel(BuildContext context, int weekday) {
    final base = DateTime(2024, 1, 1); // a Monday
    return MaterialLocalizations.of(context)
        .narrowWeekdays[base.add(Duration(days: weekday - 1)).weekday % 7];
  }
}
