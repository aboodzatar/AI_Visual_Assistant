class AssistRequest {
  final String question;
  final List<int> imageBytes; // Base64 or raw bytes will be sent via WS/HTTP
  final String language;
  final String sessionId;
  final DateTime timestamp;

  AssistRequest({
    required this.question,
    required this.imageBytes,
    required this.language,
    required this.sessionId,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'question': question,
    'image_bytes': imageBytes,
    'language': language,
    'session_id': sessionId,
    'timestamp': timestamp.toIso8601String(),
  };
}

class AssistResponse {
  final String answerText;
  final String answerType; // OCR, room, scene, object, uncertain
  final bool caution;
  final int latencyMs;

  AssistResponse({
    required this.answerText,
    required this.answerType,
    required this.caution,
    required this.latencyMs,
  });

  factory AssistResponse.fromJson(Map<String, dynamic> json) => AssistResponse(
    answerText: json['answer_text'] ?? '',
    answerType: json['answer_type'] ?? 'uncertain',
    caution: json['caution'] ?? false,
    latencyMs: json['latency_ms'] ?? 0,
  );
}
