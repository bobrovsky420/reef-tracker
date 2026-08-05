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

/// A later analysis of the same tank (lab id 315240), kept as a pair (Fauna
/// Marin + ZIMS of one sample) because it is the only real export where the
/// two phosphate columns disagree materially: `po4g` 0,021 vs `po4er`
/// 0,0953526 (#118). The lab's web report for this id names them
/// "Orthophosphat" and "Gesamtphosphat" respectively — the identities the
/// max rule is built on.
const _faunaMarinCsvJuly =
    'id;water_type;owner_type;ag;al;ar;as;b;ba;be;br;ca;cd;co;cr;cs;cu;fe;ga;'
    'hf;hg;i;k;la;li;mg;mn;mo;na;nd;ni;p;pb;s;sb;sc;se;si;sn;sr;te;th;ti;tl;'
    'u;v;w;zn;zr;fluoride;chloride;bromide;nitrate;nitrite;sulfate;'
    'conductivity;pH;alkalinityDkH;salinity;sak254;sak410;sak436;npoc;tnb;'
    'density;densityrel;po4g;po4er;smell;color;analysis_date;note;'
    'aquarium_id;sample_id\n'
    '315240;0;0;0;31,5;;0;5,56;20,4;0;67,9;413;0;0;0;;1,45;2,67;;;0;0,0628;'
    '427;0;200;1391;0;43,2;11673;;4,69;0,0311;0;872;0;;0;0,085;0;6,56;;;0;;;'
    '3,63;0;3,51;0;1,17;20208,43032456;;22,58;0,06;2612,512;54,7;8,07;8,6;'
    '36,17675501;;;;;;1,02423272;1,02727344;0,021;0,0953526;0;0;'
    '2026-07-27 19:06:33;;17003;21671326\n';

/// The ZIMS side of the July pair. It carries **both** phosphate figures —
/// "Phosphates" is the wide export's `po4g`, "Orthophosphate (PO4)" its
/// `po4er` — with the photometric one listed *first*, so row order must not
/// decide the import (#118). Note the ZIMS names are swapped against the
/// lab's own web report, where 0.0953526 is *Gesamtphosphat* (total) and
/// 0.021 is *Orthophosphat*. Alkalinity rides as "Carbonate Hardness" in
/// meq/L: 3.0702 x 2.8 = the 8.6 dKH of the wide export and of the web page.
const _zimsCsvJuly =
    '"Date","Time","Measurement","MeasurementValue","UnitofMeasure","MeasuredBy"\n'
    '"2026-07-28","11:02:14","pH","8.07","pH","FaunaMarin Lab"\n'
    '"2026-07-28","11:02:14","Carbonate Hardness","3.0702","milliequivalents per litre","FaunaMarin Lab"\n'
    '"2026-07-28","11:02:14","Sodium (Na+)","11673","milligrams per litre","FaunaMarin Lab"\n'
    '"2026-07-28","11:02:14","Calcium (Ca)","413","milligrams per litre","FaunaMarin Lab"\n'
    '"2026-07-28","11:02:14","Magnesium (Mg2+)","1391","milligrams per litre","FaunaMarin Lab"\n'
    '"2026-07-28","11:02:14","Nitrate (NO3-)","22.58","milligrams per litre","FaunaMarin Lab"\n'
    '"2026-07-28","11:02:14","Phosphates","0.021","milligrams per litre","FaunaMarin Lab"\n'
    '"2026-07-28","11:02:14","Phosphorus (P)","0.0311","milligrams per litre","FaunaMarin Lab"\n'
    '"2026-07-28","11:02:14","Orthophosphate (PO4)","0.0953526","milligrams per litre","FaunaMarin Lab"\n';

