import 'package:flutter/material.dart';
import 'package:palettenfuchs/localization/app_language.dart';
import 'package:palettenfuchs/localization/app_strings.dart';
import '../../logic/pallet_layout_engine.dart';
import '../../logic/trailer_constants.dart';
import '../../models/load_plan.dart';
import '../../models/manual_load_seed.dart';
import '../widgets/pallet_input_panel.dart';
import '../widgets/trailer_load_view.dart';
import '../widgets/weight_panel.dart';

class LoadPlannerPage extends StatefulWidget {
  final AppLanguage language;
  final ValueChanged<AppLanguage> onLanguageChanged;

  const LoadPlannerPage({
    super.key,
    required this.language,
    required this.onLanguageChanged,
  });

  @override
  State<LoadPlannerPage> createState() => _LoadPlannerPageState();
}

class _LoadPlannerPageState extends State<LoadPlannerPage> {
  int _euroPallets = 0;
  int _industryPallets = 0;
  bool _optimizeAxleLoad = false;
  int _kgPerEuro = 0;
  int _kgPerIndustry = 0;
  TrailerType _trailerType = TrailerType.standard;
  ManualLoadSeed _manualSeed = ManualLoadSeed.empty;
  late LoadPlan _currentPlan;

  @override
  void initState() {
    super.initState();
    _currentPlan = LoadPlan.empty;
  }

  void _updatePlan() {
    setState(() {
      _currentPlan = PalletLayoutEngine.calculatePlanWithSeed(
        euroPallets: _euroPallets,
        industryPallets: _industryPallets,
        optimizeAxleLoad: _optimizeAxleLoad,
        trailerType: _trailerType,
        seed: _manualSeed,
        kgPerEuro: _kgPerEuro,
      );
    });
  }

  void _onEuroPalletsChanged(int value) {
    setState(() {
      _euroPallets = value.clamp(0, PalletLayoutEngine.maxEuroPallets);
      _updatePlan();
    });
  }

  void _onIndustryPalletsChanged(int value) {
    setState(() {
      _industryPallets =
          value.clamp(0, PalletLayoutEngine.maxIndustryPallets);
      _updatePlan();
    });
  }

  void _onOptimizeAxleLoadChanged(bool value) {
    setState(() {
      _optimizeAxleLoad = value;
      _updatePlan();
    });
  }

  void _onKgPerEuroChanged(int value) {
    setState(() {
      _kgPerEuro = value;
      if (_optimizeAxleLoad) _updatePlan();
    });
  }

  void _onKgPerIndustryChanged(int value) {
    setState(() => _kgPerIndustry = value);
  }

  void _onTrailerTypeChanged(TrailerType value) {
    setState(() {
      _trailerType = value;
      _updatePlan();
    });
  }

  void _onManualModeChanged(bool value) {
    setState(() {
      _manualSeed = _manualSeed.copyWith(enabled: value);
      _updatePlan();
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.language;
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.get(lang, 'app_title')),
        actions: [
          _LanguageDropdown(
            selected: lang,
            onChanged: widget.onLanguageChanged,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PalletInputPanel(
              euroPallets: _euroPallets,
              industryPallets: _industryPallets,
              optimizeAxleLoad: _optimizeAxleLoad,
              kgPerEuro: _kgPerEuro,
              kgPerIndustry: _kgPerIndustry,
              trailerType: _trailerType,
              language: lang,
              onEuroPalletsChanged: _onEuroPalletsChanged,
              onIndustryPalletsChanged: _onIndustryPalletsChanged,
              onOptimizeAxleLoadChanged: _onOptimizeAxleLoadChanged,
              onKgPerEuroChanged: _onKgPerEuroChanged,
              onKgPerIndustryChanged: _onKgPerIndustryChanged,
              onTrailerTypeChanged: _onTrailerTypeChanged,
            ),
            const SizedBox(height: 20),
            _ManualSeedToggle(
              enabled: _manualSeed.enabled,
              language: lang,
              onChanged: _onManualModeChanged,
            ),
            const SizedBox(height: 20),
            TrailerLoadView(
              loadPlan: _currentPlan,
              language: lang,
            ),
            const SizedBox(height: 20),
            WeightPanel(
              loadPlan: _currentPlan,
              kgPerEuro: _kgPerEuro,
              kgPerIndustry: _kgPerIndustry,
              language: lang,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _LanguageDropdown extends StatelessWidget {
  final AppLanguage selected;
  final ValueChanged<AppLanguage> onChanged;

  const _LanguageDropdown({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AppLanguage>(
          value: selected,
          icon: const SizedBox.shrink(),
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurface),
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
      ),
    );
  }
}

class _ManualSeedToggle extends StatelessWidget {
  final bool enabled;
  final AppLanguage language;
  final ValueChanged<bool> onChanged;

  const _ManualSeedToggle({
    required this.enabled,
    required this.language,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppStrings.get(language, 'manual_plan'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Switch(value: enabled, onChanged: onChanged),
              ],
            ),
            if (enabled) ...[
              const SizedBox(height: 8),
              Text(
                AppStrings.get(language, 'manual_plan_hint'),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
