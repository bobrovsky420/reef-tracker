// GENERATED CODE — DO NOT EDIT BY HAND.
//
// Source: hanna_methods.yaml
// Regenerate: dart run tool/gen_hanna_methods.dart

part of 'hanna_meter.dart';

/// Every method the HI97115C registers, in display order,
/// generated from `hanna_methods.yaml`.
const List<HannaMeterMethod> kHannaMeterMethods = [
  HannaMeterMethod(2097, 'ph'),
  HannaMeterMethod(2002, 'alkalinity'),
  HannaMeterMethod(2099, 'ammonia'),
  HannaMeterMethod(2011, 'calcium'),
  HannaMeterMethod(2098, 'magnesium'),
  HannaMeterMethod(2095, 'nitrate'),
  HannaMeterMethod(2096, 'nitrate', lowRange: true),
  HannaMeterMethod(2057, 'nitrite', lowRange: true, factor: 0.001),
  HannaMeterMethod(2069, 'phosphate'),
];
