import 'package:flutter/material.dart';
import '../../core/models/ui_models.dart';
import '../../core/ui/states/state_view.dart';
import '../../theme/app_tokens.dart';
import '../map/indoor_navigation_screen.dart';

class AiGuideScreen extends StatefulWidget {
  const AiGuideScreen({super.key});

  @override
  State<AiGuideScreen> createState() => _AiGuideScreenState();
}

class _AiGuideScreenState extends State<AiGuideScreen> {
  AiGuideViewState _state = AiGuideViewState.empty;
  bool _english = true;
  bool _tourMode = false;

  final _messages = <UiAiMessage>[
    const UiAiMessage(
      id: '1',
      text: 'Moni! Ask about any artifact to begin your guided conversation.',
      isVisitor: false,
      timestamp: '10:02',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFCF8),
      appBar: AppBar(
        title: const Text('AI Guide'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: _openTranscript,
          ),
        ],
      ),
      body: Column(
        children: [
          _LanguageToggle(
            english: _english,
            onChanged: (v) => setState(() => _english = v),
          ),
          _TourPanel(
            active: _tourMode,
            onToggle: () => setState(() => _tourMode = !_tourMode),
            onNextStop: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const IndoorNavigationScreen()),
              );
            },
          ),
          Expanded(child: _buildBody()),
          _Composer(
            onSend: (text) {
              setState(() {
                _state = AiGuideViewState.conversation;
                _messages.add(UiAiMessage(id: DateTime.now().toString(), text: text, isVisitor: true));
                _messages.add(
                  UiAiMessage(
                    id: '${DateTime.now()}-ai',
                    text: 'This artifact reflects Chewa traditions and was used in ceremony.',
                    isVisitor: false,
                  ),
                );
              });
            },
            onListen: () => setState(() => _state = AiGuideViewState.listening),
            onForceError: () => setState(() => _state = AiGuideViewState.error),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case AiGuideViewState.empty:
        return const AppEmptyState(
          title: 'Start a Conversation',
          message: 'Try: "Tell me the story of this artifact" or use Tour Mode.',
        );
      case AiGuideViewState.conversation:
        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: _messages.length,
          itemBuilder: (context, index) {
            final msg = _messages[index];
            return Align(
              alignment: msg.isVisitor ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: msg.isVisitor ? AppColors.primary : AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(14),
                  border: msg.isVisitor ? null : Border.all(color: AppColors.surfaceBorder),
                ),
                child: Text(
                  msg.text,
                  style: TextStyle(
                    color: msg.isVisitor ? Colors.white : AppColors.textMain,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            );
          },
        );
      case AiGuideViewState.listening:
        return const StateView(
          icon: Icons.mic,
          title: 'Listening...',
          message: 'Speak clearly and ask about the current artifact.',
        );
      case AiGuideViewState.error:
        return AppErrorState(
          title: 'Guide Temporarily Unavailable',
          message: 'Please retry in a moment.',
          onAction: () => setState(() => _state = AiGuideViewState.conversation),
        );
    }
  }

  void _openTranscript() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: _messages.length,
          itemBuilder: (_, i) {
            final m = _messages[i];
            return ListTile(
              leading: Icon(m.isVisitor ? Icons.person : Icons.smart_toy),
              title: Text(m.text, maxLines: 2, overflow: TextOverflow.ellipsis),
            );
          },
        );
      },
    );
  }
}

class _LanguageToggle extends StatelessWidget {
  const _LanguageToggle({required this.english, required this.onChanged});
  final bool english;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: true, label: Text('English')),
          ButtonSegment(value: false, label: Text('Chichewa')),
        ],
        selected: {english},
        onSelectionChanged: (value) => onChanged(value.first),
      ),
    );
  }
}

class _TourPanel extends StatelessWidget {
  const _TourPanel({
    required this.active,
    required this.onToggle,
    required this.onNextStop,
  });

  final bool active;
  final VoidCallback onToggle;
  final VoidCallback onNextStop;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Tour Mode',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                ),
              ),
              Switch(value: active, onChanged: (_) => onToggle()),
            ],
          ),
          if (active) ...[
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(Icons.route, color: AppColors.primary),
                SizedBox(width: 8),
                Text('Step 2/8 • Hall of Ancestors'),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onNextStop,
                icon: const Icon(Icons.near_me),
                label: const Text('Navigate to Next Stop'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Composer extends StatefulWidget {
  const _Composer({
    required this.onSend,
    required this.onListen,
    required this.onForceError,
  });

  final ValueChanged<String> onSend;
  final VoidCallback onListen;
  final VoidCallback onForceError;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: 'Ask the AI guide...',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: widget.onListen,
              icon: const Icon(Icons.mic),
            ),
            IconButton(
              onPressed: widget.onForceError,
              icon: const Icon(Icons.error_outline),
            ),
            IconButton(
              onPressed: () {
                final text = _controller.text.trim();
                if (text.isEmpty) return;
                widget.onSend(text);
                _controller.clear();
              },
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
