import 'package:flutter/material.dart';
import '../../logic/pallet_layout_engine.dart';
import '../../logic/trailer_constants.dart';
import '../../models/pallet_type.dart';

const int _maxEuro = PalletLayoutEngine.maxEuroPallets;
const int _maxIndustry = PalletLayoutEngine.maxIndustryPallets;

class PalletInputPanel extends StatefulWidget {
  final int euroPallets;
  final int industryPallets;
  final bool optimizeAxleLoad;
  final int kgPerEuro;
  final int kgPerIndustry;
  final TrailerType trailerType;
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
    // Nur schreiben wenn der geparste Textwert vom Widget-Wert abweicht,
    // damit Cursor-Position und laufende Eingabe erhalten bleiben.
    if ((int.tryParse(_euroController.text) ?? 0) != widget.euroPallets) {
      _euroController.text = widget.euroPallets.toString();
    }
    if ((int.tryParse(_industryController.text) ?? 0) != widget.industryPallets) {
      _industryController.text = widget.industryPallets.toString();
    }
    if ((int.tryParse(_kgEuroController.text) ?? 0) != widget.kgPerEuro) {
      _kgEuroController.text =
          widget.kgPerEuro == 0 ? '' : widget.kgPerEuro.toString();
    }
    if ((int.tryParse(_kgIndustryController.text) ?? 0) != widget.kgPerIndustry) {
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
              'Paletten eingeben',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),

            // Auflieger-Typ
            Text(
              'Auflieger-Typ',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            SegmentedButton<TrailerType>(
              segments: TrailerType.values
                  .map((t) => ButtonSegment<TrailerType>(
                        value: t,
                        label: Text(t.label),
                      ))
                  .toList(),
              selected: {widget.trailerType},
              onSelectionChanged: (Set<TrailerType> s) =>
                  widget.onTrailerTypeChanged(s.first),
            ),
            const SizedBox(height: 16),

            // Achslast optimieren Toggle
            SwitchListTile(
              title: const Text('Achslast optimieren'),
              subtitle: const Text(
                'Verteilt die Paletten so, dass die Ladefläche besser genutzt und die Achslast vorbereitet wird.',
              ),
              value: widget.optimizeAxleLoad,
              onChanged: widget.onOptimizeAxleLoadChanged,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),

            // Euro-Paletten Anzahl
            _buildPalletInput(
              label: PalletType.euro.label,
              controller: _euroController,
              onChanged: (v) {
                final parsed = int.tryParse(v) ?? 0;
                setState(() =>
                    _euroWarning = parsed > widget.trailerType.maxEuroPallets);
                widget.onEuroPalletsChanged(parsed.clamp(0, _maxEuro));
              },
              showWarning: _euroWarning,
              warningText:
                  'Maximal ${widget.trailerType.maxEuroPallets} Euro-Paletten',
            ),
            const SizedBox(height: 16),

            // Industrie-Paletten Anzahl
            _buildPalletInput(
              label: PalletType.industrial.label,
              controller: _industryController,
              onChanged: (v) {
                final parsed = int.tryParse(v) ?? 0;
                setState(() => _industryWarning = parsed > _maxIndustry);
                widget.onIndustryPalletsChanged(parsed.clamp(0, _maxIndustry));
              },
              showWarning: _industryWarning,
              warningText: 'Maximal $_maxIndustry Industrie-Paletten',
            ),
            const SizedBox(height: 8),

            // Einklappbarer Gewichtsbereich
            ExpansionTile(
              title: const Text('Gewicht optional'),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(top: 4, bottom: 8),
              children: [
                _buildKgInput(
                  label: 'kg pro Euro-Palette',
                  controller: _kgEuroController,
                  onChanged: (v) =>
                      widget.onKgPerEuroChanged(int.tryParse(v) ?? 0),
                ),
                const SizedBox(height: 12),
                _buildKgInput(
                  label: 'kg pro Industrie-Palette',
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
          decoration: const InputDecoration(labelText: 'Anzahl'),
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
      decoration: InputDecoration(
        labelText: label,
        suffixText: 'kg',
      ),
      keyboardType: TextInputType.number,
      onChanged: onChanged,
    );
  }
}
