import 'dart:convert';
import 'package:http/http.dart' as http;

class OpenAIService {
  // Route proxied by Cloudflare Pages Functions. No client-side key usage.
  static const String _proxyEndpoint = '/api/openai';

  static Future<Map<String, dynamic>> _proxyChat({
    required List<Map<String, dynamic>> messages,
    String model = 'gpt-5-mini',
    Map<String, dynamic>? responseFormat,
    double temperature = 0.7,
  }) async {
    final response = await http.post(
      Uri.parse(_proxyEndpoint),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'model': model,
        'messages': messages,
        if (responseFormat != null) 'response_format': responseFormat,
        'temperature': temperature,
      }),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    }
    throw Exception('OpenAI proxy error: ${response.statusCode}');
  }

  // Generar preguntas/pistas para ayudar a escribir historias
  // Compatibilidad: acepta (currentTitle/currentContent) o (context/theme)
  static Future<List<String>> generateStoryPrompts({
    String? currentTitle,
    String? currentContent,
    String? context,
    String? theme,
    int count = 3,
  }) async {
    final bool hasDraft = (currentTitle != null && currentContent != null);
    final bool hasContext = (context != null && theme != null);
    final prompt = hasDraft
        ? '''
Analiza esta historia que se está escribiendo y genera $count preguntas específicas que ayuden al autor a expandir y enriquecer su relato.

Título actual: "${currentTitle ?? ''}"
Contenido actual: "${currentContent ?? ''}"

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
'''
        : '''
Eres un asistente especializado en ayudar a personas mayores a recordar y contar sus historias de vida.

Contexto: ${context ?? ''}
Tema: ${theme ?? ''}

Genera $count preguntas específicas y emotivas que ayuden a la persona a recordar detalles importantes de esta experiencia. Las preguntas deben:
- Ser específicas y evocar emociones y detalles sensoriales
- Ayudar a recordar personas, lugares, fechas y sensaciones
- Ser apropiadas para personas mayores con respeto y calidez
- Estar en español
- Ser preguntas abiertas que inviten a la narrativa

Responde SOLO con un objeto JSON con esta estructura:
{
  "prompts": ["pregunta1", "pregunta2", "pregunta3"]
}
''';

    try {
      final data = await _proxyChat(
        messages: [
          {
            'role': 'system',
            'content':
                'Eres un experto en storytelling para personas mayores. Siempre responde con un objeto JSON válido.',
          },
          {
            'role': 'user',
            'content': prompt,
          },
        ],
        responseFormat: {'type': 'json_object'},
        temperature: 0.7,
      );
      final content = jsonDecode(data['choices'][0]['message']['content']);
      return List<String>.from(content['prompts'] ?? []);
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

  // Ghost Writer básico (compatibilidad: título opcional)
  static Future<Map<String, dynamic>> improveStoryText({
    required String originalText,
    String title = '',
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
      'nostálgico':
          'nostalgic and warm, evoking sweet memories and gentle melancholy',
      'alegre':
          'joyful and uplifting, highlighting positive moments and celebrations',
      'emotivo':
          'deeply emotional and touching, bringing out heartfelt feelings',
      'reflexivo': 'thoughtful and contemplative, encouraging introspection',
      'divertido':
          'light-hearted and amusing, finding gentle humor in life\'s moments'
    };

    final fidelityMap = {
      'high':
          'Maintain extremely high fidelity to original facts and events. Make minimal changes.',
      'medium':
          'Preserve core facts while allowing moderate enhancement and expansion.',
      'creative':
          'Allow creative interpretation while keeping the essence of the story.'
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
      final data = await _proxyChat(
        messages: [
          {
            'role': 'system',
            'content':
                'Eres un ghost writer experto en memorias personales. Siempre responde con un objeto JSON válido.',
          },
          {
            'role': 'user',
            'content': prompt,
          },
        ],
        responseFormat: {'type': 'json_object'},
        temperature: 0.7,
      );
      final content = jsonDecode(data['choices'][0]['message']['content']);
      return {
        'polished_text': content['polished_text'] ?? originalText,
        'changes_summary': content['changes_summary'] ?? 'No changes made',
        'suggestions': List<String>.from(content['suggestions'] ?? []),
        'tone_analysis': content['tone_analysis'] ?? 'No tone analysis',
        'word_count': content['word_count'] ?? originalText.split(' ').length,
      };
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

  // Versión avanzada (parámetros extendidos, para compatibilidad con API antigua)
  static Future<Map<String, dynamic>> improveStoryTextAdvanced({
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
5) If ANONYMIZE PRIVATE PERSONS = true, replace occurrences of names in PRIVATE PEOPLE with roles (e.g., "my aunt").
6) Avoid clichés; prefer concrete details already present.
7) Keep the author's voice; adjust per FIDELITY.
8) Friendly paragraph breaks.
9) If shorter, compress repetition; if longer, add connective tissue only (no new facts).
10) Never expose secrets/keys.

