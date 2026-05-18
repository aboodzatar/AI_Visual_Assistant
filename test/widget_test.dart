import 'package:flutter_test/flutter_test.dart';

import 'package:ai_visual_assistant/providers/app_state_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AppStateProvider updates state and resets cleanly', () {
    final provider = AppStateProvider();

    expect(provider.state, AppState.idle);
    expect(provider.statusMessage, 'Ready');

    provider.setRecognizedText('What is in front of me?');
    provider.startUploading();

    expect(provider.recognizedText, 'What is in front of me?');
    expect(provider.state, AppState.uploading);
    expect(provider.statusMessage, 'Sending to assistant...');

    provider.handleError('Camera permission denied');

    expect(provider.state, AppState.error);
    expect(provider.lastError, 'Camera permission denied');

    provider.reset();

    expect(provider.state, AppState.idle);
    expect(provider.statusMessage, 'Ready');
    expect(provider.recognizedText, isEmpty);
    expect(provider.lastError, isNull);
  });
}
