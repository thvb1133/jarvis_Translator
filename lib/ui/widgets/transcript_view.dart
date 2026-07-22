import 'package:flutter/material.dart';

import '../../config/languages.dart';
import '../../pipeline/transcript_entry.dart';
import '../theme/app_theme.dart';

/// Scrollable, chat-like view of the running conversation showing each
/// utterance's original text and its translation.
class TranscriptView extends StatelessWidget {
  const TranscriptView({super.key, required this.entries});

  final List<TranscriptEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(
        child: Text(
          'Transcripts will appear here.\nHold the orb and speak.',
          textAlign: TextAlign.center,
          style: TextStyle(color: JarvisColors.textMuted, height: 1.5),
        ),
      );
    }

    return ListView.separated(
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final entry = entries[entries.length - 1 - index];
        return _TranscriptCard(entry: entry);
      },
    );
  }
}

class _TranscriptCard extends StatelessWidget {
  const _TranscriptCard({required this.entry});

  final TranscriptEntry entry;

  @override
  Widget build(BuildContext context) {
    final source = SupportedLanguages.byCode(entry.sourceLanguageCode);
    final target = SupportedLanguages.byCode(entry.targetLanguageCode);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: JarvisColors.panel.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: JarvisColors.coreGlow.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _langChip('${source.flag} ${source.name}', JarvisColors.textMuted),
          const SizedBox(height: 6),
          Text(
            entry.originalText,
            style: const TextStyle(
              color: JarvisColors.textMuted,
              fontSize: 15,
            ),
          ),
          const Divider(height: 18, color: Colors.white12),
          _langChip('${target.flag} ${target.name}', JarvisColors.coreGlow),
          const SizedBox(height: 6),
          Text(
            entry.translatedText,
            style: const TextStyle(
              color: JarvisColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _langChip(String label, Color color) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        color: color,
        fontSize: 11,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
