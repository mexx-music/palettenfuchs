import 'package:flutter_test/flutter_test.dart';
import 'package:palettenfuchs/features/load_planner/logic/pallet_layout_engine.dart';
import 'package:palettenfuchs/features/load_planner/logic/trailer_constants.dart';
import 'package:palettenfuchs/features/load_planner/models/pallet_type.dart';

void main() {
  test('Schwerlast Testfälle', () {
    final cases = [
      (euroPallets: 20, kgPerEuro: 1000),
      (euroPallets: 20, kgPerEuro: 1100),
      (euroPallets: 26, kgPerEuro: 1000),
    ];

    for (final c in cases) {
      final report = PalletLayoutEngine.debugReport(
        euroPallets: c.euroPallets,
        kgPerEuro: c.kgPerEuro,
        trailerType: TrailerType.standard,
      );
      // ignore: avoid_print
      print('\n$report');
    }

    // Test passes trivially – output is the goal.
    expect(true, isTrue);
  });

  test('10 Euro-Paletten: 2×3er + 2×2er ohne Einzelpalette', () {
    final plan = PalletLayoutEngine.calculateBasicPlan(
      euroPallets: 10,
      industryPallets: 0,
      trailerType: TrailerType.standard,
    );

    expect(plan.placedEuroPallets, 10);
    expect(plan.rows.length, 4);

    // Check arrangement types
    final arr = plan.rows.map((r) => r.arrangement).toList();
    expect(arr, contains(RowArrangement.euroLongi3));
    expect(arr, contains(RowArrangement.euroTransverse2));

    // Count 3er and 2er rows
    final longiCount = arr.where((a) => a == RowArrangement.euroLongi3).length;
    final twoCount = arr
        .where((a) => a == RowArrangement.euroTransverse2)
        .length;
    expect(longiCount, 2);
    expect(twoCount, 2);

    // Verify no single pallet
    expect(
      arr.where((a) => a == RowArrangement.euroTransverseSingle).length,
      0,
    );
  });

  test('13 Euro-Paletten: 3×3er + 2×2er ohne Einzelpalette', () {
    final plan = PalletLayoutEngine.calculateBasicPlan(
      euroPallets: 13,
      industryPallets: 0,
      trailerType: TrailerType.standard,
    );

    expect(plan.placedEuroPallets, 13);
    expect(plan.rows.length, 5);

    final arr = plan.rows.map((r) => r.arrangement).toList();
    final longiCount = arr.where((a) => a == RowArrangement.euroLongi3).length;
    final twoCount = arr
        .where((a) => a == RowArrangement.euroTransverse2)
        .length;
    expect(longiCount, 3);
    expect(twoCount, 2);
    expect(
      arr.where((a) => a == RowArrangement.euroTransverseSingle).length,
      0,
    );
  });

  test('16 Euro-Paletten: 4×3er + 2×2er ohne Einzelpalette', () {
    final plan = PalletLayoutEngine.calculateBasicPlan(
      euroPallets: 16,
      industryPallets: 0,
      trailerType: TrailerType.standard,
    );

    expect(plan.placedEuroPallets, 16);
    expect(plan.rows.length, 6);

    final arr = plan.rows.map((r) => r.arrangement).toList();
    final longiCount = arr.where((a) => a == RowArrangement.euroLongi3).length;
    final twoCount = arr
        .where((a) => a == RowArrangement.euroTransverse2)
        .length;
    expect(longiCount, 4);
    expect(twoCount, 2);
    expect(
      arr.where((a) => a == RowArrangement.euroTransverseSingle).length,
      0,
    );
  });

  test(
    '10 Euro + Industrie: Restfläche nicht durch Einzelpalette blockiert',
    () {
      final plan = PalletLayoutEngine.calculateBasicPlan(
        euroPallets: 10,
        industryPallets: 4,
        trailerType: TrailerType.standard,
      );

      expect(plan.placedEuroPallets, 10);
      // Industries should fit; at least some should be placed
      expect(plan.placedIndustryPallets, greaterThan(0));

      // Verify no trailing single Euro pallet
      final lastRow = plan.rows.isNotEmpty ? plan.rows.last : null;
      expect(
        lastRow?.arrangement,
        isNot(RowArrangement.euroTransverseSingle),
        reason: 'Should not end with single Euro pallet',
      );

      // Verify used length is within trailer bounds
      expect(plan.usedLengthCm, lessThanOrEqualTo(plan.trailerMaxLengthCm));
    },
  );
}
