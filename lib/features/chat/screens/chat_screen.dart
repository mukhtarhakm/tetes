import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/ui/app_dialog.dart';
import '../../../core/ui/state_views.dart';
import '../../beans/bean_model.dart';
import '../../beans/state/bean_providers.dart';
import '../chat_controller.dart';
import '../chat_message.dart';

/// Batas pesan chat per hari. Harus sama dengan batas di Edge Function `ai`.
const _dailyChatLimit = 20;

const _suggestions = [
  'Kenapa seduhanku terasa asam?',
  'Gilingan apa yang cocok untuk biji ini?',
  'Bagaimana membuat seduhan lebih manis?',
];

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: AppDurations.feedback,
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send(String text) async {
    final controller = ref.read(chatControllerProvider.notifier);
    final before = ref.read(chatControllerProvider).asData?.value;
    if (before == null || before.isSending) return;
    await controller.send(text);
    final after = ref.read(chatControllerProvider).asData?.value;
    if (after != null && after.errorMessage == null) {
      _textController.clear();
    }
  }

  Future<void> _confirmNewConversation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: 'Mulai percakapan baru?',
        message: 'Riwayat percakapan di perangkat ini akan dihapus.',
        primaryLabel: 'Hapus dan mulai baru',
        onPrimaryPressed: () => Navigator.of(dialogContext).pop(true),
        secondaryLabel: 'Batal',
        onSecondaryPressed: () => Navigator.of(dialogContext).pop(false),
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(chatControllerProvider.notifier).newConversation();
    }
  }

  Future<void> _pickBean(List<Bean> beans, Bean? selected) async {
    final controller = ref.read(chatControllerProvider.notifier);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s12,
            0,
            AppSpacing.s12,
            AppSpacing.s16,
          ),
          children: [
            ListTile(
              title: const Text('Tanpa konteks biji'),
              trailing: selected == null ? const Icon(Icons.check) : null,
              onTap: () {
                controller.setContextBean(null);
                Navigator.of(sheetContext).pop();
              },
            ),
            for (final bean in beans)
              ListTile(
                title: Text(bean.name),
                subtitle: bean.roastery == null ? null : Text(bean.roastery!),
                trailing: selected?.id == bean.id
                    ? const Icon(Icons.check)
                    : null,
                onTap: () {
                  controller.setContextBean(bean.id);
                  Navigator.of(sheetContext).pop();
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(chatControllerProvider, (previous, next) {
      final before = previous?.asData?.value;
      final after = next.asData?.value;
      if (after != null &&
          (before == null ||
              before.messages.length != after.messages.length ||
              before.isSending != after.isSending)) {
        _scrollToEnd();
      }
    });
    final chat = ref.watch(chatControllerProvider);
    final beans = ref.watch(beanListProvider).asData?.value ?? const <Bean>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tanya Barista'),
        actions: [
          IconButton(
            tooltip: 'Mulai percakapan baru',
            onPressed: chat.asData?.value.isSending == false &&
                    chat.asData!.value.messages.isNotEmpty
                ? _confirmNewConversation
                : null,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: chat.when(
          loading: () => const LoadingView(message: 'Memuat percakapan...'),
          error: (_, _) => Padding(
            padding: AppInsets.screen,
            child: ErrorView(
              message: 'Percakapan belum dapat dimuat. Coba lagi.',
              onRetry: () => ref.invalidate(chatControllerProvider),
            ),
          ),
          data: (state) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s20,
                  AppSpacing.s8,
                  AppSpacing.s20,
                  0,
                ),
                child: _ContextCard(
                  bean: state.contextBean,
                  enabled: !state.isSending && beans.isNotEmpty,
                  onChange: () => _pickBean(beans, state.contextBean),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.s20,
                    AppSpacing.s16,
                    AppSpacing.s20,
                    AppSpacing.s16,
                  ),
                  children: [
                    const _AssistantBubble(
                      text:
                          'Halo! Aku bisa bantu soal seduh V60 kamu. '
                          'Pilih biji sebagai konteks, lalu tanyakan apa saja soal seduhanmu.',
                    ),
                    if (state.messages.isEmpty) ...[
                      const SizedBox(height: AppSpacing.s12),
                      Padding(
                        padding: const EdgeInsets.only(
                          left: AppSizes.chatAvatar + AppSpacing.s8,
                        ),
                        child: Wrap(
                          spacing: AppSpacing.s8,
                          runSpacing: AppSpacing.s8,
                          children: [
                            for (final text in _suggestions)
                              ActionChip(
                                label: Text(text),
                                onPressed:
                                    state.isSending ||
                                        state.remainingToday == 0
                                    ? null
                                    : () => _send(text),
                              ),
                          ],
                        ),
                      ),
                    ],
                    for (final message in state.messages) ...[
                      const SizedBox(height: AppSpacing.s12),
                      message.role == 'user'
                          ? _UserBubble(message: message)
                          : _AssistantBubble(text: message.content),
                    ],
                    if (state.isSending) ...[
                      const SizedBox(height: AppSpacing.s12),
                      const _TypingBubble(),
                    ],
                  ],
                ),
              ),
              if (state.errorMessage case final error?)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.s20,
                    0,
                    AppSpacing.s12,
                    AppSpacing.s8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          error,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.error),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Tutup pesan galat',
                        onPressed: ref
                            .read(chatControllerProvider.notifier)
                            .dismissError,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
              _InputBar(
                controller: _textController,
                isSending: state.isSending,
                remaining: state.remainingToday,
                onSend: _send,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContextCard extends StatelessWidget {
  const _ContextCard({
    required this.bean,
    required this.enabled,
    required this.onChange,
  });

  final Bean? bean;
  final bool enabled;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s8,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.innerCard),
      ),
      child: Row(
        children: [
          Container(
            width: AppSizes.chatAvatar + AppSpacing.s4,
            height: AppSizes.chatAvatar + AppSpacing.s4,
            decoration: const BoxDecoration(
              color: AppColors.accentSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.coffee_outlined, size: AppSpacing.s20),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Konteks percakapan',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.inkSoft,
                  ),
                ),
                Text(
                  bean == null
                      ? 'Tanpa konteks biji'
                      : '${bean!.name} · seduhan terbaru ikut dibaca',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: enabled ? onChange : null,
            child: const Text('Ganti'),
          ),
        ],
      ),
    );
  }
}

