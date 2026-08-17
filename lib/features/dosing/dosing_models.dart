/// Presentation-neutral payloads shared by dosing routes and screens.
library;

import '../../domain/supplement_catalog.dart';

class ManualDoseDraft {
  const ManualDoseDraft({
    required this.elementKey,
    required this.amount,
    required this.unit,
    this.productKey,
  });

  final String elementKey;
  final double amount;
  final DoseUnit unit;
  final String? productKey;
}
