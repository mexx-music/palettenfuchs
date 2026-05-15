import 'package:flutter_test/flutter_test.dart';
import 'package:palettenfuchs/features/load_planner/logic/manual_pallet_service.dart';
import 'package:palettenfuchs/features/load_planner/logic/pallet_layout_engine.dart';
import 'package:palettenfuchs/features/load_planner/logic/trailer_constants.dart';
import 'package:palettenfuchs/features/load_planner/models/load_plan.dart';
import 'package:palettenfuchs/features/load_planner/models/pallet_type.dart';

void main() {
  group('29 Euro + 3 Industrie (reales Hecklayout)', () {
    void expect29Sequence(LoadPlan plan) {
      expect(plan.rows.length, 12);
      for (var i = 0; i < 8; i++) {
        expect(plan.rows[i].arrangement, RowArrangement.euroLongi3,
            reason: 'row[$i] should be euroLongi3');
      }
      expect(plan.rows[8].arrangement, RowArrangement.euroTransverse2);
      expect(plan.rows[9].arrangement, RowArrangement.euroTransverse2);
      expect(plan.rows[10].arrangement, RowArrangement.industryLongi2);
      expect(plan.rows[11].arrangement, RowArrangement.mixedEuro1Industry1Tail);
    }

    test('Frigo: alle Paletten platziert, usedLength=1320', () {
      final plan = PalletLayoutEngine.calculateBasicPlan(
        euroPallets: 29,
        industryPallets: 3,
        trailerType: TrailerType.frigo,
      );
      expect(plan.placedEuroPallets, 29);
      expect(plan.placedIndustryPallets, 3);
      expect(plan.unplacedEuroPallets, 0);
      expect(plan.unplacedIndustryPallets, 0);
      expect(plan.hasUnplaced, isFalse);
      expect(plan.usedLengthCm, 1320);
      expect(plan.isOverLimit, isFalse);
    });

    test('Standard: alle Paletten platziert, usedLength=1320', () {
      final plan = PalletLayoutEngine.calculateBasicPlan(
        euroPallets: 29,
        industryPallets: 3,
        trailerType: TrailerType.standard,
      );
      expect(plan.placedEuroPallets, 29);
      expect(plan.placedIndustryPallets, 3);
      expect(plan.unplacedEuroPallets, 0);
      expect(plan.unplacedIndustryPallets, 0);
      expect(plan.hasUnplaced, isFalse);
      expect(plan.usedLengthCm, 1320);
      expect(plan.isOverLimit, isFalse);
    });

    test('Frigo: Sequenz 8× longi3 + 2× euroTransverse2 + 1× industryLongi2 '
        '+ 1× mixedEuro1Industry1Tail', () {
      final plan = PalletLayoutEngine.calculateBasicPlan(
        euroPallets: 29,
        industryPallets: 3,
        trailerType: TrailerType.frigo,
      );
      expect29Sequence(plan);
    });

    test('Standard: gleiche Sequenz wie Frigo', () {
      final plan = PalletLayoutEngine.calculateBasicPlan(
        euroPallets: 29,
        industryPallets: 3,
        trailerType: TrailerType.standard,
      );
      expect29Sequence(plan);
    });

    test('Heck-Mischzone: 1 Euro (80×120) + 1 Industrie (100×120), '
        'gleiche Vorderkante, kein Overlap, innerhalb Trailer', () {
      for (final trailer in [TrailerType.frigo, TrailerType.standard]) {
        final plan = PalletLayoutEngine.calculateBasicPlan(
          euroPallets: 29,
          industryPallets: 3,
          trailerType: trailer,
        );
        final pallets = ManualPalletService.extractFreePallets(plan);

        // 24 (longi3) + 4 (transverse2) + 2 (industryLongi2) + 2 (tail mix)
        expect(pallets.length, 32, reason: '$trailer pallet count');

        final tailMix = pallets
            .where((p) =>
                p.arrangement == RowArrangement.mixedEuro1Industry1Tail)
            .toList();
        expect(tailMix.length, 2, reason: '$trailer tail mix pallet count');

        final tailEuro = tailMix
            .firstWhere((p) => p.widthCm == 80.0 && p.heightCm == 120.0);
        final tailIndustry = tailMix
            .firstWhere((p) => p.widthCm == 100.0 && p.heightCm == 120.0);
        // Same front edge.
        expect(tailEuro.xCm, tailIndustry.xCm,
            reason: '$trailer front edge alignment');
        // Different y-halves (no horizontal overlap).
        expect(tailEuro.yCm, isNot(tailIndustry.yCm));
        // Industrie reaches the rear of the zone, Euro has 20 cm Luft.
        expect(tailIndustry.xCm! + tailIndustry.widthCm! -
            (tailEuro.xCm! + tailEuro.widthCm!), 20.0);

        final (ok, errorMsg) = ManualPalletService.validateFreePallets(
          pallets,
          trailer.trailerLengthCm,
          trailer.trailerWidthCm,
        );
        expect(ok, isTrue, reason: '$trailer: $errorMsg');
      }
    });
  });

  group('28 Euro + 4 Industrie (reales Hecklayout)', () {
    void expectExpectedSequence(LoadPlan plan) {
      expect(plan.rows.length, 12);
      for (var i = 0; i < 8; i++) {
        expect(plan.rows[i].arrangement, RowArrangement.euroLongi3,
            reason: 'row[$i] should be euroLongi3');
      }
      expect(plan.rows[8].arrangement, RowArrangement.industryLongi2);
      expect(plan.rows[9].arrangement, RowArrangement.industryLongi2);
      expect(plan.rows[10].arrangement, RowArrangement.euroTransverse2);
      expect(plan.rows[11].arrangement, RowArrangement.euroTransverse2);
    }

    test('Frigo: alle Paletten platziert, usedLength=1320', () {
      final plan = PalletLayoutEngine.calculateBasicPlan(
        euroPallets: 28,
        industryPallets: 4,
        trailerType: TrailerType.frigo,
      );
      expect(plan.placedEuroPallets, 28);
      expect(plan.placedIndustryPallets, 4);
      expect(plan.unplacedEuroPallets, 0);
      expect(plan.unplacedIndustryPallets, 0);
      expect(plan.hasUnplaced, isFalse);
      expect(plan.usedLengthCm, 1320);
      expect(plan.isOverLimit, isFalse);
    });

    test('Standard: alle Paletten platziert, usedLength=1320', () {
      final plan = PalletLayoutEngine.calculateBasicPlan(
        euroPallets: 28,
        industryPallets: 4,
        trailerType: TrailerType.standard,
      );
      expect(plan.placedEuroPallets, 28);
      expect(plan.placedIndustryPallets, 4);
      expect(plan.unplacedEuroPallets, 0);
      expect(plan.unplacedIndustryPallets, 0);
      expect(plan.hasUnplaced, isFalse);
      expect(plan.usedLengthCm, 1320);
      expect(plan.isOverLimit, isFalse);
    });

    test('Frigo: Sequenz 8× longi3 + 2× industryLongi2 + 2× euroTransverse2',
        () {
      final plan = PalletLayoutEngine.calculateBasicPlan(
        euroPallets: 28,
        industryPallets: 4,
        trailerType: TrailerType.frigo,
      );
      expectExpectedSequence(plan);
    });

    test('Standard: gleiche Sequenz wie Frigo', () {
      final plan = PalletLayoutEngine.calculateBasicPlan(
        euroPallets: 28,
        industryPallets: 4,
        trailerType: TrailerType.standard,
      );
      expectExpectedSequence(plan);
    });

    test('Keine einzelne hochkante Euro-Palette mehr im Hecklayout', () {
      for (final trailer in [TrailerType.frigo, TrailerType.standard]) {
        final plan = PalletLayoutEngine.calculateBasicPlan(
          euroPallets: 28,
          industryPallets: 4,
          trailerType: trailer,
        );
        expect(
          plan.rows.any(
              (r) => r.arrangement == RowArrangement.euroTransverseSingle),
          isFalse,
          reason: '$trailer should not contain euroTransverseSingle',
        );
      }
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