class _AssistantBubble extends StatelessWidget {
  const _AssistantBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.sizeOf(context).width * 0.75;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const _BotAvatar(),
        const SizedBox(width: AppSpacing.s8),
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s16,
                vertical: AppSpacing.s12,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.innerCard),
                  topRight: Radius.circular(AppRadius.innerCard),
                  bottomRight: Radius.circular(AppRadius.innerCard),
                  bottomLeft: Radius.circular(AppSpacing.s4),
                ),
              ),
              child: SelectableText(
                text,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.75;
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s16,
                vertical: AppSpacing.s12,
              ),
              decoration: const BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.innerCard),
                  topRight: Radius.circular(AppRadius.innerCard),
                  bottomLeft: Radius.circular(AppRadius.innerCard),
                  bottomRight: Radius.circular(AppSpacing.s4),
                ),
              ),
              child: SelectableText(
                message.content,
                style: textTheme.bodyLarge?.copyWith(color: AppColors.onDark),
              ),
            ),
            if (message.failed)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.s4),
                child: Text(
                  'Belum terkirim',
                  style: textTheme.bodySmall?.copyWith(color: AppColors.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Barista sedang mengetik',
    child: Row(
      children: [
        const _BotAvatar(),
        const SizedBox(width: AppSpacing.s8),
        Container(
          padding: const EdgeInsets.all(AppSpacing.s16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.innerCard),
          ),
          child: const SizedBox(
            width: AppSizes.buttonProgress,
            height: AppSizes.buttonProgress,
            child: CircularProgressIndicator(
              strokeWidth: AppSizes.progressStroke,
            ),
          ),
        ),
      ],
    ),
  );
}

class _BotAvatar extends StatelessWidget {
  const _BotAvatar();

  @override
  Widget build(BuildContext context) => Container(
    width: AppSizes.chatAvatar,
    height: AppSizes.chatAvatar,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: AppColors.primary,
      shape: BoxShape.circle,
    ),
    child: Text(
      'T',
      style: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
    ),
  );
}

class _InputBar extends StatefulWidget {
  const _InputBar({
    required this.controller,
    required this.isSending,
    required this.remaining,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isSending;
  final int? remaining;
  final Future<void> Function(String text) onSend;

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final exhausted = widget.remaining == 0;
    final text = widget.controller.text.trim();
    final canSend = !widget.isSending && !exhausted && text.isNotEmpty;
    final caption = exhausted
        ? 'Kuota chat hari ini habis. Coba lagi besok.'
        : widget.remaining == null
        ? 'Saran bersifat kemungkinan, bukan kepastian'
        : 'Sisa ${widget.remaining} dari $_dailyChatLimit pesan hari ini · '
              'Saran bersifat kemungkinan, bukan kepastian';
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        AppSpacing.s8,
        AppSpacing.s16,
        AppSpacing.s12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            caption,
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
          ),
          const SizedBox(height: AppSpacing.s8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  enabled: !exhausted,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 500,
                  textInputAction: TextInputAction.send,
                  onSubmitted: canSend ? widget.onSend : null,
                  style: textTheme.bodyLarge,
                  decoration: InputDecoration(
                    hintText: 'Tanya soal seduhanmu...',
                    counterText: '',
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s20,
                      vertical: AppSpacing.s16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              IconButton.filled(
                tooltip: 'Kirim',
                onPressed: canSend ? () => widget.onSend(text) : null,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.ink,
                  foregroundColor: AppColors.onDark,
                  fixedSize: const Size.square(AppSizes.chatSendButton),
                ),
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
