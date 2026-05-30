import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../core/constants.dart';

class AnalogyService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final String _backendUrl = AppConstants.backendUrl;

  static Future<String> generateAnalogy({
    required String question,
    required String answer,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return _fallbackAnalogy(question, answer);

    try {
      final uid = user.uid;
      final analogyUrl = _backendUrl.replaceAll('/api/v2', '/api/generate-analogy');

      final response = await http
          .post(
            Uri.parse(analogyUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'uid': uid,
              'question': question,
              'answer': answer,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['analogy'] as String? ?? _fallbackAnalogy(question, answer);
      }
    } catch (e) {
      print('AnalogyService error: $e');
    }

    return _fallbackAnalogy(question, answer);
  }

  static String _fallbackAnalogy(String question, String answer) {
    final analogies = {
      'intention': 'Your intention is like a seed planted in blessed soil. '
          'Each day it sends roots deeper into your heart '
          'and reaches toward the light of Allah\'s mercy.',
      'heart': 'Your heart is like the moon — sometimes full and radiant, '
          'sometimes a slim crescent hidden in shadow. '
          'Both phases are part of its journey, and both are beautiful.',
      'challenge': 'A mountain path is steep not to stop you, '
          'but to show you how strong you\'ve become with each step. '
          'Allah does not burden a soul beyond what it can bear.',
      'journey': 'Your spiritual journey is like a garden waking in spring. '
          'Each reflection, each prayer, each moment of patience — '
          'these are the blossoms unfolding at their own time.',
    };

    for (final key in analogies.keys) {
      if (question.toLowerCase().contains(key)) {
        return analogies[key]!;
      }
    }

    return 'Like a river finding its way to the ocean, '
        'your journey is guided by a force greater than you can see. '
        'Trust the current, and let it carry you closer to peace.';
  }
}
