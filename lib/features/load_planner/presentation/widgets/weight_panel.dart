import 'package:flutter/material.dart';
import '../../logic/weight_engine.dart';
import '../../models/load_plan.dart';
import '../../models/pallet_type.dart';

class WeightPanel extends StatelessWidget {
  final LoadPlan loadPlan;
  final int kgPerEuro;
  final int kgPerIndustry;

  const WeightPanel({
    super.key,
    required this.loadPlan,
    required this.kgPerEuro,
    required this.kgPerIndustry,
  });

  int get _euroCount => loadPlan.rows
      .where((r) =>
          r.arrangement == RowArrangement.euroLongi3 ||
          r.arrangement == RowArrangement.euroTransverse2 ||
          r.arrangement == RowArrangement.euroTransverseSingle)
      .fold(0, (s, r) => s + r.palletCount);

  int get _industryCount => loadPlan.rows
      .where((r) =>
          r.arrangement == RowArrangement.industryLongi2 ||
          r.arrangement == RowArrangement.industrySingle)
      .fold(0, (s, r) => s + r.palletCount);

  @override
  Widget build(BuildContext context) {
    final percentUsed =
        (loadPlan.usedLengthCm / loadPlan.trailerMaxLengthCm * 100)
            .clamp(0, 150);

    final bool hasWeight = kgPerEuro > 0 || kgPerIndustry > 0;
    final int euroWeight = _euroCount * kgPerEuro;
    final int industryWeight = _industryCount * kgPerIndustry;
    final int totalWeight = euroWeight + industryWeight;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ladung Status',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),

            // Paletten-Info
            _infoRow(context, 'Gesamtpaletten:', '${loadPlan.totalPallets}',
                bold: true),
            const SizedBox(height: 8),

            // Längen-Info
            _infoRow(
              context,
              'Genutzte Länge:',
              '${loadPlan.usedLengthCm.toStringAsFixed(0)} cm',
              bold: true,
            ),
            const SizedBox(height: 8),

            _infoRow(
              context,
              'Freie Länge:',
              '${loadPlan.remainingLengthCm.toStringAsFixed(0)} cm',
            ),
            const SizedBox(height: 16),

            // Fortschrittsbalken
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (percentUsed / 150).clamp(0, 1),
                minHeight: 8,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  loadPlan.isOverLimit ? Colors.red : Colors.green,
                ),
              ),
            ),
            const SizedBox(height: 8),

            Text(
              '${percentUsed.toStringAsFixed(1)}% ausgelastet',
              style: Theme.of(context).textTheme.bodySmall,
            ),

            // Warnung nicht platzierbare Paletten
            if (loadPlan.hasUnplaced) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.red[400]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning, color: Colors.red[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Nicht alle Paletten passen auf die Ladefläche.',
                            style: TextStyle(
                              color: Colors.red[700],
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (loadPlan.unplacedEuroPallets > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Nicht platzierte Euro-Paletten: ${loadPlan.unplacedEuroPallets}',
                        style: TextStyle(color: Colors.red[700], fontSize: 12),
                      ),
                    ],
                    if (loadPlan.unplacedIndustryPallets > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Nicht platzierte Industrie-Paletten: ${loadPlan.unplacedIndustryPallets}',
                        style: TextStyle(color: Colors.red[700], fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // Gewichtsbereich – nur wenn mindestens ein kg-Wert eingegeben
            if (hasWeight) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 4),
              Text(
                'Gewichte',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              _infoRow(context, 'Euro-Paletten:', '$euroWeight kg'),
              const SizedBox(height: 6),
              _infoRow(context, 'Industrie-Paletten:', '$industryWeight kg'),
              const SizedBox(height: 6),
              _infoRow(context, 'Gesamtgewicht:', '$totalWeight kg',
                  bold: true),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 4),
              Text(
                'Achslast-Schätzung (Hebelmodell)',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Grobe Fahrerhilfe – kein rechtssicherer Wiegenachweis.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 10),
              Builder(builder: (context) {
                final dist = WeightEngine.calculateDistribution(
                  loadPlan: loadPlan,
                  kgPerEuro: kgPerEuro,
                  kgPerIndustry: kgPerIndustry,
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRow(
                      context,
                      'Sattellast / Frontlast (ca.):',
                      '${dist.frontLoadKg.round()} kg'
                          ' (${dist.frontPercent.toStringAsFixed(1)} %)',
                    ),
                    const SizedBox(height: 6),
                    _infoRow(
                      context,
                      'Trailer-Hinterachse (ca.):',
                      '${dist.rearLoadKg.round()} kg'
                          ' (${dist.rearPercent.toStringAsFixed(1)} %)',
                    ),
                    if (dist.isFrontCritical) ...[
                      const SizedBox(height: 10),
                      _warningBox(
                        context,
                        color: Colors.red,
                        icon: Icons.warning,
                        message:
                            'Sattellast wahrscheinlich zu hoch – Ladung weiter'
                            ' nach hinten verteilen oder Gewicht prüfen.',
                      ),
                    ] else if (dist.isFrontWarning) ...[
                      const SizedBox(height: 10),
                      _warningBox(
                        context,
                        color: Colors.orange,
                        icon: Icons.warning_amber,
                        message:
                            'Achtung: Sattellast nähert sich dem Grenzbereich.',
                      ),
                    ],
                  ],
                );
              }),
            ],

            // Warnung bei Überladung
            if (loadPlan.isOverLimit) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.red[400]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ladefläche überschritten – bitte Anzahl reduzieren.',
                        style: TextStyle(color: Colors.red[700], fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _warningBox(
    BuildContext context, {
    required MaterialColor color,
    required IconData icon,
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color[100],
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color[400]!),
      ),
      child: Row(
        children: [
          Icon(icon, color: color[800], size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color[800], fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(
    BuildContext context,
    String label,
    String value, {
    bool bold = false,
  }) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        Text(value, style: style),
      ],
    );
  }
}
