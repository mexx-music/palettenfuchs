import 'package:flutter/material.dart';
import 'variant_card.dart';

class VariantGrid extends StatelessWidget {
  const VariantGrid({super.key});

  @override
  Widget build(BuildContext context) {
    // Platzhalter-Varianten für Demo
    final variants = [
      {
        'title': 'Variante 1',
        'weight': 15000.0,
        'grogScore': 85.5,
        'isValid': true,
      },
      {
        'title': 'Variante 2',
        'weight': 18500.0,
        'grogScore': 72.3,
        'isValid': true,
      },
      {
        'title': 'Variante 3',
        'weight': 42000.0,
        'grogScore': 50.0,
        'isValid': false,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ladevarianten',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.9,
          ),
          itemCount: variants.length,
          itemBuilder: (context, index) {
            final variant = variants[index];
            return VariantCard(
              title: variant['title'] as String,
              weight: variant['weight'] as double,
              grogScore: variant['grogScore'] as double,
              isValid: variant['isValid'] as bool,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${variant['title']} ausgewählt'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
