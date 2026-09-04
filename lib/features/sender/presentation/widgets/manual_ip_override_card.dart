import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/neumorphic_widgets.dart';

/// Collapsible card allowing manual IP and Port configuration overrides.
class ManualIpOverrideCard extends StatelessWidget {
  final TextEditingController ipController;
  final TextEditingController portController;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;

  const ManualIpOverrideCard({
    super.key,
    required this.ipController,
    required this.portController,
    required this.isExpanded,
    required this.onToggleExpanded,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: TextButton.icon(
            onPressed: onToggleExpanded,
            icon: Icon(
              isExpanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: AppTheme.textSecondary,
              size: 18,
            ),
            label: Text(
              isExpanded
                  ? 'Hide Manual IP Settings'
                  : 'Manual Target IP Override',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        if (isExpanded) ...[
          const SizedBox(height: 10),
          NeumorphicCard(
            borderRadius: 20,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Manual IP Configuration',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: ipController,
                  decoration: const InputDecoration(
                    labelText: 'Receiver IP Address',
                    hintText: '192.168.43.1',
                    prefixIcon: Icon(Icons.lan_rounded, size: 20),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'IP address required';
                    }
                    if (!RegExp(r'^(\d{1,3}\.){3}\d{1,3}$')
                        .hasMatch(val.trim())) {
                      return 'Enter a valid IPv4 address (e.g. 192.168.43.1)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: portController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Signaling Port',
                    hintText: '8080',
                    prefixIcon: Icon(Icons.numbers_rounded, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