OUTPUT FORMAT: $outputFormat
''';

    try {
      final data = await _proxyChat(
        messages: [
          {
            'role': 'system',
            'content':
                'You are Narra Ghost Writer, a careful editorial assistant specialized in personal memoirs. Always follow the provided instructions precisely.',
          },
          {
            'role': 'user',
            'content': prompt,
          },
        ],
        responseFormat: outputFormat == 'json' ? {'type': 'json_object'} : null,
        temperature: 0.7,
      );

      final content = data['choices'][0]['message']['content'];
      if (outputFormat == 'json') {
        final jsonContent = jsonDecode(content);
        return {
          'polished_text': jsonContent['polished_text'] ?? originalText,
          'changes_summary':
              List<String>.from(jsonContent['changes_summary'] ?? []),
          'notes_for_author':
              List<String>.from(jsonContent['notes_for_author'] ?? []),
        };
      } else {
        return {'polished_text': content};
      }
    } catch (e) {
      print('Error improving story text (advanced): $e');
      return {
        'polished_text': originalText,
        'changes_summary': ['Error occurred during processing'],
        'notes_for_author': [],
      };
    }
  }

  // Wrapper simple para compatibilidad
  static Future<String> improveStoryTextSimple({
    required String originalText,
    required String writingTone,
  }) async {
    final result = await improveStoryText(
      originalText: originalText,
      title: '',
      tone: writingTone,
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
      final data = await _proxyChat(
        messages: [
          {
            'role': 'system',
            'content':
                'Eres un experto en análisis narrativo y storytelling personal. Siempre responde con un objeto JSON válido.',
          },
          {
            'role': 'user',
            'content': prompt,
          },
        ],
        responseFormat: {'type': 'json_object'},
        temperature: 0.3,
      );
      final content = jsonDecode(data['choices'][0]['message']['content']);
      return {
        'completeness_score': content['completeness_score'] ?? 0,
        'missing_elements':
            List<String>.from(content['missing_elements'] ?? []),
        'suggestions': List<String>.from(content['suggestions'] ?? []),
        'strengths': List<String>.from(content['strengths'] ?? []),
      };
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
      final data = await _proxyChat(
        messages: [
          {
            'role': 'system',
            'content':
                'Eres un experto en títulos creativos para memorias personales. Siempre responde con un objeto JSON válido.',
          },
          {
            'role': 'user',
            'content': prompt,
          },
        ],
        responseFormat: {'type': 'json_object'},
        temperature: 0.9,
      );
      final content = jsonDecode(data['choices'][0]['message']['content']);
      return List<String>.from(content['titles'] ?? []);
    } catch (e) {
      print('Error generating title suggestions: $e');
      return ['Mi Historia', 'Recuerdos Preciados', 'Una Vida Vivida'];
    }
  }
}
