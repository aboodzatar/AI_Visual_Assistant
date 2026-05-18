import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../providers/app_state_provider.dart';
import '../services/camera_service.dart';
import '../services/speech_service.dart';
import '../services/api_client.dart';
import '../models/history_entry.dart';
import '../services/latency_tracker.dart';

class FlowOrchestrator {
  final CameraService cameraService;
  final SpeechService speechService;
  final AppStateProvider stateProvider;
  final ApiClient apiClient;
  final Function() onComplete;

  Timer? _timeoutTimer;
  bool _isProcessing = false;
  final Uuid _uuid = const Uuid();
  late final LatencyTracker _tracker;

  FlowOrchestrator({
    required this.cameraService,
    required this.speechService,
    required this.stateProvider,
    required this.apiClient,
    required this.onComplete,
  }) {
    _tracker = stateProvider.latencyTracker;
  }

  Future<void> startInteraction(String recognizedQuestion) async {
    if (_isProcessing || recognizedQuestion.trim().isEmpty) return;

    _isProcessing = true;
    _cancelTimeouts();
    _tracker.reset();
    HapticFeedback.lightImpact();

    try {
      // Track full flow start
      _tracker.start(LatencyTracker.fullFlow);

      // 1. Capture
      stateProvider.startCapturing();
      _tracker.start(LatencyTracker.capture);
      final imageBytes = await _captureWithTimeout();
      _tracker.end(LatencyTracker.capture);
      if (imageBytes == null) {
        _handleError('Camera capture failed or timed out');
        return;
      }

      // 2. Upload + Backend Processing
      stateProvider.startUploading();
      _tracker.start(LatencyTracker.upload);

      final response = await apiClient.sendQuery(
        question: recognizedQuestion,
        imageBytes: imageBytes,
        language: stateProvider.language,
        sessionId: _uuid.v4(),
      );
      _tracker.end(LatencyTracker.upload);

      if (response == null) {
        _handleError('No response from backend');
        return;
      }

      // Record backend-reported latency
      stateProvider.recordBackendLatency(response.latencyMs);

      // 3. Speak Answer
      stateProvider.startSpeaking();
      stateProvider.setAnswer(response.answerText);

      _tracker.start(LatencyTracker.tts);
      await speechService.speak(
        response.answerText,
        language: stateProvider.language,
      );
      _tracker.end(LatencyTracker.tts);

      // 4. Save History
      final entry = HistoryEntry(
        id: _uuid.v4(),
        question: recognizedQuestion,
        answer: response.answerText,
        timestamp: DateTime.now(),
        type: response.answerType,
      );
      stateProvider.addHistoryEntry(entry);

      // End full flow tracking
      _tracker.end(LatencyTracker.fullFlow);
      _logPerformanceSummary();
    } catch (e) {
      _handleError('Interaction failed: $e');
    } finally {
      _isProcessing = false;
      _cancelTimeouts();
    }
  }

  void _logPerformanceSummary() {
    final summary = stateProvider.getPerformanceSummary();
    debugPrint('Performance: $summary');
    // Optional: send to analytics service in production
  }

  void cancelCurrentFlow() {
    _isProcessing = false;
    _cancelTimeouts();
    speechService.stopSpeaking();
    speechService.stopListening();
    stateProvider.reset();
    HapticFeedback.mediumImpact();
    onComplete();
  }

  Future<Uint8List?> _captureWithTimeout() async {
    _startTimeout('capturing', const Duration(seconds: 5));
    return cameraService.captureAndCompressImage();
  }

  void _startTimeout(String stage, Duration duration) {
    _cancelTimeouts();
    _timeoutTimer = Timer(
      duration,
      () => _handleError('$stage operation timed out'),
    );
  }

  void _cancelTimeouts() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
  }

  void _handleError(String message) {
    _isProcessing = false;
    _cancelTimeouts();
    speechService.stopSpeaking();
    stateProvider.handleError(message);
    onComplete();
  }
}
