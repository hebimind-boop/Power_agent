class ChatMessage {
  final String role; // user | assistant | system
  final String content;
  final String? actionResult;

  ChatMessage({required this.role, required this.content, this.actionResult});

  Map<String, dynamic> toJson() =>
      {'role': role, 'content': content, 'actionResult': actionResult};

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        role: j['role'] as String,
        content: j['content'] as String,
        actionResult: j['actionResult'] as String?,
      );
}
