import 'package:flutter/material.dart';
import 'package:palettenfuchs/localization/app_language.dart';
import 'package:palettenfuchs/localization/app_strings.dart';

class StartPage extends StatelessWidget {
  final AppLanguage language;
  final ValueChanged<AppLanguage> onLanguageChanged;
  final VoidCallback onStart;

  const StartPage({
    super.key,
    required this.language,
    required this.onLanguageChanged,
    required this.onStart,
  });

  String _s(String key) => AppStrings.get(language, key);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Language picker aligned right
                  Align(
                    alignment: Alignment.centerRight,
                    child: _LanguagePicker(
                      selected: language,
                      onChanged: onLanguageChanged,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Fox image
                  _FoxImage(),
                  const SizedBox(height: 28),

                  // Title
                  Text(
                    _s('start_title'),
                    textAlign: TextAlign.center,
                    style: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Subtitle
                  Text(
                    _s('start_subtitle'),
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurface.withAlpha(178),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Feature list
                  _FeatureItem(
                    icon: Icons.table_chart_outlined,
                    label: _s('start_feature_load_plan'),
                    color: scheme.primary,
                  ),
                  const SizedBox(height: 12),
                  _FeatureItem(
                    icon: Icons.balance_outlined,
                    label: _s('start_feature_axle_weight'),
                    color: scheme.primary,
                  ),
                  const SizedBox(height: 12),
                  _FeatureItem(
                    icon: Icons.touch_app_outlined,
                    label: _s('start_feature_manual_mode'),
                    color: scheme.primary,
                  ),
                  const SizedBox(height: 40),

                  // Start button
                  FilledButton(
                    onPressed: onStart,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      textStyle: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(_s('start_button')),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FoxImage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220, maxHeight: 220),
        child: Image.asset(
          'assets/images/pal_fuchs_intro.png',
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => _FoxFallback(),
        ),
      ),
    );
  }
}

class _FoxFallback extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 180,
      height: 180,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.local_shipping_outlined,
        size: 80,
        color: scheme.onPrimaryContainer,
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _FeatureItem({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ],
    );
  }
}

class _LanguagePicker extends StatelessWidget {
  final AppLanguage selected;
  final ValueChanged<AppLanguage> onChanged;

  const _LanguagePicker({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<AppLanguage>(
        value: selected,
        icon: const Icon(Icons.language, size: 18),
        iconSize: 18,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
        items: AppLanguage.values
            .map((lang) => DropdownMenuItem<AppLanguage>(
                  value: lang,
                  child: Text(lang.code),
                ))
            .toList(),
        onChanged: (lang) {
          if (lang != null) onChanged(lang);
        },
      ),
    );
  }
}
