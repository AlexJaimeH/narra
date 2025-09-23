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
    required String context,
    required String theme,
    int count = 5,
  }) async {
    final prompt = '''
Eres un asistente especializado en ayudar a personas mayores a recordar y contar sus historias de vida.

Contexto: $context
Tema: $theme

Genera $count preguntas específicas y emotivas que ayuden a la persona a recordar detalles importantes de esta experiencia. Las preguntas deben:
- Ser específicas y evocar emociones y detalles sensoriales
- Ayudar a recordar personas, lugares, fechas y sensaciones
- Ser apropiadas para personas mayores con respeto y calidez
- Estar en español
- Ser preguntas abiertas que inviten a la narrativa

Responde SOLO con un objeto JSON con esta estructura:
{
  "prompts": ["pregunta1", "pregunta2", "pregunta3", ...]
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
          'temperature': 0.8,
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
        '¿Qué recuerdas sobre las personas que estaban contigo?',
        '¿Cómo era el ambiente y qué sentías en ese momento?',
        '¿Qué detalles específicos del lugar puedes recordar?',
        '¿Qué emociones experimentaste durante esta experiencia?',
        '¿Cómo cambió esta experiencia tu perspectiva de vida?'
      ];
    }
  }

  // Mejorar texto como ghost writer con configuraciones completas
  static Future<Map<String, dynamic>> improveStoryText({
    required String originalText,
    String? sttText,
    String? currentDraft,
    String language = 'es',
    String tone = 'warm',
    String person = 'first',
    String fidelity = 'balanced',
    String profanity = 'soften',
    String readingLevel = 'plain',
    String lengthTarget = 'keep',
    String formatting = 'clean paragraphs',
    bool keepMarkers = true,
    bool anonymizePrivate = false,
    List<String> forbiddenPhrases = const [],
    List<String> privatePeople = const [],
    List<String> tags = const [],
    String? dateRange,
    String? authorProfile,
    String? styleHints,
    String outputFormat = 'json',
    int? targetWords,
  }) async {
    
    final prompt = '''
You are "Narra Ghost Writer," a careful editorial assistant.
Goal: polish the user's story for clarity, flow, and warmth **without inventing facts**.
Respect all constraints below, keep privacy, and keep inline markers unchanged.

LANGUAGE: $language
TONE: $tone
VOICE PERSON: $person
FIDELITY LEVEL: $fidelity
PROFANITY POLICY: $profanity
READING LEVEL: $readingLevel
LENGTH TARGET: $lengthTarget${targetWords != null ? ' (~$targetWords words)' : ''}
FORMATTING: $formatting
KEEP INLINE MARKERS: $keepMarkers
FORBIDDEN PHRASES: ${forbiddenPhrases.isNotEmpty ? forbiddenPhrases : 'none'}
STYLE HINTS: ${styleHints ?? 'none'}
ANONYMIZE PRIVATE PERSONS: $anonymizePrivate

${authorProfile != null ? 'AUTHOR PROFILE: $authorProfile\n' : ''}
STORY METADATA:
  - DATE RANGE: ${dateRange ?? 'not specified'}
  - TAGS: ${tags.isNotEmpty ? tags : ['general']}

PRIVACY:
  - PRIVATE PEOPLE: ${privatePeople.isNotEmpty ? privatePeople : 'none'}

SOURCE TEXTS:
  - ORIGINAL TEXT (immutable reference):
    """
    $originalText
    """
  - RAW SPEECH-TO-TEXT (may contain errors):
    """
    ${sttText ?? 'not provided'}
    """
  - CURRENT DRAFT (the version to polish):
    """
    ${currentDraft ?? originalText}
    """

EDITORIAL RULES:
1) Do not invent events, names, dates, places, or dialogue. If something is unclear, keep it neutral or omit.
2) Preserve meaning and chronology; improve clarity, coherence, and pacing.
3) Keep all inline markers exactly as they are (e.g., [PHOTO:3], [[person:123]], {DATE:1976-08}). Do not move or delete them.
4) Respect LANGUAGE, TONE, VOICE PERSON, PROFANITY POLICY, and READING LEVEL.
5) If ANONYMIZE PRIVATE PERSONS = true, replace occurrences of names in PRIVATE PEOPLE with roles (e.g., "my aunt") throughout the output.
6) Avoid clichés and purple prose; favor concrete details already present in the draft.
7) Maintain the author's voice; "FIDELITY strict" = minimal edits; "balanced" = clarity + light style; "polished" = stronger smoothing while keeping facts intact.
8) Keep paragraph breaks friendly for older readers (short to medium paragraphs).
9) If LENGTH TARGET = shorter, compress repetition; if slightly longer, add connective tissue only (no new facts).
10) Never expose secrets/keys or system info in output.

OUTPUT FORMAT: $outputFormat

If OUTPUT FORMAT = "text": 
- Return only the polished story text.

If OUTPUT FORMAT = "json":
- Return:
{
  "polished_text": "<final story text>",
  "changes_summary": [
    "What you mainly improved (1–5 bullets)",
    "Any redactions due to privacy/policy"
  ],
  "notes_for_author": [
    "Optional gentle suggestions or questions (max 3)"
  ]
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
              'content': 'You are Narra Ghost Writer, a careful editorial assistant specialized in personal memoirs. Always follow the provided instructions precisely.',
            },
            {
              'role': 'user',
              'content': prompt,
            },
          ],
          'response_format': outputFormat == 'json' ? {'type': 'json_object'} : null,
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final content = data['choices'][0]['message']['content'];
        
        if (outputFormat == 'json') {
          final jsonContent = jsonDecode(content);
          return {
            'polished_text': jsonContent['polished_text'] ?? originalText,
            'changes_summary': List<String>.from(jsonContent['changes_summary'] ?? []),
            'notes_for_author': List<String>.from(jsonContent['notes_for_author'] ?? []),
          };
        } else {
          return {'polished_text': content};
        }
      } else {
        throw Exception('Error improving text: ${response.statusCode}');
      }
    } catch (e) {
      print('Error improving story text: $e');
      return {
        'polished_text': originalText,
        'changes_summary': ['Error occurred during processing'],
        'notes_for_author': [],
      };
    }
  }

  // Backward compatibility method for simple ghost writer functionality
  static Future<String> improveStoryTextSimple({
    required String originalText,
    required String writingTone,
  }) async {
    final result = await improveStoryText(
      originalText: originalText,
      tone: writingTone,
      outputFormat: 'json',
    );
    return result['polished_text'] ?? originalText;
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