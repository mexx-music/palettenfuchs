import 'package:flutter_test/flutter_test.dart';
import 'package:palettenfuchs/features/load_planner/logic/manual_pallet_service.dart';
import 'package:palettenfuchs/features/load_planner/logic/pallet_layout_engine.dart';
import 'package:palettenfuchs/features/load_planner/logic/trailer_constants.dart';
import 'package:palettenfuchs/features/load_planner/models/pallet_type.dart';

void main() {
  group('Frigo 29 Euro + 3 Industrie', () {
    final plan = PalletLayoutEngine.calculateBasicPlan(
      euroPallets: 29,
      industryPallets: 3,
      trailerType: TrailerType.frigo,
    );

    test('alle 29 Euro und 3 Industrie sind platziert', () {
      expect(plan.placedEuroPallets, 29);
      expect(plan.placedIndustryPallets, 3);
      expect(plan.unplacedEuroPallets, 0);
      expect(plan.unplacedIndustryPallets, 0);
    });

    test('usedLength == 1340 cm (exakt Frigo-Innenlänge)', () {
      expect(plan.usedLengthCm, 1340);
      expect(plan.isOverLimit, isFalse);
      expect(plan.trailerMaxLengthCm, 1340);
    });

    test('Sequenz enthält genau eine mixedEuro2Industry1-Reihe', () {
      final mixed = plan.rows
          .where((r) => r.arrangement == RowArrangement.mixedEuro2Industry1)
          .toList();
      expect(mixed.length, 1);
      expect(mixed.first.palletCount, 3);
      expect(mixed.first.lengthCm, 160);
    });

    test('Sequenz: 9× longi3 + 1× mixed + 1× industryLongi2', () {
      expect(plan.rows.length, 11);
      for (var i = 0; i < 9; i++) {
        expect(plan.rows[i].arrangement, RowArrangement.euroLongi3);
      }
      expect(plan.rows[9].arrangement, RowArrangement.mixedEuro2Industry1);
      expect(plan.rows[10].arrangement, RowArrangement.industryLongi2);
    });

    test('Free-mode-Geometrie der Mixed-Zone überschneidet sich nicht', () {
      final pallets = ManualPalletService.extractFreePallets(plan);

      // Genau 32 Paletten insgesamt (27 + 3 + 2).
      expect(pallets.length, 32);

      final (ok, errorMsg) = ManualPalletService.validateFreePallets(
        pallets,
        TrailerType.frigo.trailerLengthCm,
        TrailerType.frigo.trailerWidthCm,
      );
      expect(ok, isTrue, reason: errorMsg);
    });
  });

  group('Standard 29 Euro + 3 Industrie', () {
    test('Standard-Trailer nutzt keine Mixed-Zone (kein erzwungener Fix)', () {
      final plan = PalletLayoutEngine.calculateBasicPlan(
        euroPallets: 29,
        industryPallets: 3,
        trailerType: TrailerType.standard,
      );
      final mixed = plan.rows
          .where((r) => r.arrangement == RowArrangement.mixedEuro2Industry1)
          .toList();
      expect(mixed, isEmpty);
    });
  });

  group('Frigo Nachbar-Fälle bleiben unverändert', () {
    test('33 Euro + 0 Industrie (Frigo) verwendet keine Mixed-Zone', () {
      final plan = PalletLayoutEngine.calculateBasicPlan(
        euroPallets: 33,
        industryPallets: 0,
        trailerType: TrailerType.frigo,
      );
      final mixed = plan.rows
          .where((r) => r.arrangement == RowArrangement.mixedEuro2Industry1)
          .toList();
      expect(mixed, isEmpty);
      expect(plan.placedEuroPallets, 33);
    });

    test('27 Euro + 3 Industrie (Frigo) passt regulär ohne Mixed-Zone', () {
      final plan = PalletLayoutEngine.calculateBasicPlan(
        euroPallets: 27,
        industryPallets: 3,
        trailerType: TrailerType.frigo,
      );
      final mixed = plan.rows
          .where((r) => r.arrangement == RowArrangement.mixedEuro2Industry1)
          .toList();
      expect(mixed, isEmpty);
      expect(plan.placedEuroPallets, 27);
      expect(plan.placedIndustryPallets, 3);
    });
  });
}
