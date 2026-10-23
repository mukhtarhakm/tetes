class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    required this.failed,
  });

  final String id;
  final String role;
  final String content;
  final DateTime createdAt;
  final bool failed;
}
