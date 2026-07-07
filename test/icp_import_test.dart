import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/domain/icp_import.dart';

/// Real Fauna Marin lab-portal CSV export (German locale: `;` delimiter,
/// decimal commas). One analysis row; empty cells are unmeasured fields.
const _faunaMarinCsv =
    'id;water_type;owner_type;ag;al;ar;as;b;ba;be;br;ca;cd;co;cr;cs;cu;fe;ga;'
    'hf;hg;i;k;la;li;mg;mn;mo;na;nd;ni;p;pb;s;sb;sc;se;si;sn;sr;te;th;ti;tl;'
    'u;v;w;zn;zr;fluoride;chloride;bromide;nitrate;nitrite;sulfate;'
    'conductivity;pH;alkalinityDkH;salinity;sak254;sak410;sak436;npoc;tnb;'
    'density;densityrel;po4g;po4er;smell;color;analysis_date;note;'
    'aquarium_id;sample_id\n'
    '303316;0;0;0;26,6;;0;5,61;16,7;0;67;392;0;0;0;;2,5;0,905;;;0;0,102;412;'
    '0;201;1325;0;36,3;11127;;4,01;0,0145;0;850;0;;0;0,204;0;5,97;;;0;;;3,19;'
    '0;2,03;0;;;;;;2546,6;;;;;;;;;;;;;0,044457;0;0;2026-06-01 15:36:59;;'
    '17003;01337792\n';

/// The ZIMS export of the same analysis (comma-separated, quoted, explicit
/// units, UTF-8 BOM).
const _zimsCsv =
    '﻿"Date","Time","Measurement","MeasurementValue","UnitofMeasure","MeasuredBy"\n'
    '"2026-06-02","07:10:45","Sodium (Na+)","11127","milligrams per litre","FaunaMarin Lab"\n'
    '"2026-06-02","07:10:45","Sulfur (S)","850","milligrams per litre","FaunaMarin Lab"\n'
    '"2026-06-02","07:10:45","Sulfate","2546.6","milligrams per litre","FaunaMarin Lab"\n'
    '"2026-06-02","07:10:45","Potassium (K+)","412","milligrams per litre","FaunaMarin Lab"\n'
    '"2026-06-02","07:10:45","Boron (B)","5.61","milligrams per litre","FaunaMarin Lab"\n'
    '"2026-06-02","07:10:45","Magnesium (Mg2+)","1325","milligrams per litre","FaunaMarin Lab"\n'
    '"2026-06-02","07:10:45","Calcium (Ca)","392","milligrams per litre","FaunaMarin Lab"\n'
    '"2026-06-02","07:10:45","Strontium (Sr2+)","5.97","milligrams per litre","FaunaMarin Lab"\n'
    '"2026-06-02","07:10:45","Bromine (Br)","67","milligrams per litre","FaunaMarin Lab"\n'
    '"2026-06-02","07:10:45","Iodine (I2)","0.102","milligrams per litre","FaunaMarin Lab"\n'
    '"2026-06-02","07:10:45","Silicon (Si)","0.204","milligrams per litre","FaunaMarin Lab"\n'
    '"2026-06-02","07:10:45","Zinc (Zn)","2.03","micrograms per litre","FaunaMarin Lab"\n'
    '"2026-06-02","07:10:45","Vanadium (V)","3.19","micrograms per litre","FaunaMarin Lab"\n'
    '"2026-06-02","07:10:45","Copper (Cu)","2.5","micrograms per litre","FaunaMarin Lab"\n'
    '"2026-06-02","07:10:45","Nickel (Ni)","4.01","micrograms per litre","FaunaMarin Lab"\n'
    '"2026-06-02","07:10:45","Molybdenum (Mo)","36.3","micrograms per litre","FaunaMarin Lab"\n'
    '"2026-06-02","07:10:45","Barium (Ba)","16.7","micrograms per litre","FaunaMarin Lab"\n'
    '"2026-06-02","07:10:45","Cobalt (Co)","0","micrograms per litre","FaunaMarin Lab"\n'
    '"2026-06-02","07:10:45","Chromium (Cr)","0","micrograms per litre","FaunaMarin Lab"\n'
    '"2026-06-02","07:10:45","Iron (Fe)","0.905","micrograms per litre","FaunaMarin Lab"\n'
    '"2026-06-02","07:10:45","Lithium (Li)","201","micrograms per litre","FaunaMarin Lab"\n'
    '"2026-06-02","07:10:45","Manganese (Mn)","0","micrograms per litre","FaunaMarin Lab"\n'
    '"2026-06-02","07:10:45","Selenium (Se)","0","micrograms per litre","FaunaMarin Lab"\n'
    '"2026-06-02","07:10:45","Aluminum (Al)","26.6","micrograms per litre","FaunaMarin Lab"\n'
    '"2026-06-02","07:10:45","Antimony (Sb)","0","micrograms per litre","FaunaMarin Lab"\n'
    '"2026-06-02","07:10:45","Arsenic (As)","0","micrograms per litre","FaunaMarin Lab"\n'
    '"2026-06-02","07:10:45","Beryllium (Be)","0","micrograms per litre","FaunaMarin Lab"\n'
    '"2026-06-02","07:10:45","Lead (Pb)","0","micrograms per litre","FaunaMarin Lab"\n'
    '"2026-06-02","07:10:45","Cadmium (Cd)","0","micrograms per litre","FaunaMarin Lab"\n'
    '"2026-06-02","07:10:45","Lanthanum (La)","0","micrograms per litre","FaunaMarin Lab"\n'
    '"2026-06-02","07:10:45","Mercury (Hg)","0","micrograms per litre","FaunaMarin Lab"\n'
    '"2026-06-02","07:10:45","Titanium (Ti)","0","micrograms per litre","FaunaMarin Lab"\n'
    '"2026-06-02","07:10:45","Tungsten (W)","0","micrograms per litre","FaunaMarin Lab"\n'
    '"2026-06-02","07:10:45","Tin (Sn)","0","micrograms per litre","FaunaMarin Lab"\n'
    '"2026-06-02","07:10:45","Phosphorus (P)","0.0145","milligrams per litre","FaunaMarin Lab"\n'
    '"2026-06-02","07:10:45","Orthophosphate (PO4)","0.044457","milligrams per litre","FaunaMarin Lab"\n'
    '"2026-06-02","07:10:45","Silver (Ag)","0","micrograms per litre","FaunaMarin Lab"\n'
    '"2026-06-02","07:10:45","Zirconium (Zr)","0","micrograms per litre","FaunaMarin Lab"\n';

