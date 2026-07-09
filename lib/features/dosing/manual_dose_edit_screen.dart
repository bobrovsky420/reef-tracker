import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/database.dart';
import '../../domain/supplement_catalog.dart';
import '../../domain/units.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import 'dosing_screen.dart' show formatDoseAmount;

/// Sentinel for the "Other…" (custom free-text) choice, same convention as the
/// plan edit form.
const String _kCustom = '__custom__';

/// Add/edit form for a logged one-off manual dose (supplement, vitamin or
/// medicine given by hand): Vendor → Product → Element cascade, a required
/// amount, and the date/time it was given. Writes directly to the database and
/// pops on save.
class ManualDoseEditScreen extends ConsumerStatefulWidget {
  const ManualDoseEditScreen({super.key, this.dose});

  /// The dose being edited, or null to log a new one.
  final ManualDose? dose;

  @override
  ConsumerState<ManualDoseEditScreen> createState() =>
      _ManualDoseEditScreenState();
}

class _ManualDoseEditScreenState extends ConsumerState<ManualDoseEditScreen> {
  final _formKey = GlobalKey<FormState>();

  String? _vendorSel;
  String? _productSel;
  final _vendorCtrl = TextEditingController();
  final _productCtrl = TextEditingController();

  String? _elementKey;

  final _amountCtrl = TextEditingController();
  DoseUnit _unit = DoseUnit.ml;

  DateTime _dosedAt = DateTime.now();

  final _noteCtrl = TextEditingController();

  /// True while a save is in flight; blocks re-entrant saves (double-tap).
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.dose;
    if (d != null) _initFromDose(d);
  }

  void _initFromDose(ManualDose d) {
    final key = d.productKey;
    if (key != null && kSupplementProductByKey.containsKey(key)) {
      _productSel = key;
      _vendorSel = kVendorKeyByProductKey[key];
    } else {
      String? vendorKey;
      for (final v in kSupplementVendors) {
        if (v.name == d.vendor) vendorKey = v.key;
      }
      _vendorSel = vendorKey ?? (d.vendor != null ? _kCustom : null);
      _vendorCtrl.text = d.vendor ?? '';
      _productSel = _kCustom;
      _productCtrl.text = d.product;
    }
    _elementKey = d.elementKey;
    _amountCtrl.text = formatDoseAmount(d.amount);
    _unit = DoseUnit.fromName(d.amountUnit);
    _dosedAt = d.dosedAt;
    _noteCtrl.text = d.note ?? '';
  }

  @override
  void dispose() {
    _vendorCtrl.dispose();
    _productCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  SupplementVendor? get _vendor => _vendorSel == null || _vendorSel == _kCustom
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

  Future<void> _pickDateTime() async {
    final picked = await pickPastDateTime(context, _dosedAt);
    if (picked == null || !mounted) return;
    setState(() => _dosedAt = picked);
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    final tank = ref.read(activeTankProvider);
    if (tank == null) return;
    final amount = parseUserDouble(_amountCtrl.text);
    if (amount == null || amount <= 0) return;
    setState(() => _saving = true);
    final db = ref.read(dbProvider);

    final productKey = (_productSel != null && _productSel != _kCustom)
        ? _productSel
        : null;
    final vendorName = _customVendor ? _vendorCtrl.text.trim() : _vendor?.name;
    final program = productKey != null
        ? kProgramNameByProductKey[productKey]
        : null;
    final note = _noteCtrl.text.trim();

    try {
      final existing = widget.dose;
      if (existing == null) {
        await db.insertManualDose(
          ManualDosesCompanion(
            tankId: Value(tank.id),
            dosedAt: Value(_dosedAt),
            productKey: Value(productKey),
            vendor: Value(vendorName),
            program: Value(program),
            product: Value(_productName),
            elementKey: Value(_elementKey),
            amount: Value(amount),
            amountUnit: Value(_unit.name),
            note: Value(note.isEmpty ? null : note),
          ),
        );
      } else {
        await db.updateManualDose(
          existing.copyWith(
            dosedAt: _dosedAt,
            productKey: Value(productKey),
            vendor: Value(vendorName),
            program: Value(program),
            product: _productName,
            elementKey: Value(_elementKey),
            amount: amount,
            amountUnit: _unit.name,
            note: Value(note.isEmpty ? null : note),
          ),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.dose == null ? l.manualDoseNew : l.manualDoseEdit),
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
            _amountRow(l),
            const SizedBox(height: 16),
            _dosedAtRow(l),
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

  Widget _amountRow(AppLocalizations l) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextFormField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l.dosingAmount,
              border: const OutlineInputBorder(),
            ),
            validator: (v) {
              // Unlike the plan's optional dosage, the given amount is the
              // point of the record — it must be a positive number.
              final parsed = parseUserDouble(v ?? '');
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
    );
  }

  Widget _dosedAtRow(AppLocalizations l) {
    return Row(
      children: [
        const Icon(Icons.schedule),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            formatDateTime(context, _dosedAt, weekday: false),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          tooltip: l.change,
          onPressed: _pickDateTime,
        ),
      ],
    );
  }
}
