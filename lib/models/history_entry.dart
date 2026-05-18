class HistoryEntry {
  final String id;
  final String question;
  final String answer;
  final DateTime timestamp;
  final String type;

  HistoryEntry({
    required this.id,
    required this.question,
    required this.answer,
    required this.timestamp,
    required this.type,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'question': question,
    'answer': answer,
    'timestamp': timestamp.toIso8601String(),
    'type': type,
  };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
    id: json['id'] as String,
    question: json['question'] as String,
    answer: json['answer'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    type: json['type'] as String,
  );
}
