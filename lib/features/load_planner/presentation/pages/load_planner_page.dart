import 'package:flutter/material.dart';
import 'package:palettenfuchs/localization/app_language.dart';
import 'package:palettenfuchs/localization/app_strings.dart';
import '../../logic/pallet_layout_engine.dart';
import '../../logic/trailer_constants.dart';
import '../../models/load_plan.dart';
import '../../models/manual_load_seed.dart';
import '../../models/placed_pallet.dart';
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
  late ManualLoadSeed _manualSeed;
  late LoadPlan _currentPlan;

  @override
  void initState() {
    super.initState();
    _currentPlan = LoadPlan.empty;
    _manualSeed = ManualLoadSeed.empty();
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

  void _onManualPalletsAccepted(List<PlacedPallet> pallets) {
    setState(() {
      _currentPlan = _currentPlan.copyWith(manualPallets: pallets);
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
            TrailerLoadView(
              loadPlan: _currentPlan,
              language: lang,
              onManualPalletsAccepted: _onManualPalletsAccepted,
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

