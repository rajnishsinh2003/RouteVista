import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';

class AiService {
  // ── Groq Configuration ───────────────────────────────────────────
  static const String _groqBaseUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const String _groqApiKey = 'YOUR_GROQ_API_KEY';
  static const String _groqModel = 'llama-3.3-70b-versatile';

  // ── Gemini Configuration ─────────────────────────────────────────
  // TODO: Replace with your actual Gemini API Key from aistudio.google.com
  static const String _geminiApiKey = 'YOUR_GEMINI_API_KEY';
  static const String _geminiModel = 'gemini-1.5-flash';

  // Toggle this to switch between providers
  static bool useGemini = false;

  /// Sends a list of messages to the selected AI provider.
  static Future<String> getChatResponse(List<Map<String, String>> messages) async {
    if (useGemini && _geminiApiKey != 'YOUR_GEMINI_API_KEY') {
      return _getGeminiResponse(messages);
    } else {
      return _getGroqResponse(messages);
    }
  }

  static Future<String> _getGeminiResponse(List<Map<String, String>> messages) async {
    try {
      final model = GenerativeModel(
        model: _geminiModel,
        apiKey: _geminiApiKey,
        generationConfig: GenerationConfig(
          temperature: 0.7,
          topK: 40,
          topP: 0.95,
          maxOutputTokens: 1024,
        ),
      );

      // Convert history to Gemini format
      final history = messages.take(messages.length - 1).map((m) {
        return Content(m['role'] == 'user' ? 'user' : 'model', [TextPart(m['content']!)]);
      }).toList();

      final prompt = messages.last['content']!;
      final chat = model.startChat(history: history);
      final response = await chat.sendMessage(Content.text(prompt));
      
      return response.text ?? 'No response from Gemini';
    } catch (e) {
      print('Gemini Error: $e');
      // Fallback to Groq if Gemini fails or is unconfigured
      return _getGroqResponse(messages);
    }
  }

  static Future<String> _getGroqResponse(List<Map<String, String>> messages) async {
    try {
      final response = await http.post(
        Uri.parse(_groqBaseUrl),
        headers: {
          'Authorization': 'Bearer $_groqApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _groqModel,
          'messages': messages,
          'temperature': 0.7,
          'max_tokens': 1024,
          'top_p': 1,
          'stream': false,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'].toString().trim();
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error']['message'] ?? 'Failed to get response from Groq');
      }
    } catch (e) {
      rethrow;
    }
  }
}