/// A third real export (ZIMS only) from the same tank a month earlier. It
/// repeats the July pattern at a fifth of the concentration — P 0.01 x 3.066
/// = the 0.03066 "Orthophosphate (PO4)" row, five times the 0.006
/// "Phosphates" gauge — which is what makes the gap systematic rather than
/// one bad analysis (#118).
const _zimsCsvJune26 =
    '"Date","Time","Measurement","MeasurementValue","UnitofMeasure","MeasuredBy"\n'
    '"2026-06-26","12:32:12","Salinity","34.99284","parts per thousand","FaunaMarin Lab"\n'
    '"2026-06-26","12:32:12","pH","7.98","pH","FaunaMarin Lab"\n'
    '"2026-06-26","12:32:12","Carbonate Hardness","3.0345","milliequivalents per litre","FaunaMarin Lab"\n'
    '"2026-06-26","12:32:12","Calcium (Ca)","414","milligrams per litre","FaunaMarin Lab"\n'
    '"2026-06-26","12:32:12","Nitrate (NO3-)","23.28","milligrams per litre","FaunaMarin Lab"\n'
    '"2026-06-26","12:32:12","Phosphates","0.006","milligrams per litre","FaunaMarin Lab"\n'
    '"2026-06-26","12:32:12","Manganese (Mn)","0.722","micrograms per litre","FaunaMarin Lab"\n'
    '"2026-06-26","12:32:12","Phosphorus (P)","0.01","milligrams per litre","FaunaMarin Lab"\n'
    '"2026-06-26","12:32:12","Orthophosphate (PO4)","0.03066","milligrams per litre","FaunaMarin Lab"\n';

