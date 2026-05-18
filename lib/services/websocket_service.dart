import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  final String _wsUrl;
  final Function(String message) onMessageReceived;
  final Function() onConnected;
  final Function(String error) onError;

  WebSocketService({
    required String wsUrl,
    required this.onMessageReceived,
    required this.onConnected,
    required this.onError,
  }) : _wsUrl = wsUrl;

  Future<void> connect() async {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));
      await _channel!.ready;
      onConnected();
      _channel!.stream.listen(
        (data) => onMessageReceived(data.toString()),
        onError: (err) => onError(err.toString()),
        onDone: () => onError('WebSocket closed'),
      );
    } catch (e) {
      onError('Connection failed: $e');
    }
  }

  void send(Map<String, dynamic> payload) {
    if (_channel != null && _channel!.closeCode == null) {
      _channel!.sink.add(jsonEncode(payload));
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }
}
