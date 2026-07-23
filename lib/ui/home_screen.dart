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
                  if (isWide) {
                    return Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: _OrbSection(controller: controller),
                        ),
                        const VerticalDivider(width: 1, color: Colors.white10),
                        Expanded(
                          flex: 4,
                          child: _TranscriptSection(controller: controller),
                        ),
                      ],
                    );
                  }
                  return _MobileLayout(
                    controller: controller,
                    viewportHeight: constraints.maxHeight,
                    viewportWidth: constraints.maxWidth,
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

String _statusLabelFor(PipelineController controller) {
  final companion = controller.mode == AppMode.companion;
  return switch (controller.status) {
    PipelineStatus.idle =>
      companion ? 'Hold to talk to Kimchi' : 'Hold the orb & speak',
    PipelineStatus.listening => 'Listening…',
    PipelineStatus.thinking =>
      companion ? 'Kimchi is thinking…' : 'Translating…',
    PipelineStatus.speaking =>
      companion ? 'Kimchi is speaking…' : 'Speaking…',
    PipelineStatus.error => 'Tap to dismiss error',
  };
}

/// The orb plus its status text and any banners. Reused by both layouts.
class _OrbBlock extends StatelessWidget {
  const _OrbBlock({required this.controller, required this.size});

  final PipelineController controller;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PushToTalkOrb(controller: controller, size: size),
        const SizedBox(height: 20),
        Text(
          _statusLabelFor(controller),
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
            style: const TextStyle(color: Color(0xFFFF6B7A), fontSize: 12),
          ),
        ],
        if (!controller.isReady) ...[
          const SizedBox(height: 10),
          _NotReadyBanner(controller: controller),
        ],
      ],
    );
  }
}

/// Desktop / wide layout: the orb fills the left pane.
class _OrbSection extends StatelessWidget {
  const _OrbSection({required this.controller});

  final PipelineController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const _Header(),
          const SizedBox(height: 12),
          _SettingsBar(controller: controller),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final orbSize = (constraints.biggest.shortestSide * 0.9)
                    .clamp(180.0, 480.0);
                return Center(
                  child: SingleChildScrollView(
                    child: _OrbBlock(controller: controller, size: orbSize),
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

/// Phone / narrow layout: a single scrolling page so the orb is always big and
/// fully visible (and pressable), with controls and the transcript below it.
class _MobileLayout extends StatelessWidget {
  const _MobileLayout({
    required this.controller,
    required this.viewportHeight,
    required this.viewportWidth,
  });

  final PipelineController controller;
  final double viewportHeight;
  final double viewportWidth;

  @override
  Widget build(BuildContext context) {
    // A comfortably large orb that always fits the phone width.
    final orbSize = (viewportWidth * 0.7).clamp(180.0, 320.0);
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: viewportHeight),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                children: [
                  const _Header(),
                  const SizedBox(height: 12),
                  _SettingsBar(controller: controller),
                  const SizedBox(height: 20),
                  _OrbBlock(controller: controller, size: orbSize),
                  const SizedBox(height: 20),
                  _LanguageBar(controller: controller),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white10),
            SizedBox(
              height: 320,
              child: _TranscriptSection(controller: controller),
            ),
          ],
        ),
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
          'KIMACHI',
          style: TextStyle(
            color: JarvisColors.coreHot,
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: 10,
          ),
        ),
        SizedBox(height: 2),
        Text(
          'KIMCHI JARVIS · LIVE TRANSLATOR',
          style: TextStyle(
            color: JarvisColors.textMuted,
            fontSize: 11,
            letterSpacing: 3,
          ),
        ),
      ],
    );
  }
}

class _SettingsBar extends StatelessWidget {
  const _SettingsBar({required this.controller});

  final PipelineController controller;

  @override
  Widget build(BuildContext context) {
    const voiceEngines = VoiceEngine.values;
    const providers = TranslationProvider.values;
    const modes = AppMode.values;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 8,
      children: [
        _MultiToggle(
          segments: const [
            _Seg('Translate', Icons.translate),
            _Seg('Kimchi', Icons.pets),
          ],
          selectedIndex: modes.indexOf(controller.mode),
          onSelect: (i) => controller.setMode(modes[i]),
        ),
        _MultiToggle(
          segments: const [
            _Seg('Cloud', Icons.cloud_outlined),
            _Seg('Device', Icons.smartphone),
          ],
          selectedIndex: voiceEngines.indexOf(controller.voiceEngine),
          onSelect: (i) => controller.setVoiceEngine(voiceEngines[i]),
        ),
        _MultiToggle(
          segments: const [
            _Seg('Free', Icons.money_off),
            _Seg('OpenAI', Icons.auto_awesome),
            _Seg('Claude', Icons.psychology_alt),
          ],
          selectedIndex: providers.indexOf(controller.translationProvider),
          onSelect: (i) => controller.setTranslationProvider(providers[i]),
        ),
      ],
    );
  }
}

class _Seg {
  const _Seg(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _MultiToggle extends StatelessWidget {
  const _MultiToggle({
    required this.segments,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<_Seg> segments;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: JarvisColors.panel.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: JarvisColors.coreGlow.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < segments.length; i++)
            _segment(segments[i], i == selectedIndex, () => onSelect(i)),
        ],
      ),
    );
  }

  Widget _segment(_Seg seg, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? JarvisColors.accent.withValues(alpha: 0.85)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(seg.icon,
                size: 15,
                color: selected ? Colors.white : JarvisColors.textMuted),
            const SizedBox(width: 6),
            Text(
              seg.label,
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
    final companion = controller.mode == AppMode.companion;
    return Row(
      children: [
        Expanded(
          child: LanguageSelector(
            label: companion ? 'You speak' : 'Speaker',
            value: controller.sourceLanguage,
            options: SupportedLanguages.withAuto,
            onChanged: controller.setSourceLanguage,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: IconButton(
            onPressed: companion ? null : controller.swapLanguages,
            icon: Icon(
              companion ? Icons.arrow_forward : Icons.swap_horiz,
              color: JarvisColors.coreGlow,
            ),
            tooltip: companion ? 'Kimchi replies in' : 'Swap languages',
          ),
        ),
        Expanded(
          child: LanguageSelector(
            label: companion ? 'Kimchi speaks' : 'Translate to',
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
    final config = controller.config;
    final companion = controller.mode == AppMode.companion;
    final String message;
    if (companion && !config.canChat) {
      message = 'Kimchi needs a brain: add OPENAI_API_KEY or ANTHROPIC_API_KEY '
          '(or a chat proxy). There is no key-free chat.';
    } else if (!companion && !config.canTranslate) {
      message = config.translationProvider == TranslationProvider.claude
          ? 'Add a Claude key (ANTHROPIC_API_KEY) or a translate proxy to '
              'enable translation.'
          : 'Add OPENAI_API_KEY or a translate proxy to enable translation.';
    } else {
      message = 'Cloud voice needs OPENAI_API_KEY. Switch to Device voice '
          '(free, no key) or add the key.';
    }
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
