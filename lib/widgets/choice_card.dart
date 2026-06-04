// lib/widgets/choice_card.dart
//
// Reusable tap-to-select card, matching the consultation mockups.
// Used by Step 2 (Priority), Step 3 (System Type), and Step 7 (Timeline).
//
// Usage:
//   ChoiceGroup(
//     value: _selected,
//     options: const [
//       ChoiceOption(value: 'savings', icon: Icons.savings_outlined,
//           title: 'Reduce my electricity bill', subtitle: '...'),
//       ...
//     ],
//     onChanged: (v) => setState(() => _selected = v),
//   )

import 'package:flutter/material.dart';

const _navy = Color(0xFF1B2B6B);
const _grey = Color(0xFF888888);
const _border = Color(0xFFDDDDDD);

class ChoiceOption {
  final String value;
  final IconData icon;
  final String title;
  final String? subtitle;

  const ChoiceOption({
    required this.value,
    required this.icon,
    required this.title,
    this.subtitle,
  });
}

class ChoiceGroup extends StatelessWidget {
  final String value;
  final List<ChoiceOption> options;
  final ValueChanged<String> onChanged;

  /// When true, lays the cards out in a 2-column grid (for short labels
  /// like Grid-tied / Hybrid). Defaults to a single stacked column.
  final bool twoColumns;

  const ChoiceGroup({
    Key? key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.twoColumns = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (twoColumns) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: _card(options[i])),
          ],
        ],
      );
    }
    return Column(
      children: [
        for (final o in options) ...[
          _card(o),
          if (o != options.last) const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _card(ChoiceOption o) {
    final selected = o.value == value;
    return GestureDetector(
      onTap: () => onChanged(o.value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF4F6FC) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _navy : _border,
            width: selected ? 2 : 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(o.icon, size: 24, color: selected ? _navy : _grey),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    o.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  if (o.subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      o.subtitle!,
                      style: const TextStyle(fontSize: 12.5, color: _grey, height: 1.4),
                    ),
                  ],
                ],
              ),
            ),
            if (selected)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.check_circle, size: 20, color: _navy),
              ),
          ],
        ),
      ),
    );
  }
}