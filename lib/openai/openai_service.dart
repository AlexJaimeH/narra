import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class OpenAIProxyException implements Exception {
  OpenAIProxyException({
    required this.statusCode,
    required this.message,
    this.code,
    this.body,
  });

  final int statusCode;
  final String message;
  final String? code;
  final Map<String, dynamic>? body;

  @override
  String toString() => 'OpenAI proxy error: $statusCode - $message';
}

class OpenAIService {
  // Route proxied by Cloudflare Pages Functions. No client-side key usage.
  static const String _proxyEndpoint = '/api/openai';

  static Map<String, dynamic> _jsonSchemaFormat({
    required String name,
    required Map<String, dynamic> schema,
  }) {
    return {
      'type': 'json_schema',
      'json_schema': {
        'name': name,
        'schema': schema,
        'strict': true,
      },
    };
  }

  // October 2025: According to https://platform.openai.com/docs/models#gpt-4-1,
  // GPT-4.1 delivers the highest quality editing and long-form reasoning
  // experience generally available for narrative refinement tasks.
  static const String _bestNarrativeModel = 'gpt-4.1';
  static const String _fallbackNarrativeModel = 'gpt-4.1-mini';

  static Future<Map<String, dynamic>> _proxyChat({
    required List<Map<String, dynamic>> messages,
    String model = _bestNarrativeModel,
    Map<String, dynamic>? responseFormat,
    double? temperature = 0.7,
  }) async {
    Future<Map<String, dynamic>> send(String modelId) async {
      final response = await http.post(
        Uri.parse(_proxyEndpoint),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': modelId,
          'messages': messages,
          if (responseFormat != null) 'response_format': responseFormat,
          if (temperature != null) 'temperature': temperature,
        }),
      );

      final bodyText = utf8.decode(response.bodyBytes);
      Map<String, dynamic>? decodedBody;
      try {
        final parsed = jsonDecode(bodyText);
        if (parsed is Map<String, dynamic>) {
          decodedBody = parsed;
        }
      } catch (_) {
        // Ignore JSON parsing errors, handled below.
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (decodedBody != null) {
          return decodedBody;
        }
        throw OpenAIProxyException(
          statusCode: response.statusCode,
          message: 'respuesta inesperada del proxy',
          body: decodedBody,
        );
      }

      String errorMessage = bodyText;
      String? errorCode;

      if (decodedBody != null) {
        final errorField = decodedBody['error'];
        if (errorField is Map<String, dynamic>) {
          errorMessage = errorField['message']?.toString() ?? errorMessage;
          errorCode = errorField['code']?.toString();
        } else if (errorField is String) {
          errorMessage = errorField;
        }
      }

