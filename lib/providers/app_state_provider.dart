import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/history_entry.dart';
import '../services/latency_tracker.dart';

enum AppState {
  idle,
  listening,
  capturing,
  uploading,
  processing,
  speaking,
  error,
}

class AppStateProvider extends ChangeNotifier {
  AppState _state = AppState.idle;
  String _statusMessage = 'Ready';
  String _lastAnswer = '';
  String _recognizedText = '';
  String _language = 'en';
  bool _autoListen = false; // Phase 5 requirement: default OFF
  final List<HistoryEntry> _history = [];
  String? _lastError;

  // Phase 8: Performance tracking
  final LatencyTracker _latencyTracker = LatencyTracker(
    onStageComplete: (stage, duration) {
      debugPrint('⏱️ $stage: ${duration.inMilliseconds}ms');
    },
  );

  // Getters
  AppState get state => _state;
  String get statusMessage => _statusMessage;
  String get lastAnswer => _lastAnswer;
  String get recognizedText => _recognizedText;
  String get language => _language;
  bool get autoListen => _autoListen;
  List<HistoryEntry> get history => List.unmodifiable(_history);
  bool get isActive => _state != AppState.idle && _state != AppState.error;
  String? get lastError => _lastError;
  LatencyTracker get latencyTracker => _latencyTracker;

  // Setters with notification
  void setState(AppState newState, String message) {
    _state = newState;
    _statusMessage = message;
    _lastError = null;
    notifyListeners();
  }

  void setAnswer(String answer) {
    _lastAnswer = answer;
    notifyListeners();
  }

  void setRecognizedText(String text) {
    _recognizedText = text;
    notifyListeners();
  }

  void setLanguage(String lang) {
    _language = lang;
    notifyListeners();
  }

  void toggleAutoListen() {
    _autoListen = !_autoListen;
    notifyListeners();
  }

  void addHistoryEntry(HistoryEntry entry) {
    _history.insert(0, entry);
    if (_history.length > 15) _history.removeLast();
    notifyListeners();
  }

  void clearHistory() {
    _history.clear();
    notifyListeners();
  }

  // Phase 8: Record backend-reported latency
  void recordBackendLatency(int latencyMs) {
    // ✅ Use public setResult() method instead of accessing private _results
    _latencyTracker.setResult(
      'backend_total',
      Duration(milliseconds: latencyMs),
    );
    notifyListeners();
  }

  // Phase 8: Get human-readable performance summary
  String getPerformanceSummary() {
    final results = _latencyTracker.getAllResults();
    if (results.isEmpty) return 'No metrics yet';

    final total = results.values.fold(Duration.zero, (sum, d) => sum + d);
    return 'Total: ${total.inMilliseconds}ms | '
        'Capture: ${results[LatencyTracker.capture]?.inMilliseconds ?? 0}ms | '
        'Upload: ${results[LatencyTracker.upload]?.inMilliseconds ?? 0}ms | '
        'Backend: ${results['backend_total']?.inMilliseconds ?? 0}ms';
  }

  // State machine shortcuts
  void startListening() {
    HapticFeedback.lightImpact();
    setState(AppState.listening, 'Listening...');
  }
  
  void startCapturing() {
    HapticFeedback.mediumImpact();
    setState(AppState.capturing, 'Capturing image...');
  }
  
  void startUploading() =>
      setState(AppState.uploading, 'Sending to assistant...');
      
  void startProcessing() {
    HapticFeedback.vibrate();
    setState(AppState.processing, 'Analyzing...');
  }
  
  void startSpeaking() => setState(AppState.speaking, 'Answer ready');

  void handleError(String message) {
    HapticFeedback.heavyImpact();
    _state = AppState.error;
    _statusMessage = 'Error';
    _lastError = message;
    notifyListeners();
  }

  void reset() {
    _state = AppState.idle;
    _statusMessage = 'Ready';
    _recognizedText = '';
    _lastError = null;
    notifyListeners();
  }

  void clearAnswer() {
    _lastAnswer = '';
    notifyListeners();
  }
}
