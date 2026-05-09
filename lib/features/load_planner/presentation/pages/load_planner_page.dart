import 'package:flutter/material.dart';
import '../../../../../app/app_language.dart';
import '../../logic/pallet_layout_engine.dart';
import '../../logic/trailer_constants.dart';
import '../../models/load_plan.dart';
import '../../models/manual_load_seed.dart';
import '../widgets/pallet_input_panel.dart';
import '../widgets/trailer_load_view.dart';
import '../widgets/weight_panel.dart';

class LoadPlannerPage extends StatefulWidget {
  const LoadPlannerPage({super.key});

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
  AppLanguage _language = AppLanguage.de;
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
      // Gewicht beeinflusst die Achslast-Optimierung → Plan neu berechnen
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paletten Fuchs'),
        actions: [
          _LanguageDropdown(
            selected: _language,
            onChanged: (lang) => setState(() => _language = lang),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Eingabepanel für Paletten
            PalletInputPanel(
              euroPallets: _euroPallets,
              industryPallets: _industryPallets,
              optimizeAxleLoad: _optimizeAxleLoad,
              kgPerEuro: _kgPerEuro,
              kgPerIndustry: _kgPerIndustry,
              trailerType: _trailerType,
              onEuroPalletsChanged: _onEuroPalletsChanged,
              onIndustryPalletsChanged: _onIndustryPalletsChanged,
              onOptimizeAxleLoadChanged: _onOptimizeAxleLoadChanged,
              onKgPerEuroChanged: _onKgPerEuroChanged,
              onKgPerIndustryChanged: _onKgPerIndustryChanged,
              onTrailerTypeChanged: _onTrailerTypeChanged,
            ),
            const SizedBox(height: 20),

            // Manueller Ladeplan – vorbereitender Toggle
            _ManualSeedToggle(
              enabled: _manualSeed.enabled,
              onChanged: _onManualModeChanged,
            ),
            const SizedBox(height: 20),

            // Trailerladung Draufsicht
            TrailerLoadView(loadPlan: _currentPlan),
            const SizedBox(height: 20),

            // Gewichtspanel
            WeightPanel(
              loadPlan: _currentPlan,
              kgPerEuro: _kgPerEuro,
              kgPerIndustry: _kgPerIndustry,
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
  final ValueChanged<bool> onChanged;

  const _ManualSeedToggle({
    required this.enabled,
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
                  'Manueller Ladeplan',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Switch(value: enabled, onChanged: onChanged),
              ],
            ),
            if (enabled) ...[
              const SizedBox(height: 8),
              Text(
                'Drag-and-Drop kommt später. '
                'Aktuell wird nur die Engine vorbereitet.',
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
