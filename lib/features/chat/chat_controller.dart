import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/remote/ai_client.dart';
import '../../data/repositories/chat_repo.dart';
import '../auth/session/force_logout.dart';
import '../auth/state/session_controller.dart';
import '../beans/bean_model.dart';
import '../beans/state/bean_providers.dart';
import '../brew/state/ai_client_provider.dart';
import '../brew/state/brew_setup_controller.dart';
import 'chat_context.dart';
import 'chat_message.dart';

class ChatState {
  const ChatState({
    required this.messages,
    this.isSending = false,
    this.remainingToday,
    this.errorMessage,
    this.contextBean,
  });

  final List<ChatMessage> messages;
  final bool isSending;
  final int? remainingToday;
  final String? errorMessage;
  final Bean? contextBean;

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isSending,
    Object? remainingToday = _unset,
    Object? errorMessage = _unset,
    Object? contextBean = _unset,
  }) => ChatState(
    messages: messages ?? this.messages,
    isSending: isSending ?? this.isSending,
    remainingToday: identical(remainingToday, _unset)
        ? this.remainingToday
        : remainingToday as int?,
    errorMessage: identical(errorMessage, _unset)
        ? this.errorMessage
        : errorMessage as String?,
    contextBean: identical(contextBean, _unset)
        ? this.contextBean
        : contextBean as Bean?,
  );
}

const _unset = Object();

final chatControllerProvider = AsyncNotifierProvider<ChatController, ChatState>(
  ChatController.new,
);

class ChatController extends AsyncNotifier<ChatState> {
  String? _userId;
  List<Bean> _beans = const [];

  @override
  Future<ChatState> build() async {
    final session = await ref.watch(sessionControllerProvider.future);
    if (session.status != SessionStatus.authenticated ||
        session.userId == null) {
      _userId = null;
      _beans = const [];
      return const ChatState(messages: []);
    }
    final userId = session.userId!;
    final repository = await ref.watch(chatRepositoryProvider.future);
    final beanRepository = await ref.watch(beanRepositoryProvider.future);
    final messages = await repository.list(userId);
    final beans = await beanRepository.listActive(userId);
    _userId = userId;
    _beans = beans;
    final todayCount = await repository.countUserToday(
      userId,
      DateTime.now().toUtc(),
    );
    return ChatState(
      messages: messages,
      remainingToday: (20 - todayCount).clamp(0, 20),
    );
  }

  void setContextBean(String? beanId) {
    final current = state.asData?.value;
    if (current == null || current.isSending) return;
    final bean = beanId == null
        ? null
        : _beans.where((item) => item.id == beanId).firstOrNull;
    state = AsyncData(current.copyWith(contextBean: bean));
  }

  void dismissError() {
    final current = state.asData?.value;
    if (current != null) {
      state = AsyncData(current.copyWith(errorMessage: null));
    }
  }

  Future<void> newConversation() async {
    final current = state.asData?.value;
    final userId = _userId;
    if (current == null ||
        current.isSending ||
        userId == null ||
        !_isCurrentUser(userId)) {
      return;
    }
    try {
      final repository = await ref.read(chatRepositoryProvider.future);
      await repository.deleteAll(userId);
      if (_isCurrentUser(userId)) {
        state = AsyncData(current.copyWith(messages: [], errorMessage: null));
      }
    } catch (_) {
      if (_isCurrentUser(userId)) {
        state = AsyncData(
          current.copyWith(
            errorMessage: 'Percakapan belum dapat dihapus. Coba lagi.',
          ),
        );
      }
    }
  }

  Future<void> send(String text) async {
    final current = state.asData?.value;
    final userId = _userId;
    if (current == null ||
        current.isSending ||
        userId == null ||
        !_isCurrentUser(userId)) {
      return;
    }
    final clean = text.trim();
    if (clean.isEmpty || clean.length > 500) {
      state = AsyncData(
        current.copyWith(
          errorMessage: 'Pesan harus berisi 1 sampai 500 karakter.',
        ),
      );
      return;
    }
    state = AsyncData(current.copyWith(isSending: true, errorMessage: null));
    ChatMessage? userMessage;
    try {
      final repository = await ref.read(chatRepositoryProvider.future);
      userMessage = await repository.add(
        userId: userId,
        beanId: current.contextBean?.id,
        role: 'user',
        content: clean,
      );
      if (!_isCurrentUser(userId)) return;
      final messages = [...current.messages, userMessage];
      state = AsyncData(current.copyWith(messages: messages, isSending: true));
      Map<String, Object?>? context;
      var bean = current.contextBean;
      if (bean != null) {
        bean = await (await ref.read(
          beanRepositoryProvider.future,
        )).findById(userId: userId, id: bean.id);
      }
      if (bean != null) {
        final brews = await repository.recentBrews(userId, bean.id);
        final bestPlan = bean.bestBrewId == null
            ? null
            : await (await ref.read(
                brewRepositoryProvider.future,
              )).findBestPlan(
                userId: userId,
                beanId: bean.id,
                bestBrewId: bean.bestBrewId!,
              );
        context = buildChatContext(
          bean: bean,
          bestPlan: bestPlan,
          recentBrews: brews,
        );
      }
      if (!_isCurrentUser(userId)) return;
      final response = await ref
          .read(aiClientProvider)
          .chat(
            userId: userId,
            messages: messages
                .where((item) => !item.failed)
                .toList()
                .reversed
                .take(12)
                .toList()
                .reversed
                .map(
                  (item) => {
                    'role': item.role,
                    'content': item.content.length > 500
                        ? item.content.substring(0, 500)
                        : item.content,
                  },
                )
                .toList(),
            context: context,
          );
      if (!_isCurrentUser(userId)) return;
      final assistant = await repository.add(
        userId: userId,
        beanId: bean?.id,
        role: 'assistant',
        content: response.reply,
      );
      state = AsyncData(
        state.asData!.value.copyWith(
          messages: [...messages, assistant],
          isSending: false,
          remainingToday:
              response.remainingToday ?? state.asData!.value.remainingToday,
        ),
      );
    } on AiException catch (error) {
      if (userMessage != null) {
        try {
          await (await ref.read(
            chatRepositoryProvider.future,
          )).markFailed(userId: userId, id: userMessage.id);
        } catch (_) {}
      }
      if (!_isCurrentUser(userId)) return;
      if (error.failure == AiFailure.unauthorized) {
        await forceLogoutOnUnauthorized(
          ref.read(sessionControllerProvider.notifier),
        );
        return;
      }
      _fail(
        error.message,
        userMessage?.id,
        quotaExhausted: error.failure == AiFailure.rateLimited,
      );
    } catch (_) {
      if (userMessage != null) {
        try {
          await (await ref.read(
            chatRepositoryProvider.future,
          )).markFailed(userId: userId, id: userMessage.id);
        } catch (_) {}
      }
      if (_isCurrentUser(userId)) {
        _fail('Pesan belum terkirim. Coba lagi.', userMessage?.id);
      }
    }
  }

  void _fail(String message, String? failedId, {bool quotaExhausted = false}) {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        isSending: false,
        errorMessage: message,
        remainingToday: quotaExhausted ? 0 : current.remainingToday,
        messages: current.messages
            .map(
              (item) => item.id == failedId
                  ? ChatMessage(
                      id: item.id,
                      role: item.role,
                      content: item.content,
                      createdAt: item.createdAt,
                      failed: true,
                    )
                  : item,
            )
            .toList(),
      ),
    );
  }

  bool _isCurrentUser(String userId) =>
      _userId == userId &&
      ref.read(sessionControllerProvider).asData?.value.userId == userId;
}
