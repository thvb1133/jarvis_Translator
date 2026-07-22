import 'package:flutter/material.dart';

import '../../config/languages.dart';
import '../theme/app_theme.dart';

/// Compact language dropdown used for the source and target pickers.
class LanguageSelector extends StatelessWidget {
  const LanguageSelector({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final Language value;
  final List<Language> options;
  final ValueChanged<Language> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: JarvisColors.textMuted,
            fontSize: 11,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: JarvisColors.panel.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: JarvisColors.coreGlow.withValues(alpha: 0.25),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<Language>(
              value: value,
              isDense: true,
              dropdownColor: JarvisColors.spaceNavy,
              borderRadius: BorderRadius.circular(12),
              icon: const Icon(Icons.expand_more,
                  color: JarvisColors.textMuted),
              items: [
                for (final lang in options)
                  DropdownMenuItem(
                    value: lang,
                    child: Text(
                      '${lang.flag}  ${lang.name}',
                      style: const TextStyle(
                        color: JarvisColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                  ),
              ],
              onChanged: (lang) {
                if (lang != null) onChanged(lang);
              },
            ),
          ),
        ),
      ],
    );
  }
}