void main() {
  group('Fauna Marin CSV', () {
    test('imports mg/L columns as canonical ppm', () {
      final r = parseIcpCsv(_faunaMarinCsv, IcpImportFormat.faunaMarin);
      expect(r.values['sodium'], 11127);
      expect(r.values['sulfur'], 850);
      expect(r.values['boron'], 5.61);
      expect(r.values['bromine'], 67);
      expect(r.values['strontium'], 5.97);
      // Iodine and silicon are mg/L on the report even though the app
      // *displays* them in µg/L — no ÷1000 here.
      expect(r.values['iodine'], 0.102);
      expect(r.values['silicon'], 0.204);
      expect(r.values['calcium'], 392);
      expect(r.values['magnesium'], 1325);
      expect(r.values['potassium'], 412);
    });

    test('imports µg/L columns divided by 1000', () {
      final r = parseIcpCsv(_faunaMarinCsv, IcpImportFormat.faunaMarin);
      expect(r.values['aluminium'], closeTo(0.0266, 1e-9));
      expect(r.values['zinc'], closeTo(0.00203, 1e-9));
      expect(r.values['iron'], closeTo(0.000905, 1e-9));
      expect(r.values['copper'], closeTo(0.0025, 1e-9));
      expect(r.values['molybdenum'], closeTo(0.0363, 1e-9));
      expect(r.values['lithium'], closeTo(0.201, 1e-9));
      // Below-detection-limit zeros import as real 0 readings.
      expect(r.values['cobalt'], 0);
      expect(r.values['mercury'], 0);
    });

    test('imports phosphate from po4er when po4g is empty', () {
      final r = parseIcpCsv(_faunaMarinCsv, IcpImportFormat.faunaMarin);
      expect(r.values['phosphate'], 0.044457);
    });

    test('prefers po4g over po4er when both are present', () {
      const csv =
          'na;po4g;po4er;analysis_date;sample_id\n'
          '11127;0,05;0,044457;2026-06-01 15:36:59;X1\n';
      final r = parseIcpCsv(csv, IcpImportFormat.faunaMarin);
      expect(r.values['phosphate'], 0.05);
    });

    test('accepts dot decimals (non-German export locale)', () {
      const csv =
          'na;zn;i;analysis_date;sample_id\n'
          '11127;2.03;0.102;2026-06-01 15:36:59;X1\n';
      final r = parseIcpCsv(csv, IcpImportFormat.faunaMarin);
      expect(r.values['sodium'], 11127);
      expect(r.values['zinc'], closeTo(0.00203, 1e-9));
      expect(r.values['iodine'], 0.102);
    });

    test('reports metadata and skips unmapped columns visibly', () {
      final r = parseIcpCsv(_faunaMarinCsv, IcpImportFormat.faunaMarin);
      expect(r.sampleId, '01337792');
      expect(r.reportDate, DateTime(2026, 6, 1, 15, 36, 59));
      expect(r.skipped, contains('sulfate'));
      // Elemental P and the po4 pair are handled, not "skipped".
      expect(r.skipped, isNot(contains('p')));
      expect(r.skipped, isNot(contains('po4er')));
      // Nothing invents values for empty columns.
      expect(r.values.containsKey('nitrate'), isFalse);
      expect(r.values.containsKey('ph'), isFalse);
      expect(r.values.containsKey('salinity'), isFalse);
    });

    test('values come back in catalog order', () {
      final r = parseIcpCsv(_faunaMarinCsv, IcpImportFormat.faunaMarin);
      final keys = r.values.keys.toList();
      expect(keys.indexOf('calcium'), lessThan(keys.indexOf('sodium')));
      expect(keys.indexOf('sodium'), lessThan(keys.indexOf('lead')));
    });

    test('rejects a ZIMS file chosen as Fauna Marin', () {
      expect(
        () => parseIcpCsv(_zimsCsv, IcpImportFormat.faunaMarin),
        throwsA(
          isA<IcpImportException>().having(
            (e) => e.reason,
            'reason',
            IcpImportRejection.wrongFormat,
          ),
        ),
      );
    });
  });

  group('ZIMS CSV', () {
    test('imports every mappable measurement with explicit units', () {
      final r = parseIcpCsv(_zimsCsv, IcpImportFormat.zims);
      expect(r.values['sodium'], 11127);
      expect(r.values['potassium'], 412);
      expect(r.values['calcium'], 392);
      expect(r.values['magnesium'], 1325);
      // Symbol tier: "Iodine (I2)" → I → iodine, mg/L stays canonical.
      expect(r.values['iodine'], 0.102);
      expect(r.values['silicon'], 0.204);
      // µg/L rows convert to ppm.
      expect(r.values['zinc'], closeTo(0.00203, 1e-9));
      expect(r.values['aluminium'], closeTo(0.0266, 1e-9));
      expect(r.values['iron'], closeTo(0.000905, 1e-9));
      // Name tier: Orthophosphate (PO4) → phosphate.
      expect(r.values['phosphate'], 0.044457);
      expect(r.values['cobalt'], 0);
    });

    test('matches the Fauna Marin import of the same analysis', () {
      final fm = parseIcpCsv(_faunaMarinCsv, IcpImportFormat.faunaMarin);
      final zims = parseIcpCsv(_zimsCsv, IcpImportFormat.zims);
      for (final key in zims.values.keys) {
        expect(zims.values[key], closeTo(fm.values[key]!, 1e-9), reason: key);
      }
    });

    test('skips unmappable and double-log rows visibly', () {
      final r = parseIcpCsv(_zimsCsv, IcpImportFormat.zims);
      expect(r.skipped, contains('Sulfate'));
      expect(r.skipped, contains('Phosphorus (P)'));
      expect(r.values.length, 36);
    });

    test('reads the report date, has no sample id', () {
      final r = parseIcpCsv(_zimsCsv, IcpImportFormat.zims);
      expect(r.reportDate, DateTime(2026, 6, 2, 7, 10, 45));
      expect(r.sampleId, isNull);
    });

    test('skips rows with unrecognized units instead of guessing', () {
      const csv =
          '"Date","Time","Measurement","MeasurementValue","UnitofMeasure","MeasuredBy"\n'
          '"2026-06-02","07:10:45","Zinc (Zn)","2.03","parts per trillion","Lab"\n'
          '"2026-06-02","07:10:45","Iron (Fe)","0.905","micrograms per litre","Lab"\n';
      final r = parseIcpCsv(csv, IcpImportFormat.zims);
      expect(r.values.containsKey('zinc'), isFalse);
      expect(r.skipped, contains('Zinc (Zn) (parts per trillion)'));
      expect(r.values['iron'], closeTo(0.000905, 1e-9));
    });

    test('rejects a Fauna Marin file chosen as ZIMS', () {
      expect(
        () => parseIcpCsv(_faunaMarinCsv, IcpImportFormat.zims),
        throwsA(
          isA<IcpImportException>().having(
            (e) => e.reason,
            'reason',
            IcpImportRejection.wrongFormat,
          ),
        ),
      );
    });

    test('rejects garbage and value-free files distinctly', () {
      expect(
        () => parseIcpCsv('hello world', IcpImportFormat.zims),
        throwsA(
          isA<IcpImportException>().having(
            (e) => e.reason,
            'reason',
            IcpImportRejection.wrongFormat,
          ),
        ),
      );
      const empty =
          '"Date","Time","Measurement","MeasurementValue","UnitofMeasure"\n'
          '"2026-06-02","07:10:45","Rubidium (Rb)","1.0","micrograms per litre"\n';
      expect(
        () => parseIcpCsv(empty, IcpImportFormat.zims),
        throwsA(
          isA<IcpImportException>().having(
            (e) => e.reason,
            'reason',
            IcpImportRejection.noValues,
          ),
        ),
      );
    });
  });

  group('ZIMS matching helpers', () {
    test('symbol tier strips charges and stoichiometry', () {
      expect(zimsMeasurementKey('Sodium (Na+)'), 'sodium');
      expect(zimsMeasurementKey('Magnesium (Mg2+)'), 'magnesium');
      expect(zimsMeasurementKey('Iodine (I2)'), 'iodine');
      expect(zimsMeasurementKey('Iodide (I-)'), 'iodine');
      expect(zimsMeasurementKey('Potassium (K+)'), 'potassium');
    });

    test('name tier covers spelling variants and PO4', () {
      expect(zimsMeasurementKey('Aluminium'), 'aluminium');
      expect(zimsMeasurementKey('Aluminum (Al)'), 'aluminium');
      expect(zimsMeasurementKey('Sulphur'), 'sulfur');
      expect(zimsMeasurementKey('Orthophosphate (PO4)'), 'phosphate');
      expect(zimsMeasurementKey('Rubidium (Rb)'), isNull);
      expect(zimsMeasurementKey('Phosphorus (P)'), isNull);
    });

    test('unit factors', () {
      expect(zimsUnitFactor('milligrams per litre'), 1);
      expect(zimsUnitFactor('mg/L'), 1);
      expect(zimsUnitFactor('ppm'), 1);
      expect(zimsUnitFactor('micrograms per litre'), 0.001);
      expect(zimsUnitFactor('µg/L'), 0.001);
      expect(zimsUnitFactor('ug/l'), 0.001);
      expect(zimsUnitFactor('ppb'), 0.001);
      expect(zimsUnitFactor('parts per trillion'), isNull);
    });
  });
}
