import 'package:flutter/material.dart';
import 'package:palettenfuchs/localization/app_language.dart';
import 'package:palettenfuchs/localization/app_strings.dart';
import '../../logic/pallet_layout_engine.dart';
import '../../logic/trailer_constants.dart';

const int _maxEuro = PalletLayoutEngine.maxEuroPallets;
const int _maxIndustry = PalletLayoutEngine.maxIndustryPallets;

class PalletInputPanel extends StatefulWidget {
  final int euroPallets;
  final int industryPallets;
  final bool optimizeAxleLoad;
  final int kgPerEuro;
  final int kgPerIndustry;
  final TrailerType trailerType;
  final AppLanguage language;
  final Function(int) onEuroPalletsChanged;
  final Function(int) onIndustryPalletsChanged;
  final Function(bool) onOptimizeAxleLoadChanged;
  final Function(int) onKgPerEuroChanged;
  final Function(int) onKgPerIndustryChanged;
  final Function(TrailerType) onTrailerTypeChanged;

  const PalletInputPanel({
    super.key,
    required this.euroPallets,
    required this.industryPallets,
    required this.optimizeAxleLoad,
    required this.kgPerEuro,
    required this.kgPerIndustry,
    required this.trailerType,
    required this.language,
    required this.onEuroPalletsChanged,
    required this.onIndustryPalletsChanged,
    required this.onOptimizeAxleLoadChanged,
    required this.onKgPerEuroChanged,
    required this.onKgPerIndustryChanged,
    required this.onTrailerTypeChanged,
  });

  @override
  State<PalletInputPanel> createState() => _PalletInputPanelState();
}

class _PalletInputPanelState extends State<PalletInputPanel> {
  late TextEditingController _euroController;
  late TextEditingController _industryController;
  late TextEditingController _kgEuroController;
  late TextEditingController _kgIndustryController;

  bool _euroWarning = false;
  bool _industryWarning = false;

  String _s(String key) => AppStrings.get(widget.language, key);

  @override
  void initState() {
    super.initState();
    _euroController = TextEditingController(
      text: widget.euroPallets.toString(),
    );
    _industryController = TextEditingController(
      text: widget.industryPallets.toString(),
    );
    _kgEuroController = TextEditingController(
      text: widget.kgPerEuro == 0 ? '' : widget.kgPerEuro.toString(),
    );
    _kgIndustryController = TextEditingController(
      text: widget.kgPerIndustry == 0 ? '' : widget.kgPerIndustry.toString(),
    );
  }

  @override
  void didUpdateWidget(PalletInputPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((int.tryParse(_euroController.text) ?? 0) != widget.euroPallets) {
      _euroController.text = widget.euroPallets.toString();
    }
    if ((int.tryParse(_industryController.text) ?? 0) !=
        widget.industryPallets) {
      _industryController.text = widget.industryPallets.toString();
    }
    if ((int.tryParse(_kgEuroController.text) ?? 0) != widget.kgPerEuro) {
      _kgEuroController.text =
          widget.kgPerEuro == 0 ? '' : widget.kgPerEuro.toString();
    }
    if ((int.tryParse(_kgIndustryController.text) ?? 0) !=
        widget.kgPerIndustry) {
      _kgIndustryController.text =
          widget.kgPerIndustry == 0 ? '' : widget.kgPerIndustry.toString();
    }
  }

  @override
  void dispose() {
    _euroController.dispose();
    _industryController.dispose();
    _kgEuroController.dispose();
    _kgIndustryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _s('pallets_enter'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),

            // Auflieger-Typ
            Text(
              _s('trailer_type'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            SegmentedButton<TrailerType>(
              segments: TrailerType.values
                  .map((t) => ButtonSegment<TrailerType>(
                        value: t,
                        label: Text(_s(t.name)),
                      ))
                  .toList(),
              selected: {widget.trailerType},
              onSelectionChanged: (Set<TrailerType> s) =>
                  widget.onTrailerTypeChanged(s.first),
            ),
            const SizedBox(height: 16),

            // Achslast optimieren Toggle
            SwitchListTile(
              title: Text(_s('optimize_axle_load')),
              subtitle: Text(_s('optimize_axle_load_hint')),
              value: widget.optimizeAxleLoad,
              onChanged: widget.onOptimizeAxleLoadChanged,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),

            // Euro-Paletten Anzahl
            _buildPalletInput(
              label: _s('euro_pallet'),
              controller: _euroController,
              onChanged: (v) {
                final parsed = int.tryParse(v) ?? 0;
                setState(() =>
                    _euroWarning = parsed > widget.trailerType.maxEuroPallets);
                widget.onEuroPalletsChanged(parsed.clamp(0, _maxEuro));
              },
              showWarning: _euroWarning,
              warningText:
                  'Max. ${widget.trailerType.maxEuroPallets} ${_s('euro_pallet')}',
            ),
            const SizedBox(height: 16),

            // Industrie-Paletten Anzahl
            _buildPalletInput(
              label: _s('industry_pallet'),
              controller: _industryController,
              onChanged: (v) {
                final parsed = int.tryParse(v) ?? 0;
                setState(() => _industryWarning = parsed > _maxIndustry);
                widget
                    .onIndustryPalletsChanged(parsed.clamp(0, _maxIndustry));
              },
              showWarning: _industryWarning,
              warningText: 'Max. $_maxIndustry ${_s('industry_pallet')}',
            ),
            const SizedBox(height: 8),

            // Einklappbarer Gewichtsbereich
            ExpansionTile(
              title: Text(_s('optional_weight')),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(top: 4, bottom: 8),
              children: [
                _buildKgInput(
                  label: 'kg / ${_s('euro_pallet')}',
                  controller: _kgEuroController,
                  onChanged: (v) =>
                      widget.onKgPerEuroChanged(int.tryParse(v) ?? 0),
                ),
                const SizedBox(height: 12),
                _buildKgInput(
                  label: 'kg / ${_s('industry_pallet')}',
                  controller: _kgIndustryController,
                  onChanged: (v) =>
                      widget.onKgPerIndustryChanged(int.tryParse(v) ?? 0),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPalletInput({
    required String label,
    required TextEditingController controller,
    required Function(String) onChanged,
    bool showWarning = false,
    String warningText = '',
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(labelText: _s('quantity')),
          keyboardType: TextInputType.number,
          onChanged: onChanged,
        ),
        if (showWarning) ...[
          const SizedBox(height: 4),
          Text(
            warningText,
            style: TextStyle(color: Colors.orange[800], fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _buildKgInput({
    required String label,
    required TextEditingController controller,
    required Function(String) onChanged,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label, suffixText: 'kg'),
      keyboardType: TextInputType.number,
      onChanged: onChanged,
    );
  }
}
