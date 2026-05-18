import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/api_contract.dart';

class ApiClient {
  final String baseUrl;
  final Duration timeout;
  final int maxRetries;

  ApiClient({
    required this.baseUrl,
    this.timeout = const Duration(seconds: 15),
    this.maxRetries = 2,
  });

  Future<AssistResponse?> sendQuery({
    required String question,
    required Uint8List imageBytes,
    required String language,
    required String sessionId,
  }) async {
    final payload = {
      'question': question,
      'image': base64Encode(imageBytes),
      'language': language,
      'session_id': sessionId,
      'timestamp': DateTime.now().toIso8601String(),
    };

    int attempt = 0;
    while (attempt <= maxRetries) {
      try {
        final response = await http
            .post(
              Uri.parse('$baseUrl/api/assist/query'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            )
            .timeout(timeout);

        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);
          return AssistResponse.fromJson(json);
        } else if (response.statusCode >= 500 && attempt < maxRetries) {
          attempt++;
          await Future.delayed(Duration(milliseconds: 200 * attempt));
          continue;
        } else {
          throw HttpException(
            'API error ${response.statusCode}: ${response.body}',
          );
        }
      } on TimeoutException {
        if (attempt < maxRetries) {
          attempt++;
          await Future.delayed(Duration(milliseconds: 300 * attempt));
          continue;
        }
        rethrow;
      }
    }
    return null;
  }
}