void main() {
  group('Fauna Marin CSV', () {
    test('imports mg/L columns as canonical ppm', () {
      final r = parseIcpCsv(_faunaMarinCsv, IcpImportFormat.faunaMarin);
      expect(r.values['sodium'], 11127);
      expect(r.values['sulfur'], 850);
      expect(r.values['boron'], 5.61);
      expect(r.values['bromine'], 67);
      expect(r.values['strontium'], 5.97);
      // Iodine and silicon are mg/L on the report (and in the app's
      // display) — no ÷1000 here.
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

    test('takes the higher of the two phosphate columns (#118)', () {
      // Orthophosphate is a species of the total P the ICP measures, so the
      // calculated po4er normally sits above the photometric po4g.
      const csv =
          'na;po4g;po4er;analysis_date;sample_id\n'
          '11127;0,021;0,0953526;2026-06-01 15:36:59;X1\n';
      final r = parseIcpCsv(csv, IcpImportFormat.faunaMarin);
      expect(r.values['phosphate'], 0.0953526);
    });

    test('a below-detection ICP phosphorus never beats a real photometric '
        'reading (#118)', () {
      // The lab prints a hard 0 below the detection limit, which makes po4er
      // 0 too — importing that over a measured 0,05 would show a tank with
      // phosphate as a perfect zero.
      const csv =
          'na;p;po4g;po4er;analysis_date;sample_id\n'
          '11127;0;0,05;0;2026-06-01 15:36:59;X1\n';
      final r = parseIcpCsv(csv, IcpImportFormat.faunaMarin);
      expect(r.values['phosphate'], 0.05);
    });

    test('both below detection still imports a real 0 reading (#118)', () {
      const csv =
          'na;p;po4g;po4er;analysis_date;sample_id\n'
          '11127;0;0;0;2026-06-01 15:36:59;X1\n';
      final r = parseIcpCsv(csv, IcpImportFormat.faunaMarin);
      expect(r.values['phosphate'], 0);
    });

    test('the two importers agree on phosphate for one analysis (#118)', () {
      // Both files below are the real exports of the same July sample, where
      // po4g (0,021) and po4er (0,0953526) differ by 4.5x. ZIMS publishes
      // po4er as "Orthophosphate (PO4)"; importing po4g made the same report
      // land as two different readings depending on the chosen format. (The
      // two formats agree on every physically consistent report — only a
      // po4g above its own total P, which ZIMS cannot see, parts them.)
      final fm = parseIcpCsv(_faunaMarinCsvJuly, IcpImportFormat.faunaMarin);
      final zims = parseIcpCsv(_zimsCsvJuly, IcpImportFormat.zims);
      expect(fm.values['phosphate'], 0.0953526);
      expect(zims.values['phosphate'], 0.0953526);
      // Elemental P (0,0311) backs po4er at PO4 = P x 3.066 — the agreement
      // is arithmetic, not a coincidence of this one file.
      expect(fm.values['phosphate'], closeTo(0.0311 * 3.066, 1e-4));
    });

    test('a non-numeric po4er falls through to po4g (#101)', () {
      // Labs print `<0,01` at the detection limit — presence must not block
      // the fallback the way `??` on the raw cells did.
      const csv =
          'na;po4g;po4er;analysis_date;sample_id\n'
          '11127;0,044457;<0,01;2026-06-01 15:36:59;X1\n';
      final r = parseIcpCsv(csv, IcpImportFormat.faunaMarin);
      expect(r.values['phosphate'], 0.044457);
      expect(r.skipped, isNot(contains('po4er')));
    });

    test('phosphate never silently disappears: unparseable po4 pair is '
        'reported as skipped (#101)', () {
      const csv =
          'na;po4g;po4er;analysis_date;sample_id\n'
          '11127;<0,01;<0,01;2026-06-01 15:36:59;X1\n';
      final r = parseIcpCsv(csv, IcpImportFormat.faunaMarin);
      expect(r.values.containsKey('phosphate'), isFalse);
      expect(r.skipped, contains('po4er'));
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

    test('reconciles the two phosphate rows the same way as the wide '
        'export, whatever their order (#118)', () {
      // "Phosphates" (the po4g gauge) is listed *before* the calculated
      // "Orthophosphate (PO4)" in the real file — last-row-wins would have
      // been luck, not a rule.
      final r = parseIcpCsv(_zimsCsvJuly, IcpImportFormat.zims);
      expect(r.values['phosphate'], 0.0953526);
      expect(r.skipped, isNot(contains('Phosphates')));
      // ...and the same on the June report, where both figures are five
      // times smaller but keep the same relation.
      final june = parseIcpCsv(_zimsCsvJune26, IcpImportFormat.zims);
      expect(june.values['phosphate'], 0.03066);
    });

    test('imports alkalinity from the meq/L Carbonate Hardness row (#118)', () {
      // 1 meq/L = 2.8 dKH — the row the wide export prints as
      // alkalinityDkH 8.6.
      final zims = parseIcpCsv(_zimsCsvJuly, IcpImportFormat.zims);
      expect(zims.values['alkalinity'], closeTo(8.6, 0.005));
      expect(zims.skipped, isNot(contains('Carbonate Hardness')));
      final fm = parseIcpCsv(_faunaMarinCsvJuly, IcpImportFormat.faunaMarin);
      expect(fm.values['alkalinity'], 8.6);
    });

    test('a dKH-labeled alkalinity row is taken as dKH, not converted', () {
      const csv =
          '"Date","Measurement","MeasurementValue","UnitofMeasure"\n'
          '"2026-06-26","Alkalinity","8.6","dKH"\n';
      final r = parseIcpCsv(csv, IcpImportFormat.zims);
      expect(r.values['alkalinity'], 8.6);
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
      // Fauna Marin's name for the photometric gauge (the wide export's
      // po4g) — plural, and it must not fall through to "not imported".
      expect(zimsMeasurementKey('Phosphates'), 'phosphate');
      expect(zimsMeasurementKey('Carbonate Hardness'), 'alkalinity');
      expect(zimsMeasurementKey('Rubidium (Rb)'), isNull);
      expect(zimsMeasurementKey('Phosphorus (P)'), isNull);
    });

    test('alkalinity unit factors', () {
      expect(zimsAlkalinityFactor('milliequivalents per litre'), 2.8);
      expect(zimsAlkalinityFactor('meq/L'), 2.8);
      // Anything else is taken as the app's own unit, dKH.
      expect(zimsAlkalinityFactor('dKH'), 1);
      expect(zimsAlkalinityFactor(''), 1);
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
