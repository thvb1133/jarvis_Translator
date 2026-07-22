import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../config/languages.dart';
import '../pipeline/pipeline_controller.dart';
import 'theme/app_theme.dart';
import 'widgets/jarvis_orb.dart';
import 'widgets/language_selector.dart';
import 'widgets/space_background.dart';
import 'widgets/transcript_view.dart';

/// The single-screen JARVIS experience: space background, the glowing orb as a
/// push-to-talk control, language pickers, and the live transcript.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Consumer<PipelineController>(
            builder: (context, controller, _) {
              return LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 900;
                  final orbSection = _OrbSection(controller: controller);
                  final transcriptSection =
                      _TranscriptSection(controller: controller);

                  if (isWide) {
                    return Row(
                      children: [
                        Expanded(flex: 5, child: orbSection),
                        const VerticalDivider(width: 1, color: Colors.white10),
                        Expanded(flex: 4, child: transcriptSection),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      Expanded(flex: 5, child: orbSection),
                      Expanded(flex: 4, child: transcriptSection),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _OrbSection extends StatelessWidget {
  const _OrbSection({required this.controller});

  final PipelineController controller;

  String get _statusLabel => switch (controller.status) {
        PipelineStatus.idle => 'Hold to speak',
        PipelineStatus.listening => 'Listening…',
        PipelineStatus.thinking => 'Translating…',
        PipelineStatus.speaking => 'Speaking…',
        PipelineStatus.error => 'Tap to dismiss error',
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const _Header(),
          const SizedBox(height: 12),
          _ModeToggle(controller: controller),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Scale the orb to the available space so it never overflows on
                // short screens while staying large and cinematic on big ones.
                final orbSize = (constraints.biggest.shortestSide * 0.92)
                    .clamp(180.0, 480.0);
                return Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _PushToTalkOrb(controller: controller, size: orbSize),
                        const SizedBox(height: 24),
                        Text(
                          _statusLabel,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: JarvisColors.textPrimary,
                            fontSize: 18,
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (controller.status == PipelineStatus.error &&
                            controller.errorMessage != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            controller.errorMessage!,
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFFF6B7A),
                              fontSize: 12,
                            ),
                          ),
                        ],
                        if (!controller.isReady) ...[
                          const SizedBox(height: 10),
                          _NotReadyBanner(controller: controller),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          _LanguageBar(controller: controller),
        ],
      ),
    );
  }
}

class _PushToTalkOrb extends StatelessWidget {
  const _PushToTalkOrb({required this.controller, this.size = 260});

  final PipelineController controller;
  final double size;

  @override
  Widget build(BuildContext context) {
    void handleError() {
      if (controller.status == PipelineStatus.error) controller.resetError();
    }

    return GestureDetector(
      onTapDown: (_) {
        handleError();
        if (controller.status == PipelineStatus.idle && controller.isReady) {
          controller.startListening();
        }
      },
      onTapUp: (_) {
        if (controller.status == PipelineStatus.listening) {
          controller.stopAndTranslate();
        }
      },
      onTapCancel: () {
        if (controller.status == PipelineStatus.listening) {
          controller.stopAndTranslate();
        }
      },
      child: JarvisOrb(
        status: controller.status,
        size: size,
        level: controller.audioLevel,
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Text(
          'JARVIS',
          style: TextStyle(
            color: JarvisColors.coreHot,
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: 8,
          ),
        ),
        SizedBox(height: 2),
        Text(
          'LIVE VOICE TRANSLATOR',
          style: TextStyle(
            color: JarvisColors.textMuted,
            fontSize: 11,
            letterSpacing: 4,
          ),
        ),
      ],
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.controller});

  final PipelineController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: JarvisColors.panel.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: JarvisColors.coreGlow.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment(
            label: 'Online',
            icon: Icons.cloud_outlined,
            selected: controller.providerMode == ProviderMode.online,
            onTap: () => controller.setProviderMode(ProviderMode.online),
          ),
          _segment(
            label: 'Offline',
            icon: Icons.wifi_off,
            selected: controller.providerMode == ProviderMode.offline,
            onTap: () => controller.setProviderMode(ProviderMode.offline),
          ),
        ],
      ),
    );
  }

  Widget _segment({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? JarvisColors.accent.withValues(alpha: 0.85)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? Colors.white : JarvisColors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : JarvisColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageBar extends StatelessWidget {
  const _LanguageBar({required this.controller});

  final PipelineController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: LanguageSelector(
            label: 'Speaker',
            value: controller.sourceLanguage,
            options: SupportedLanguages.withAuto,
            onChanged: controller.setSourceLanguage,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: IconButton(
            onPressed: controller.swapLanguages,
            icon: const Icon(Icons.swap_horiz, color: JarvisColors.coreGlow),
            tooltip: 'Swap languages',
          ),
        ),
        Expanded(
          child: LanguageSelector(
            label: 'Translate to',
            value: controller.targetLanguage,
            options: SupportedLanguages.all,
            onChanged: controller.setTargetLanguage,
          ),
        ),
      ],
    );
  }
}

class _TranscriptSection extends StatelessWidget {
  const _TranscriptSection({required this.controller});

  final PipelineController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'TRANSCRIPT',
                style: TextStyle(
                  color: JarvisColors.textMuted,
                  fontSize: 12,
                  letterSpacing: 3,
                ),
              ),
              const Spacer(),
              if (controller.transcript.isNotEmpty)
                TextButton.icon(
                  onPressed: controller.clearTranscript,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Clear'),
                  style: TextButton.styleFrom(
                    foregroundColor: JarvisColors.textMuted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(child: TranscriptView(entries: controller.transcript)),
        ],
      ),
    );
  }
}

class _NotReadyBanner extends StatelessWidget {
  const _NotReadyBanner({required this.controller});

  final PipelineController controller;

  @override
  Widget build(BuildContext context) {
    final offline = controller.providerMode == ProviderMode.offline;
    final message = offline
        ? 'Offline engines (whisper.cpp · NLLB-200 · Piper) arrive in phase 2. '
            'Switch to Online to translate now.'
        : 'No API key detected. Run with '
            '--dart-define=OPENAI_API_KEY=sk-… to enable translation.';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF3A1F2B).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF6B7A).withValues(alpha: 0.4)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xFFFFB3BC), fontSize: 12),
      ),
    );
  }
}
