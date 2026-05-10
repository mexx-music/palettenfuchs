import 'package:flutter/material.dart';
import 'package:palettenfuchs/localization/app_language.dart';
import 'package:palettenfuchs/localization/app_strings.dart';

class PalletActionMenu extends StatelessWidget {
  final Offset position;
  final VoidCallback onMoveForward;
  final VoidCallback onMoveBackward;
  final VoidCallback onRotate;
  final VoidCallback onClearSelection;
  final bool canMoveForward;
  final bool canMoveBackward;
  final bool canRotate;
  final AppLanguage language;

  const PalletActionMenu({
    super.key,
    required this.position,
    required this.onMoveForward,
    required this.onMoveBackward,
    required this.onRotate,
    required this.onClearSelection,
    this.canMoveForward = true,
    this.canMoveBackward = true,
    this.canRotate = true,
    required this.language,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Dismissible backdrop
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              color: Colors.black.withAlpha(1),
            ),
          ),
          // Menu
          Positioned(
            left: position.dx,
            top: position.dy,
            child: Card(
              elevation: 4,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMenuItem(
                    context,
                    AppStrings.get(language, 'pallet_move_forward'),
                    Icons.arrow_upward,
                    onMoveForward,
                    enabled: canMoveForward,
                  ),
                  const Divider(height: 1),
                  _buildMenuItem(
                    context,
                    AppStrings.get(language, 'pallet_move_backward'),
                    Icons.arrow_downward,
                    onMoveBackward,
                    enabled: canMoveBackward,
                  ),
                  const Divider(height: 1),
                  _buildMenuItem(
                    context,
                    AppStrings.get(language, 'pallet_rotate'),
                    Icons.rotate_right,
                    onRotate,
                    enabled: canRotate,
                  ),
                  const Divider(height: 1),
                  _buildMenuItem(
                    context,
                    AppStrings.get(language, 'pallet_clear_selection'),
                    Icons.clear,
                    onClearSelection,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onTap, {
    bool enabled = true,
  }) {
    return InkWell(
      onTap: enabled ? () {
        Navigator.of(context).pop();
        onTap();
      } : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: enabled ? Colors.black87 : Colors.grey),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: enabled ? Colors.black87 : Colors.grey,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
