import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class OpenAIService {
  static const String _apiKey = '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';
  static const String _endpoint = 'https://api.openai.com/v1/chat/completions';
  
  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $_apiKey',
  };

  // Generar preguntas/pistas para ayudar a escribir historias  
  static Future<List<String>> generateStoryPrompts({
    required String currentTitle,
    required String currentContent,
    int count = 3,
  }) async {
    final prompt = '''
Analiza esta historia que se está escribiendo y genera $count preguntas específicas que ayuden al autor a expandir y enriquecer su relato.

Título actual: "$currentTitle"
Contenido actual: "$currentContent"

Genera preguntas que:
- Ayuden a recordar más detalles específicos sobre la experiencia
- Evoquen emociones y detalles sensoriales
- Inviten a profundizar en aspectos importantes de la historia
- Sean apropiadas y respetuosas
- Estén en español
- Sean específicas al contenido ya escrito

Responde SOLO con un objeto JSON:
{
  "prompts": ["pregunta1", "pregunta2", "pregunta3"]
}
''';

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: _headers,
        body: jsonEncode({
          'model': 'gpt-5-mini',
          'messages': [
            {
              'role': 'system',
              'content': 'Eres un experto en storytelling para personas mayores. Siempre responde con un objeto JSON válido.',
            },
            {
              'role': 'user',
              'content': prompt,
            },
          ],
          'response_format': {'type': 'json_object'},
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final content = jsonDecode(data['choices'][0]['message']['content']);
        return List<String>.from(content['prompts'] ?? []);
      } else {
        throw Exception('Error generating prompts: ${response.statusCode}');
      }
    } catch (e) {
      print('Error generating story prompts: $e');
      // Fallback prompts
      return [
        '¿Qué detalles específicos del lugar puedes recordar?',
        '¿Qué emociones experimentaste en ese momento?',
        '¿Cómo cambió esta experiencia tu vida?'
      ];
    }
  }

  // Comprehensive Ghost Writer with advanced parameters
  static Future<Map<String, dynamic>> improveStoryText({
    required String originalText,
    required String title,
    String tone = 'nostálgico',
    String fidelity = 'high',
    String language = 'español',
    String audience = 'familia',
    String perspective = 'primera persona',
    String privacy = 'privado',
    bool expandContent = false,
    bool preserveStructure = true,
  }) async {
    final toneMap = {
      'nostálgico': 'nostalgic and warm, evoking sweet memories and gentle melancholy',
      'alegre': 'joyful and uplifting, highlighting positive moments and celebrations',
      'emotivo': 'deeply emotional and touching, bringing out heartfelt feelings',
      'reflexivo': 'thoughtful and contemplative, encouraging introspection',
      'divertido': 'light-hearted and amusing, finding gentle humor in life\'s moments'
    };
    
    final fidelityMap = {
      'high': 'Maintain extremely high fidelity to original facts and events. Make minimal changes.',
      'medium': 'Preserve core facts while allowing moderate enhancement and expansion.',
      'creative': 'Allow creative interpretation while keeping the essence of the story.'
    };

    final prompt = '''
You are "Narra Ghost Writer," a careful editorial assistant. 
Goal: polish the user's story for clarity, flow, and emotional impact while respecting their voice and memories.

## STORY TO IMPROVE:
Title: "$title"
Content: "$originalText"

## IMPROVEMENT PARAMETERS:
- Tone: ${toneMap[tone] ?? toneMap['nostálgico']}
- Fidelity Level: ${fidelityMap[fidelity] ?? fidelityMap['high']}
- Target Language: $language
- Intended Audience: $audience  
- Narrative Perspective: $perspective
- Privacy Setting: $privacy
- Expand Content: ${expandContent ? 'Yes' : 'No'}
- Preserve Structure: ${preserveStructure ? 'Yes' : 'No'}

## INSTRUCTIONS:
1. PRESERVE AUTHENTICITY: Never invent facts, people, or events not in the original
2. ENHANCE READABILITY: Improve sentence flow, transitions, and paragraph structure
3. ADD SENSORY DETAILS: Where appropriate, enhance with details that feel natural to the story
4. MAINTAIN VOICE: Keep the personal, authentic voice of the storyteller
5. RESPECT MEMORIES: These are precious personal memories - treat them with care and respect
6. IMPROVE EMOTIONAL IMPACT: Help the story connect better with readers while staying truthful

## OUTPUT REQUIREMENTS:
Return ONLY a JSON object with this exact structure:
{
  "polished_text": "[improved version of the story]",
  "changes_summary": "[brief summary of what was improved]",
  "suggestions": ["suggestion1", "suggestion2", "suggestion3"],
  "tone_analysis": "[how the tone was applied]",
  "word_count": [number of words in polished text]
}

Write in $language. Be respectful of this personal story.''';

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: _headers,
        body: jsonEncode({
          'model': 'gpt-5-mini',
          'messages': [
            {
              'role': 'system',
              'content': 'Eres un ghost writer experto en memorias personales. Siempre responde con un objeto JSON válido.',
            },
            {
              'role': 'user',
              'content': prompt,
            },
          ],
          'response_format': {'type': 'json_object'},
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final content = jsonDecode(data['choices'][0]['message']['content']);
        return {
          'polished_text': content['polished_text'] ?? originalText,
          'changes_summary': content['changes_summary'] ?? 'No changes made',
          'suggestions': List<String>.from(content['suggestions'] ?? []),
          'tone_analysis': content['tone_analysis'] ?? 'No tone analysis',
          'word_count': content['word_count'] ?? originalText.split(' ').length,
        };
      } else {
        throw Exception('Error improving text: ${response.statusCode}');
      }
    } catch (e) {
      print('Error improving story text: $e');
      return {
        'polished_text': originalText,
        'changes_summary': 'Error occurred during processing',
        'suggestions': <String>[],
        'tone_analysis': 'Unable to analyze tone',
        'word_count': originalText.split(' ').length,
      };
    }
  }

  // Evaluar completitud de la historia (completómetro)
  static Future<Map<String, dynamic>> evaluateStoryCompleteness({
    required String storyText,
    required String title,
  }) async {
    final prompt = '''
Analiza esta historia personal y evalúa qué tan completa está como narrativa autobiográfica.

Título: $title
Historia: $storyText

Evalúa los siguientes aspectos (escala 0-100):
- Contexto temporal y ubicación
- Descripción de personas involucradas
- Detalles sensoriales y emocionales
- Secuencia narrativa clara
- Resolución o reflexión final

Proporciona también 3-5 sugerencias específicas para mejorar la historia.

Responde SOLO con un objeto JSON:
{
  "completeness_score": número_entre_0_y_100,
  "missing_elements": ["elemento1", "elemento2", ...],
  "suggestions": ["sugerencia1", "sugerencia2", ...],
  "strengths": ["fortaleza1", "fortaleza2", ...]
}
''';

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: _headers,
        body: jsonEncode({
          'model': 'gpt-5-mini',
          'messages': [
            {
              'role': 'system',
              'content': 'Eres un experto en análisis narrativo y storytelling personal. Siempre responde con un objeto JSON válido.',
            },
            {
              'role': 'user',
              'content': prompt,
            },
          ],
          'response_format': {'type': 'json_object'},
          'temperature': 0.3,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final content = jsonDecode(data['choices'][0]['message']['content']);
        return {
          'completeness_score': content['completeness_score'] ?? 0,
          'missing_elements': List<String>.from(content['missing_elements'] ?? []),
          'suggestions': List<String>.from(content['suggestions'] ?? []),
          'strengths': List<String>.from(content['strengths'] ?? []),
        };
      } else {
        throw Exception('Error evaluating completeness: ${response.statusCode}');
      }
    } catch (e) {
      print('Error evaluating story completeness: $e');
      return {
        'completeness_score': 50,
        'missing_elements': ['Más detalles contextuales'],
        'suggestions': ['Añade más detalles sobre el lugar y las personas'],
        'strengths': ['Historia personal auténtica'],
      };
    }
  }

  // Transcribir y mejorar audio a texto
  static Future<String> transcribeAudio(Uint8List audioData) async {
    // Nota: Esta función requeriría la API de Whisper de OpenAI
    // Por ahora retornamos un placeholder
    return 'Funcionalidad de transcripción de audio pendiente de implementación con Whisper API';
  }

  // Generar ideas de títulos para historias
  static Future<List<String>> generateTitleSuggestions({
    required String storyContent,
    int count = 5,
  }) async {
    final prompt = '''
Lee esta historia personal y sugiere $count títulos creativos y emotivos:

Historia: $storyContent

Los títulos deben:
- Capturar la esencia emocional de la historia
- Ser evocativos y memorables
- Usar español natural y cálido
- Tener entre 3-8 palabras
- Ser apropiados para memorias familiares

Responde SOLO con un objeto JSON:
{
  "titles": ["título1", "título2", "título3", ...]
}
''';

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: _headers,
        body: jsonEncode({
          'model': 'gpt-5-mini',
          'messages': [
            {
              'role': 'system',
              'content': 'Eres un experto en títulos creativos para memorias personales. Siempre responde con un objeto JSON válido.',
            },
            {
              'role': 'user',
              'content': prompt,
            },
          ],
          'response_format': {'type': 'json_object'},
          'temperature': 0.9,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final content = jsonDecode(data['choices'][0]['message']['content']);
        return List<String>.from(content['titles'] ?? []);
      } else {
        throw Exception('Error generating titles: ${response.statusCode}');
      }
    } catch (e) {
      print('Error generating title suggestions: $e');
      return ['Mi Historia', 'Recuerdos Preciados', 'Una Vida Vivida'];
    }
  }
}