import '../domain/setup_type.dart';
import '../domain/units.dart';
import '../domain/zones.dart';
import 'app_localizations.dart';

/// Localized labels for domain values (parameter names/help, setup types,
/// zones) that live as keys/enums rather than free text.
extension L10nDomain on AppLocalizations {
  String paramName(String key) {
    switch (key) {
      case 'temperature':
        return paramTemperature;
      case 'ph':
        return paramPh;
      case 'salinity':
        return paramSalinity;
      case 'alkalinity':
        return paramAlkalinity;
      case 'calcium':
        return paramCalcium;
      case 'magnesium':
        return paramMagnesium;
      case 'nitrate':
        return paramNitrate;
      case 'phosphate':
        return paramPhosphate;
      case 'ammonia':
        return paramAmmonia;
      case 'nitrite':
        return paramNitrite;
      case 'orp':
        return paramOrp;
      case 'potassium':
        return paramPotassium;
      case 'strontium':
        return paramStrontium;
      case 'iodine':
        return paramIodine;
      default:
        return key;
    }
  }

  String? paramHelp(String key) {
    switch (key) {
      case 'temperature':
        return helpTemperature;
      case 'salinity':
        return helpSalinity;
      case 'alkalinity':
        return helpAlkalinity;
      case 'nitrate':
        return helpNitrate;
      case 'ammonia':
        return helpAmmonia;
      default:
        return null;
    }
  }

  String setupLabel(SetupType type) {
    switch (type) {
      case SetupType.fishOnly:
        return setupFishOnly;
      case SetupType.soft:
        return setupSoft;
      case SetupType.lps:
        return setupLps;
      case SetupType.sps:
        return setupSps;
      case SetupType.mixed:
        return setupMixed;
    }
  }

  /// A canonical litre value formatted with its localized unit suffix in the
  /// user's preferred volume [unit] (e.g. "200 L" or "53 gal").
  String volumeWithUnit(double liters, VolumeUnit unit) {
    final value = formatVolume(liters, unit);
    switch (unit) {
      case VolumeUnit.liters:
        return litersSuffix(value);
      case VolumeUnit.gallons:
        return gallonsSuffix(value);
    }
  }

  String zoneLabel(Zone zone) {
    switch (zone) {
      case Zone.green:
        return zoneOk;
      case Zone.amber:
        return zoneAttention;
      case Zone.red:
        return zoneActNow;
      case Zone.unknown:
        return zoneUnknown;
    }
  }
}
