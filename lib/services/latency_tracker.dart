class LatencyTracker {
  final Map<String, DateTime> _markers = {};
  final Map<String, Duration> _results = {};
  final Function(String stage, Duration duration)? onStageComplete;

  LatencyTracker({this.onStageComplete});

  void start(String stage) {
    _markers[stage] = DateTime.now();
  }

  void end(String stage) {
    final start = _markers[stage];
    if (start != null) {
      final duration = DateTime.now().difference(start);
      _results[stage] = duration;
      _markers.remove(stage);
      onStageComplete?.call(stage, duration);
    }
  }

  // ✅ NEW: Public method to set a result externally (e.g., backend-reported latency)
  void setResult(String stage, Duration duration) {
    _results[stage] = duration;
    onStageComplete?.call(stage, duration);
  }

  Duration? getDuration(String stage) => _results[stage];
  Map<String, Duration> getAllResults() => Map.unmodifiable(_results);

  void reset() {
    _markers.clear();
    _results.clear();
  }

  // Predefined stage names for consistency
  static const String fullFlow = 'full_flow';
  static const String stt = 'speech_to_text';
  static const String capture = 'image_capture';
  static const String upload = 'network_upload';
  static const String backend = 'backend_processing';
  static const String ai = 'ai_inference';
  static const String tts = 'text_to_speech';
}
