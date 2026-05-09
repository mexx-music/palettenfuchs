import 'package:flutter/material.dart';

/// Karte für eine Ladevariante
class VariantCard extends StatelessWidget {
  final String title;
  final double weight;
  final double grogScore;
  final bool isValid;
  final VoidCallback onTap;

  const VariantCard({
    super.key,
    required this.title,
    required this.weight,
    required this.grogScore,
    required this.isValid,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isValid ? 2 : 0,
      child: InkWell(
        onTap: isValid ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),

              Text(
                'Gewicht: ${weight.toStringAsFixed(0)} kg',
                style: Theme.of(context).textTheme.bodySmall,
              ),

              Text(
                'Stabilitäts-Score: ${grogScore.toStringAsFixed(1)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),

              const SizedBox(height: 8),

              // Status-Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isValid ? Colors.green[100] : Colors.red[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isValid ? '✓ Gültig' : '✗ Ungültig',
                  style: TextStyle(
                    fontSize: 12,
                    color: isValid ? Colors.green[700] : Colors.red[700],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
