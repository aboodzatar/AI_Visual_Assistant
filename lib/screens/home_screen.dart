import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../services/camera_service.dart';
import '../services/speech_service.dart';
import '../services/flow_orchestrator.dart';
import '../services/api_client.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late CameraService _cameraService;
  SpeechService? _speechService;
  FlowOrchestrator? _orchestrator;
  ApiClient? _apiClient;

  bool _cameraReady = false;
  String? _cameraError;
  bool _speechReady = false;
  String? _speechError;
  String _currentTranscript = '';

  // Phase 8: Backend URL configuration
  // For Android emulator: use 'http://10.0.2.2:5000'
  // For physical device: use your PC's LAN IP, e.g., 'http://192.168.1.100:5000'
  // For iOS simulator: use 'http://localhost:5000'
  static const String _backendUrl = 'http://10.171.157.58:5276';

  @override
  void initState() {
    super.initState();
    _cameraService = CameraService();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    final stateProvider = context.read<AppStateProvider>();
    stateProvider.reset();
    setState(() {
      _cameraError = null;
      _speechError = null;
    });

    // Setup Speech
    _speechService = SpeechService(
      onSpeechRecognized: (text, isFinal) async {
        setState(() => _currentTranscript = text);
        stateProvider.setRecognizedText(text);
        // Automatically trigger flow only when speech is final
        if (isFinal && _orchestrator != null) {
          await _orchestrator!.startInteraction(text);
        }
      },
      onError: (error) {
        // Phase 8: Ignore expected silence timeouts
        if (error.contains('error_speech_timeout') ||
            error.contains('error_no_match')) {
          return;
        }
        _setSpeechError(error);
      },
      onListeningChanged: (listening) {
        if (listening) stateProvider.startListening();
      },
      onSpeakingChanged: (speaking) {
        if (speaking) {
          stateProvider.startSpeaking();
        } else {
          // TTS finished, return to idle safely
          stateProvider.reset();
          _currentTranscript = '';
        }
      },
    );

    final initialized = await _speechService!.initialize(
      language: stateProvider.language,
    );
    if (initialized) {
      setState(() {
        _speechReady = true;
        _speechError = null;
      });

      // Phase 8: Initialize API client with optimized settings
      _apiClient = ApiClient(
        baseUrl: _backendUrl,
        timeout: const Duration(seconds: 20),
        maxRetries: 1,
      );

      _orchestrator = FlowOrchestrator(
        cameraService: _cameraService,
        speechService: _speechService!,
        stateProvider: stateProvider,
        apiClient: _apiClient!,
        onComplete: () {
          stateProvider.reset();
          _currentTranscript = '';
        },
      );
    } else {
      await _setSpeechError('Speech services failed to initialize');
    }

    // Setup Camera
    try {
      final granted = await _cameraService.requestPermissions();
      if (!granted) {
        await _setCameraError("I'm sorry, I don't have camera permissions.");
        return;
      }
      await _cameraService.initializeCamera();
      if (!mounted) return;
      setState(() {
        _cameraReady = true;
        _cameraError = null;
      });
    } catch (e) {
      await _setCameraError(_friendlyCameraError(e));
    }
  }

  String _friendlyCameraError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    if (message.contains('No cameras available')) {
      return 'No camera is available on this device.';
    }
    if (message.contains('permission')) {
      return "I'm sorry, I don't have camera permissions.";
    }
    if (message.contains('Camera failed to initialize')) {
      return 'The camera could not be initialized.';
    }
    return 'The camera is unavailable right now. $message';
  }

  Future<void> _announceCriticalError(String message) async {
    if (message.isEmpty) return;

    final speechService = _speechService;
    if (speechService != null && speechService.isTtsReady) {
      await speechService.speak(
        message,
        language: context.read<AppStateProvider>().language,
      );
    }

    if (!mounted) return;
    await SemanticsService.announce(message, Directionality.of(context));
  }

  Future<void> _setCameraError(String message) async {
    if (!mounted) return;
    setState(() {
      _cameraReady = false;
      _cameraError = message;
    });
    await _announceCriticalError(message);
  }

  Future<void> _setSpeechError(String message) async {
    if (!mounted) return;
    setState(() {
      _speechReady = false;
      _speechError = message;
    });
    context.read<AppStateProvider>().handleError('Voice error: $message');
    await _announceCriticalError(message);
  }

  void _onAskPressed() {
    final stateProvider = context.read<AppStateProvider>();
    // Phase 5 requirement: Only start listening when user explicitly taps button
    if (stateProvider.state == AppState.idle &&
        _speechReady &&
        _apiClient != null) {
      _currentTranscript = '';
      stateProvider.reset();
      stateProvider.latencyTracker.reset();
      _speechService?.startListening(language: stateProvider.language);
    }
  }

  void _onLanguageToggle() {
    final stateProvider = context.read<AppStateProvider>();
    // Do not allow language change while active
    if (stateProvider.isActive) return;
    final newLang = stateProvider.language == 'en' ? 'ar' : 'en';
    stateProvider.setLanguage(newLang);
    // Re-initialize speech service with the new language
    _speechService?.initialize(language: newLang);
  }

  void _onStopPressed() {
    if (_orchestrator != null) {
      _orchestrator!.cancelCurrentFlow();
    } else {
      _speechService?.stopListening();
      _speechService?.stopSpeaking();
      context.read<AppStateProvider>().reset();
      _currentTranscript = '';
    }
  }

  @override
  void dispose() {
    _cameraService.dispose();
    _speechService?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stateProvider = context.watch<AppStateProvider>();
    final bool isActive =
        stateProvider.state != AppState.idle &&
        stateProvider.state != AppState.error;
    final bool canAsk =
        _cameraReady && _speechReady && !isActive && _apiClient != null;

    return Scaffold(
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (canAsk) {
              _onAskPressed();
            } else if (isActive) {
              _onStopPressed();
            }
          },
          child: Semantics(
            button: true,
            label: isActive ? 'Stop interaction' : 'Ask Question',
            hint:
                'Double tap anywhere on the screen to ${isActive ? 'stop' : 'start'}',
            child: Stack(
              children: [
                // 1. Camera Preview
                Semantics(
                  label:
                      _cameraReady
                          ? 'Camera viewfinder preview'
                          : 'Camera is loading',
                  image: true,
                  readOnly: true,
                  child:
                      _cameraReady
                          ? SizedBox.expand(
                            child: _cameraService.buildPreview(),
                          )
                          : Container(
                            color: Colors.black,
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            ),
                          ),
                ),

                // 2. Error Overlay
                if (_cameraError != null || _speechError != null || stateProvider.lastError != null)
                  _buildErrorOverlay(stateProvider),

                // 3. Status Banner (Top)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Semantics(
                    liveRegion: true,
                    label: 'Status: ${stateProvider.statusMessage}',
                    child: ExcludeSemantics(
                      child: Container(
                        color: Colors.black54,
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 16,
                        ),
                        child: Text(
                          stateProvider.statusMessage,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),

                // 4. Live Transcript (Middle, only while listening)
                if (_currentTranscript.isNotEmpty &&
                    stateProvider.state == AppState.listening)
                  Positioned(
                    top: 70,
                    left: 16,
                    right: 16,
                    child: Semantics(
                      container: true,
                      liveRegion: true,
                      label: 'Live transcript: $_currentTranscript',
                      child: ExcludeSemantics(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blueGrey[800],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _currentTranscript,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ),

                // 5. Controls (Bottom)
                Positioned(
                  bottom: 30,
                  left: 24,
                  right: 24,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (canAsk)
                        Semantics(
                          button: true,
                          enabled: true,
                          label: 'Ask a question',
                          hint: 'Double tap to start voice recording',
                          child: ExcludeSemantics(
                            child: ElevatedButton.icon(
                              onPressed: _onAskPressed,
                              icon: const Icon(
                                Icons.mic,
                                size: 28,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'Ask Question',
                                style: TextStyle(
                                  fontSize: 20,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 65),
                                backgroundColor: const Color(0xFF1E88E5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 4,
                              ),
                            ),
                          ),
                        )
                      else
                        Semantics(
                          button: true,
                          enabled: isActive,
                          label: 'Stop',
                          hint:
                              'Double tap to stop listening, speaking, or processing',
                          child: ExcludeSemantics(
                            child: OutlinedButton.icon(
                              onPressed: _onStopPressed,
                              icon: const Icon(
                                Icons.stop,
                                size: 28,
                                color: Colors.red,
                              ),
                              label: const Text(
                                'Stop',
                                style: TextStyle(
                                  fontSize: 20,
                                  color: Colors.red,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 65),
                                side: const BorderSide(
                                  color: Colors.red,
                                  width: 2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // 6. Language Toggle Button (Top-right)
                Positioned(
                  top: 14,
                  right: 16,
                  child: Semantics(
                    button: true,
                    label:
                        "Switch language. Current: ${stateProvider.language == 'ar' ? 'Arabic' : 'English'}",
                    hint: 'Double tap to toggle between English and Arabic',
                    child: GestureDetector(
                      // Absorb the tap so the full-screen handler never fires
                      behavior: HitTestBehavior.opaque,
                      onTap: _onLanguageToggle,
                      child: ExcludeSemantics(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color:
                                stateProvider.isActive
                                    ? Colors.black38
                                    : Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white24, width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.language,
                                color: Colors.white70,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                stateProvider.language.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // 7. Performance Debug Badge (Bottom-left, visible only in debug)
                if (!isActive &&
                    stateProvider.latencyTracker.getAllResults().isNotEmpty)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    child: ExcludeSemantics(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green[900],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          stateProvider.getPerformanceSummary(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorOverlay(AppStateProvider stateProvider) {
    final isInitError = _cameraError != null || _speechError != null;
    final errorMessage = _cameraError ?? _speechError ?? stateProvider.lastError ?? '';

    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Initialization error. $errorMessage',
      child: ExcludeSemantics(
        child: Container(
          color: Colors.black87,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                isInitError ? 'Initialization Error' : 'System Error',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              Semantics(
                button: true,
                enabled: true,
                label: 'Retry initialization',
                hint:
                    'Double tap to try starting the camera and speech services again',
                child: ExcludeSemantics(
                  child: ElevatedButton(
                    onPressed: _initializeServices,
                    child: const Text('Retry'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
