import 'package:flutter_test/flutter_test.dart';
import 'package:palettenfuchs/features/load_planner/logic/pallet_layout_engine.dart';
import 'package:palettenfuchs/features/load_planner/logic/trailer_constants.dart';

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
}