      throw OpenAIProxyException(
        statusCode: response.statusCode,
        message: errorMessage,
        code: errorCode,
        body: decodedBody,
      );
    }

    Future<Map<String, dynamic>> attempt(String modelId,
        {bool allowFallback = true}) async {
      try {
        return await send(modelId);
      } on OpenAIProxyException catch (error) {
        final bool shouldTryFallback = allowFallback &&
            modelId == _bestNarrativeModel &&
            error.statusCode == 404 &&
            (error.code == 'model_not_found' ||
                error.message.contains('does not exist'));

        if (shouldTryFallback) {
          debugPrint(
            'Falling back to $_fallbackNarrativeModel due to inaccessible $modelId: ${error.message}',
          );
          return attempt(_fallbackNarrativeModel, allowFallback: false);
        }
        rethrow;
      }
    }

    final chosenModel = model;
    final shouldAllowFallback = chosenModel == _bestNarrativeModel;
    return attempt(chosenModel, allowFallback: shouldAllowFallback);
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
        responseFormat: _jsonSchemaFormat(
          name: 'narra_story_prompts',
          schema: {
            'type': 'object',
            'additionalProperties': false,
            'required': ['prompts'],
            'properties': {
              'prompts': {
                'type': 'array',
                'items': {'type': 'string'},
                'minItems': count,
                'maxItems': count,
              },
            },
          },
        ),
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

  static Future<Map<String, dynamic>> generateStoryCoachPlan({
    required String title,
    required String content,
  }) async {
    final trimmedTitle = title.trim();
    final trimmedContent = content.trim();
    final wordCount = trimmedContent.isEmpty
        ? 0
        : trimmedContent
            .split(RegExp(r'\s+'))
            .where((word) => word.isNotEmpty)
            .length;
    final hasContent = trimmedContent.isNotEmpty;

    final contextSummary = hasContent
        ? 'Borrador actual:\n"""$trimmedContent"""'
        : 'Borrador actual: (sin texto aún)';

    final prompt = '''
Actúas como "Narra Story Coach", un editor y coach narrativo que acompaña a personas hispanohablantes sin experiencia editorial a escribir memorias familiares claras, completas y emocionantes.

## Información del autor
- Título provisional: ${trimmedTitle.isEmpty ? 'Sin título' : '"$trimmedTitle"'}
- Palabras actuales: $wordCount
- $contextSummary

## Tareas
1. Evalúa el avance general del texto.
2. Detecta si faltan etapas, personajes o detalles importantes.
3. Sugiere ideas concretas y preguntas cálidas que ayuden a ampliar o pulir el relato.
4. Propone siguientes pasos claros para que la persona continúe escribiendo.
5. Cierra con un mensaje de ánimo personalizado que refuerce la confianza.

## Estados disponibles
- "starting_out": la persona aún no escribe o apenas comienza.
- "needs_more": hay borrador, pero faltan partes clave o claridad.
- "in_progress": el relato avanza bien aunque puede profundizar.
- "complete": el relato está completo y claro, basta con celebrarlo.

## Formato de salida
Responde SOLO con un objeto JSON válido que cumpla exactamente el siguiente esquema:
{
  "status": "starting_out" | "needs_more" | "in_progress" | "complete",
  "summary": "Resumen breve del diagnóstico",
  "sections": [
    {
      "title": "Título breve del bloque",
      "purpose": "ideas" | "questions" | "edits" | "reflection" | "memories",
      "description": "Contexto opcional (usa cadena vacía si no aplica)",
      "items": ["Sugerencia concreta 1", "Sugerencia concreta 2"]
    }
  ],
  "next_steps": ["Paso inmediato 1", "Paso inmediato 2"],
  "missing_pieces": ["Detalle a profundizar"],
  "warmups": ["Idea o pregunta para inspirar"],
  "encouragement": "Mensaje motivador en segunda persona"
}

- Mantén todas las respuestas en español neutro.
- Si no hay texto, entrega warmups e ideas para comenzar.
- Si el relato está completo, celebra el logro pero ofrece un repaso final amable.
- Ajusta el tono para que sea cercano, cálido y profesional.
- Incluye siempre todos los campos del esquema, aunque alguna lista quede vacía o la descripción sea una cadena vacía.
''';

    final data = await _proxyChat(
      messages: [
        {
          'role': 'system',
          'content':
              'Eres Narra Story Coach, un editor empático que orienta autobiografías familiares en español. Siempre responde con JSON válido según el formato solicitado.',
        },
        {
          'role': 'user',
          'content': prompt,
        },
      ],
      responseFormat: _jsonSchemaFormat(
        name: 'narra_story_coach_plan',
        schema: {
          'type': 'object',
          'additionalProperties': false,
          'required': [
            'status',
            'summary',
            'sections',
            'next_steps',
            'missing_pieces',
            'warmups',
            'encouragement',
          ],
          'properties': {
            'status': {
              'type': 'string',
              'enum': [
                'starting_out',
                'needs_more',
                'in_progress',
                'complete',
              ],
            },
            'summary': {'type': 'string', 'minLength': 1},
            'sections': {
              'type': 'array',
              'minItems': 1,
              'maxItems': 4,
              'items': {
                'type': 'object',
                'additionalProperties': false,
                'required': ['title', 'purpose', 'description', 'items'],
                'properties': {
                  'title': {'type': 'string', 'minLength': 1},
                  'purpose': {
                    'type': 'string',
                    'enum': [
                      'ideas',
                      'questions',
                      'edits',
                      'reflection',
                      'memories',
                    ],
                  },
                  'description': {'type': 'string', 'minLength': 0},
                  'items': {
                    'type': 'array',
                    'minItems': 1,
                    'maxItems': 5,
                    'items': {'type': 'string', 'minLength': 1},
                  },
                },
              },
            },
            'next_steps': {
              'type': 'array',
              'minItems': 1,
              'maxItems': 5,
              'items': {'type': 'string', 'minLength': 1},
            },
            'missing_pieces': {
              'type': 'array',
              'items': {'type': 'string', 'minLength': 1},
              'maxItems': 6,
            },
            'warmups': {
              'type': 'array',
              'items': {'type': 'string', 'minLength': 1},
              'maxItems': 5,
            },
            'encouragement': {'type': 'string', 'minLength': 1},
          },
        },
      ),
      temperature: hasContent ? 0.7 : 0.8,
    );

    final contentRaw = data['choices'][0]['message']['content'];
    final decoded = jsonDecode(contentRaw);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    throw Exception('Respuesta inválida del asistente de Story Coach');
  }

  // Ghost Writer básico (compatibilidad: título opcional)
  static Future<Map<String, dynamic>> improveStoryText({
    required String originalText,
    String title = '',
    String tone = 'warm',
    String fidelity = 'balanced',
    String language = 'es',
    String perspective = 'first',
    bool avoidProfanity = false,
    String extraInstructions = '',
  }) async {
    final toneDescriptions = {
      'formal':
          'un tono formal, elegante y cuidado, propio de una obra literaria',
      'neutral': 'un tono claro y directo, objetivo pero cercano',
      'warm':
          'un tono cálido, humano y emotivo, ideal para memorias familiares',
    };

    final fidelityDescriptions = {
      'faithful':
          'Realiza solo correcciones imprescindibles y conserva al máximo la redacción original.',
      'balanced':
          'Mejora claridad, ritmo y emoción respetando por completo los hechos y la voz del autor.',
      'polished':
          'Pulir estilo, ritmo y riqueza expresiva para lograr un acabado editorial sin alterar los hechos.',
    };

    final perspectiveDescriptions = {
      'first': 'primera persona (yo/nosotros)',
      'third': 'tercera persona (él/ella/ellos)',
    };

    final languageNames = {
      'es': 'español',
      'en': 'inglés',
      'pt': 'portugués',
    };

    final languageLabel = languageNames[language] ?? 'español';
    final editingGuidance =
        fidelityDescriptions[fidelity] ?? fidelityDescriptions['balanced']!;
    final voiceGuidance = perspectiveDescriptions[perspective] ??
        perspectiveDescriptions['first']!;
    final toneGuidance = toneDescriptions[tone] ?? toneDescriptions['warm']!;
    final sanitizedInstructions = extraInstructions.trim();
    final additionalInstructions = <String>[
      if (avoidProfanity)
        '- Evita palabrotas o expresiones agresivas; usa un lenguaje amable y respetuoso.',
      if (sanitizedInstructions.isNotEmpty)
        '- Preferencias del autor: $sanitizedInstructions',
    ];

    final prompt = '''
Actúa como "Narra Ghost Writer", editor senior de memorias autobiográficas reales.
Tu misión es pulir el texto para que pueda publicarse en un libro manteniendo la verdad y la voz auténtica del autor.

## Parámetros clave
- Título de referencia: "$title"
- Tono deseado: $toneGuidance
- Estilo de edición: $editingGuidance
- Voz narrativa: $voiceGuidance
- Idioma de entrega: $languageLabel
${additionalInstructions.isNotEmpty ? additionalInstructions.join('\n') + '\n' : ''}- Respeta absolutamente los hechos, nombres, fechas y lugares aportados.

## Texto original
"""$originalText"""

## Tareas
1. Corrige ortografía, gramática, puntuación y acentos.
2. Mejora la fluidez, las transiciones y la estructura de párrafos para lectura editorial.
3. Refuerza la emoción y los detalles sensoriales solo cuando surjan naturalmente del texto original.
4. Evita repeticiones innecesarias y frases redundantes.
5. Mantén el ritmo y la extensión general; no inventes ni alteres hechos.

## Formato de salida
Devuelve EXCLUSIVAMENTE un JSON válido con la forma:
{
  "polished_text": "...",
  "changes_summary": "...",
  "suggestions": ["...", "..."],
  "tone_analysis": "...",
  "word_count": 123
}

- "polished_text": versión final lista para reemplazar el borrador, escrita en $languageLabel.
- "changes_summary": resumen breve (máx. 3 frases) de las mejoras aplicadas.
- "suggestions": hasta 3 sugerencias concretas para continuar mejorando.
- "tone_analysis": explica cómo aplicaste el tono solicitado.
- "word_count": número de palabras del texto mejorado.

Responde únicamente con el objeto JSON y nada más.
''';

    try {
      final data = await _proxyChat(
        messages: [
          {
            'role': 'system',
            'content':
                'Eres un editor literario experto en memorias personales. Siempre responde con un objeto JSON válido.',
          },
          {
            'role': 'user',
            'content': prompt,
          },
        ],
        responseFormat: _jsonSchemaFormat(
          name: 'narra_ghost_writer_polish',
          schema: {
            'type': 'object',
            'additionalProperties': false,
            'required': [
              'polished_text',
              'changes_summary',
              'suggestions',
              'tone_analysis',
              'word_count',
            ],
            'properties': {
              'polished_text': {'type': 'string'},
              'changes_summary': {'type': 'string'},
              'suggestions': {
                'type': 'array',
                'items': {'type': 'string'},
                'maxItems': 3,
              },
              'tone_analysis': {'type': 'string'},
              'word_count': {'type': 'integer', 'minimum': 0},
            },
          },
        ),
        temperature: 0.55,
      );
      final content = jsonDecode(data['choices'][0]['message']['content']);
      final polishedText =
          (content['polished_text'] as String?)?.trim() ?? originalText;
      final summary = (content['changes_summary'] as String?)?.trim() ??
          'Sin cambios reportados';
      final toneAnalysis = (content['tone_analysis'] as String?)?.trim() ??
          'No se proporcionó análisis de tono';
      final suggestionsList = content['suggestions'] is List
          ? List<String>.from(content['suggestions'])
          : <String>[];
      final wordCountValue = content['word_count'];
      final wordCount = wordCountValue is num
          ? wordCountValue.toInt()
          : polishedText
              .split(RegExp(r'\s+'))
              .where((word) => word.isNotEmpty)
              .length;

      return {
        'polished_text': polishedText,
        'changes_summary': summary,
        'suggestions': suggestionsList,
        'tone_analysis': toneAnalysis,
        'word_count': wordCount,
      };
    } catch (e) {
      print('Error improving story text: $e');
      final fallbackWordCount = originalText
          .split(RegExp(r'\s+'))
          .where((word) => word.isNotEmpty)
          .length;
      return {
        'polished_text': originalText,
        'changes_summary': 'No se pudo completar la mejora automáticamente.',
        'suggestions': <String>[],
        'tone_analysis': 'No fue posible analizar el tono solicitado.',
        'word_count': fallbackWordCount,
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
        responseFormat: outputFormat == 'json'
            ? _jsonSchemaFormat(
                name: 'narra_ghost_writer_advanced',
                schema: {
                  'type': 'object',
                  'additionalProperties': false,
                  'required': [
                    'polished_text',
                    'changes_summary',
                    'notes_for_author',
                  ],
                  'properties': {
                    'polished_text': {'type': 'string'},
                    'changes_summary': {
                      'type': 'array',
                      'items': {'type': 'string'},
                    },
                    'notes_for_author': {
                      'type': 'array',
                      'items': {'type': 'string'},
                    },
                  },
                },
              )
            : null,
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
