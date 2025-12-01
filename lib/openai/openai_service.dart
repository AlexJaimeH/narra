import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:narra/repositories/ai_usage_repository.dart';

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
  static final RegExp _photoPlaceholderPattern = RegExp(r'\[img_(\d+)\]');

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

  /// Registra el uso de IA en la base de datos
  static Future<void> _logAIUsage({
    required String usageType,
    required Map<String, dynamic> apiResponse,
    String? storyId,
    Map<String, dynamic>? requestMetadata,
  }) async {
    try {
      // Extraer información de uso de la respuesta de OpenAI
      final usage = apiResponse['usage'] as Map<String, dynamic>?;
      if (usage == null) return;

      final promptTokens = usage['prompt_tokens'] as int? ?? 0;
      final completionTokens = usage['completion_tokens'] as int? ?? 0;
      final totalTokens = usage['total_tokens'] as int? ?? 0;

      // Extraer el modelo usado de la respuesta
      final modelUsed = apiResponse['model'] as String? ?? 'unknown';

      // Calcular costo estimado
      final estimatedCost = AIUsageRepository.estimateCost(
        model: modelUsed,
        promptTokens: promptTokens,
        completionTokens: completionTokens,
      );

      // Registrar uso
      await AIUsageRepository.logUsage(
        usageType: usageType,
        modelUsed: modelUsed,
        totalTokens: totalTokens,
        promptTokens: promptTokens,
        completionTokens: completionTokens,
        estimatedCostUsd: estimatedCost,
        storyId: storyId,
        requestMetadata: requestMetadata,
        responseMetadata: {
          'finish_reason': apiResponse['choices']?[0]?['finish_reason'],
        },
      );
    } catch (error) {
      // No queremos que un error de logging rompa la funcionalidad
      debugPrint('⚠️ [OpenAIService] Error logging AI usage: $error');
    }
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
    List<String>? suggestedTopics,
    List<Map<String, dynamic>>? previousStoryDates,
    String? storyId,
  }) async {
    final trimmedTitle = title.trim();
    final trimmedContent = content.trim();
    final wordCount = trimmedContent.isEmpty
        ? 0
        : trimmedContent
            .split(RegExp(r'\s+'))
            .where((word) => word.isNotEmpty)
            .length;
    final hasContent = trimmedContent.isNotEmpty && wordCount >= 20;
    final hasMinimalContent = trimmedContent.isNotEmpty && wordCount < 20;

    final contextSummary = hasContent
        ? 'Borrador actual:\n"""$trimmedContent"""'
        : hasMinimalContent
            ? 'Borrador inicial (muy breve):\n"""$trimmedContent"""'
            : 'Borrador actual: (sin texto aún)';

    // Agregar contexto de temas sugeridos cuando no hay mucho contenido
    final topicsContext = (!hasContent && suggestedTopics != null && suggestedTopics.isNotEmpty)
        ? '\n\n## Temas sugeridos para explorar\nEl autor podría estar interesado en escribir sobre estos temas: ${suggestedTopics.join(", ")}.\nUsa estos temas como inspiración para generar sugerencias concretas y específicas que ayuden al autor a comenzar su historia.'
        : '';

    // Agregar contexto de historias anteriores con fechas
    String datesContext = '';
    if (!hasContent && previousStoryDates != null && previousStoryDates.isNotEmpty) {
      final datesList = previousStoryDates.map((story) {
        final date = story['date'] as DateTime;
        final precision = story['precision'] as String;
        final title = story['title'] as String;

        String dateStr;
        if (precision == 'year') {
          dateStr = '${date.year}';
        } else if (precision == 'month') {
          dateStr = '${date.month}/${date.year}';
        } else {
          dateStr = '${date.day}/${date.month}/${date.year}';
        }
        return '- "$title" (fecha: $dateStr)';
      }).join('\n');

      datesContext = '\n\n## Historias anteriores del autor\nEl autor ya ha escrito sobre estos periodos de su vida:\n$datesList\n\nCONSIDERA ESTAS FECHAS para sugerir periodos que aún no ha cubierto. Sugiere desde lo MÁS SENCILLO a lo más complicado: generalmente escribir sobre la infancia y juventud es más fácil que periodos recientes. Prioriza sugerencias de periodos tempranos de su vida si aún no los ha cubierto.';
    }

    final prompt = '''
Actúas como "Narra Story Coach", un coach narrativo cálido y empático que ayuda a personas comunes (NO escritores profesionales) a escribir sus historias de vida para compartir con familia y seres queridos.

## IMPORTANTE: Perfil del usuario
El usuario es una persona común que quiere preservar sus memorias y experiencias de vida para sus seres queridos. NO es escritor profesional. Necesita:
- Sugerencias CONCRETAS y ESPECÍFICAS, no abstractas
- Preguntas que despierten recuerdos específicos (nombres, lugares, fechas, olores, sabores, sensaciones)
- Inspiración práctica que lo ayude a EMPEZAR a escribir inmediatamente
- Lenguaje cercano, amable y motivador (como un amigo que lo anima)
- Ideas que lo hagan recordar momentos vividos, no técnicas literarias

## Información del autor
- Título provisional: ${trimmedTitle.isEmpty ? 'Sin título' : '"$trimmedTitle"'}
- Palabras actuales: $wordCount
- $contextSummary$topicsContext$datesContext

## Tareas principales
1. Si el texto está vacío o tiene muy poco (menos de 20 palabras):
   - Ofrece IDEAS CONCRETAS y ESPECÍFICAS sobre qué escribir (no técnicas abstractas)
   - Si hay fechas de historias anteriores, identifica PERIODOS que aún no ha cubierto y sugiere sobre esos
   - Prioriza SIEMPRE periodos tempranos de la vida (infancia, juventud) porque son más fáciles de escribir
   - Sugiere escenas o momentos MUY específicos para comenzar (ej: "Escribe sobre tu primer día de escuela: ¿cómo era el salón? ¿quién era tu maestro/a?")
   - Da ejemplos breves y concretos de cómo podría empezar a escribir
   - Usa los temas sugeridos (si se proporcionan) para inspirar ideas concretas
   - MENCIONA que puede empezar escribiendo algo breve y luego dar clic en "Sugerencias" de nuevo para que le ayudes a continuar y expandir la historia

2. Si hay texto pero está incompleto (20-200 palabras):
   - SIMPLIFICA tus sugerencias: la gente no lee mucho, hazlo MUY fácil de entender
   - EVALÚA si la historia ya está bien o le falta más (sé honesto y claro)
   - Haz PREGUNTAS ESPECÍFICAS que ayuden a completar la historia (¿qué falta?)
   - Identifica detalles sensoriales que faltan (¿cómo olía? ¿qué colores veías? ¿qué sonidos escuchabas?)
   - Pregunta por personas específicas que podrían haber estado ahí
   - Sugiere qué más puede poner para CERRAR BIEN su historia (de su estilo de escritura, no sugiriendo técnicas literarias)
   - Si la historia necesita pulirse profesionalmente, menciona que puede usar el "Asistente de IA (Ghost Writer)" para mejorar la redacción
   - Recomienda detalles emocionales (¿qué sentiste? ¿qué pensaste en ese momento?)

3. Si el relato está avanzado (más de 200 palabras):
   - Celebra lo bien que va (sé específico sobre qué está bien)
   - Evalúa si YA ESTÁ LISTA para publicar o todavía le falta algo
   - Si le falta algo, di QUÉ específicamente y por qué
   - Sugiere detalles finales CONCRETOS que lo enriquezcan (no generalidades)
   - Propón una reflexión o cierre emotivo si aún no lo tiene
   - Si solo necesita pulirse, menciona el "Asistente de IA (Ghost Writer)" para mejorar la redacción profesionalmente

## Estados disponibles (sé REALISTA con el diagnóstico)
- "starting_out": sin texto o menos de 20 palabras
- "needs_more": hay texto pero falta contexto, detalles o claridad
- "in_progress": el relato tiene buen avance y estructura
- "complete": la historia está completa, clara y emotiva

## Formato de salida
Responde SOLO con un objeto JSON válido que cumpla exactamente el siguiente esquema:
{
  "status": "starting_out" | "needs_more" | "in_progress" | "complete",
  "summary": "Diagnóstico breve y cálido (2-3 frases máximo)",
  "sections": [
    {
      "title": "Título atractivo y específico del bloque",
      "purpose": "ideas" | "questions" | "edits" | "reflection" | "memories",
      "description": "Explicación breve de por qué estas sugerencias son útiles (o cadena vacía)",
      "items": [
        "Sugerencia MUY concreta y accionable",
        "Pregunta específica que evoque recuerdos (incluye ejemplos si ayuda)",
        "Idea práctica que el usuario pueda escribir AHORA MISMO"
      ]
    }
  ],
  "next_steps": [
    "Paso inmediato y concreto (ej: 'Describe el olor de la cocina de tu abuela')",
    "Acción específica que pueda hacer en 5 minutos"
  ],
  "missing_pieces": [
    "Detalle concreto que falta (ej: '¿Qué edad tenías?', '¿Quién más estaba ahí?')"
  ],
  "warmups": [
    "Pregunta evocadora con ejemplos (ej: '¿Recuerdas alguna comida especial que cocinaba tu familia? ¿Cómo olía la casa?')",
    "Idea específica para comenzar a escribir basada en los temas sugeridos"
  ],
  "encouragement": "Mensaje MUY cálido y personal que celebre su esfuerzo y lo motive a continuar. Usa 'tú' o 'usted' según el contexto. Hazlo sentir que está haciendo algo valioso e importante para su familia."
}

## REGLAS IMPORTANTES:
- SIMPLICIDAD ANTE TODO: La gente no lee mucho, haz sugerencias CORTAS, CLARAS y MUY FÁCILES de entender
- Todas las sugerencias deben ser ESPECÍFICAS, no genéricas
- Usa preguntas que incluyan ejemplos concretos (¿Recuerdas...? ¿Cómo era...? ¿Qué sentías cuando...?)
- Si hay temas sugeridos Y fechas de historias anteriores, úsalos para generar ideas concretas sobre PERIODOS que aún no ha cubierto
- Cuando sugiera periodos de vida, SIEMPRE prioriza los más tempranos (infancia, niñez, adolescencia) porque son más fáciles de recordar y escribir
- Los "warmups" son para inspirar al usuario cuando no sabe qué escribir - deben ser IDEAS CONCRETAS, no abstractas
- Los "next_steps" deben ser acciones INMEDIATAS que pueda hacer en menos de 5 minutos
- El "encouragement" debe ser genuino y hacer que el usuario se sienta orgulloso de escribir sus memorias
- Si hay contenido, EVALÚA honestamente si ya está bien o le falta más, y DILO CLARAMENTE
- Cuando la historia necesite pulido profesional (no solo más contenido), menciona el "Asistente de IA (Ghost Writer)"
- Mantén todo en español neutro y cálido
- Si no hay texto, prioriza "warmups" y "ideas" muy concretas para empezar, y MENCIONA que puede escribir algo breve y volver a pedir sugerencias
- Si el relato está completo, celebra mucho y di claramente "Tu historia ya está lista" o similar
''';

    final data = await _proxyChat(
      messages: [
        {
          'role': 'system',
          'content':
              'Eres Narra Story Coach, un coach narrativo cálido y empático especializado en ayudar a personas comunes (no escritores profesionales) a escribir sus historias de vida. Tu objetivo es inspirar, motivar y guiar con sugerencias MUY concretas y específicas que ayuden a recordar y escribir momentos vividos. Siempre responde con JSON válido según el formato solicitado.',
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
      temperature: hasContent ? 0.7 : 0.85,
    );

    // Registrar uso de IA (no esperar, ejecutar en background)
    unawaited(_logAIUsage(
      usageType: 'suggestions',
      apiResponse: data,
      storyId: storyId,
      requestMetadata: {
        'title_length': trimmedTitle.length,
        'content_length': trimmedContent.length,
        'word_count': wordCount,
        'has_suggested_topics': suggestedTopics != null && suggestedTopics.isNotEmpty,
        'has_previous_dates': previousStoryDates != null && previousStoryDates.isNotEmpty,
      },
    ));

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
    String? storyId,
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

    final placeholderTokenMap = <String, String>{};
    final originalTextForPrompt = _maskPhotoPlaceholders(
      originalText,
      placeholderTokenMap,
    );

    if (placeholderTokenMap.isNotEmpty) {
      additionalInstructions.insert(
        0,
        '- Mantén todos los marcadores de fotos exactamente en su posición. '
        'En el texto aparecerán como __NARRA_IMG_#__ (equivalentes a [img_#]).',
      );
    }

    final prompt = '''
Actúa como "Narra Ghost Writer", editor senior de memorias autobiográficas reales.
Tu misión es transformar el texto del autor en un capítulo digno de un libro publicado, manteniendo la verdad y la voz auténtica del autor.

## Parámetros clave (DEBEN respetarse en TODO momento)
- Título de referencia: "$title"
- Tono deseado: $toneGuidance
- Estilo de edición: $editingGuidance
- Voz narrativa: $voiceGuidance
- Idioma de entrega: $languageLabel
${additionalInstructions.isNotEmpty ? additionalInstructions.join('\n') + '\n' : ''}- Respeta absolutamente los hechos, nombres, fechas y lugares aportados.

**CRÍTICO**: Las preferencias del autor (tono, estilo de edición, instrucciones adicionales) deben aplicarse en TODA la reorganización y edición del texto. No ignores estas variables.

## Texto original
"""$originalTextForPrompt"""

## IMPORTANTE: Contexto del autor
El autor puede haber escrito sus ideas en desorden, puede haber puesto juntas cosas que no tienen mucho sentido juntas, o puede haber saltado entre diferentes momentos o ideas. Tu trabajo es tomar todo ese contenido y organizarlo para que sea un relato coherente, profesional y digno de ser publicado en un libro.

## Tareas
1. **Organización narrativa**: Si el texto está desordenado, reorganiza el contenido de manera cronológica o lógica para que tenga una secuencia narrativa clara y natural. Agrupa ideas relacionadas y separa las que no lo están. SIEMPRE respetando el tono y estilo de edición solicitados.

2. **Coherencia y fluidez**: Identifica saltos abruptos, ideas inconexas o cambios de tema sin transición. Crea conexiones suaves entre párrafos y asegúrate de que la historia fluya de principio a fin como un capítulo profesional.

3. **Estructura profesional**: Organiza el texto en párrafos bien definidos con una introducción clara, desarrollo coherente y, si corresponde, una reflexión o cierre que le dé sentido al relato.

4. **Reflexión y cierre íntimo (SOLO si aplica)**: Si el relato lo permite y tiene sentido, agrega al final una reflexión breve que revele qué significaron esos recuerdos en la vida del autor y un cierre más íntimo que conecte la memoria con su identidad. IMPORTANTE: No añadas ningún hecho nuevo, solo una reflexión basada en lo que el autor ya escribió.

5. **Corrección técnica**: Corrige ortografía, gramática, puntuación y acentos.

6. **Calidad literaria**: Mejora la redacción para que suene profesional y publicable. Refuerza la emoción y los detalles sensoriales solo cuando surjan naturalmente del texto original. Evita repeticiones innecesarias y frases redundantes. RESPETA el tono deseado ($toneGuidance) en todo momento.

7. **Fidelidad absoluta**: NUNCA inventes hechos, nombres, fechas, lugares o eventos que no estén en el texto original. Solo reorganiza, conecta y pule lo que el autor ya escribió.

## Resultado esperado
El texto final debe leerse como un capítulo completo y profesional de un libro publicado: bien narrado, en orden, entendible, coherente y emocionalmente resonante. Debe cumplir con TODAS las preferencias del autor (tono, estilo, instrucciones adicionales).

## Formato de salida
Devuelve EXCLUSIVAMENTE un JSON válido con la forma:
{
  "polished_text": "...",
  "changes_summary": "...",
  "suggestions": ["...", "..."],
  "tone_analysis": "...",
  "word_count": 123
}

- "polished_text": versión final lista para reemplazar el borrador, escrita en $languageLabel. Debe ser un texto completo, organizado, coherente y profesional.
- "changes_summary": resumen breve (máx. 3 frases) de las mejoras aplicadas, especialmente si reorganizaste el contenido.
- "suggestions": hasta 3 sugerencias concretas para continuar mejorando.
- "tone_analysis": explica cómo aplicaste el tono solicitado y las instrucciones adicionales del autor.
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

      // Registrar uso de IA (no esperar, ejecutar en background)
      unawaited(_logAIUsage(
        usageType: 'ghost_writer',
        apiResponse: data,
        storyId: storyId,
        requestMetadata: {
          'title': title,
          'tone': tone,
          'fidelity': fidelity,
          'language': language,
          'perspective': perspective,
          'avoid_profanity': avoidProfanity,
          'original_text_length': originalText.length,
          'has_extra_instructions': extraInstructions.isNotEmpty,
        },
      ));

      final content = jsonDecode(data['choices'][0]['message']['content']);
      final polishedTextRaw = (content['polished_text'] as String?)?.trim();
      final missingTokens = placeholderTokenMap.keys
          .where((token) =>
              polishedTextRaw == null || !polishedTextRaw.contains(token))
          .toList();
      if (missingTokens.isNotEmpty) {
        print(
            'Ghost Writer response missing photo markers: ${missingTokens.join(', ')}');
      }
      final polishedText = missingTokens.isEmpty
          ? _restorePhotoPlaceholders(
              polishedTextRaw ?? originalText,
              placeholderTokenMap,
            )
          : originalText;
      final summaryRaw = (content['changes_summary'] as String?)?.trim() ??
          'Sin cambios reportados';
      final summary = _restorePhotoPlaceholders(
        summaryRaw,
        placeholderTokenMap,
      );
      final toneAnalysisRaw = (content['tone_analysis'] as String?)?.trim() ??
          'No se proporcionó análisis de tono';
      final toneAnalysis = _restorePhotoPlaceholders(
        toneAnalysisRaw,
        placeholderTokenMap,
      );
      final suggestionsListRaw = content['suggestions'] is List
          ? List<String>.from(content['suggestions'])
          : <String>[];
      final suggestionsList = suggestionsListRaw
          .map((suggestion) =>
              _restorePhotoPlaceholders(suggestion, placeholderTokenMap))
          .toList();
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
    final placeholderTokenMap = <String, String>{};
    final maskedOriginalText = _maskPhotoPlaceholders(
      originalText,
      placeholderTokenMap,
    );
    final String? maskedCurrentDraft = currentDraft != null
        ? _maskPhotoPlaceholders(currentDraft, placeholderTokenMap)
        : null;
    final String? maskedSttText = sttText != null
        ? _maskPhotoPlaceholders(sttText, placeholderTokenMap)
        : null;
    final inlineMarkersRule = placeholderTokenMap.isNotEmpty
        ? '3) Keep all inline markers exactly as they are (including photo tokens '
            'like __NARRA_IMG_1__ which represent [img_1]). Do not move or delete them.'
        : '3) Keep all inline markers exactly as they are (e.g., [PHOTO:3], '
            '[[person:123]], {DATE:1976-08}). Do not move or delete them.';
    final photoPlaceholderNote = placeholderTokenMap.isNotEmpty
        ? 'PHOTO PLACEHOLDERS: tokens __NARRA_IMG_#__ correspond to original [img_#]. '
            'Keep them exactly in place.\n'
        : '';

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

${photoPlaceholderNote}SOURCE TEXTS:
  - ORIGINAL TEXT (immutable reference):
    """
    $maskedOriginalText
    """
  - RAW SPEECH-TO-TEXT (may contain errors):
    """
    ${maskedSttText ?? 'not provided'}
    """
  - CURRENT DRAFT (the version to polish):
    """
    ${maskedCurrentDraft ?? maskedOriginalText}
    """

EDITORIAL RULES:
1) Do not invent events, names, dates, places, or dialogue. If something is unclear, keep it neutral or omit.
2) Preserve meaning and chronology; improve clarity, coherence, and pacing.
$inlineMarkersRule
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
        final polishedRaw = (jsonContent['polished_text'] as String?)?.trim();
        final missingTokens = placeholderTokenMap.keys
            .where(
                (token) => polishedRaw == null || !polishedRaw.contains(token))
            .toList();
        if (missingTokens.isNotEmpty) {
          print(
              'Ghost Writer advanced response missing photo markers: ${missingTokens.join(', ')}');
        }
        final polished = missingTokens.isEmpty
            ? _restorePhotoPlaceholders(
                polishedRaw ?? originalText,
                placeholderTokenMap,
              )
            : originalText;
        final changesSummaryRaw = jsonContent['changes_summary'] is List
            ? List<dynamic>.from(jsonContent['changes_summary'])
            : const <dynamic>[];
        final notesForAuthorRaw = jsonContent['notes_for_author'] is List
            ? List<dynamic>.from(jsonContent['notes_for_author'])
            : const <dynamic>[];

        return {
          'polished_text': polished,
          'changes_summary': _restorePhotoPlaceholdersInList(
            changesSummaryRaw,
            placeholderTokenMap,
          ),
          'notes_for_author': _restorePhotoPlaceholdersInList(
            notesForAuthorRaw,
            placeholderTokenMap,
          ),
        };
      } else {
        final polishedRaw = content.trim();
        final missingTokens = placeholderTokenMap.keys
            .where((token) => !polishedRaw.contains(token))
            .toList();
        if (missingTokens.isNotEmpty) {
          print(
              'Ghost Writer advanced response missing photo markers: ${missingTokens.join(', ')}');
        }
        final polished = missingTokens.isEmpty
            ? _restorePhotoPlaceholders(polishedRaw, placeholderTokenMap)
            : originalText;
        return {'polished_text': polished};
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

  static String _maskPhotoPlaceholders(
    String text,
    Map<String, String> tokenMap,
  ) {
    if (text.isEmpty) {
      return text;
    }
    return text.replaceAllMapped(_photoPlaceholderPattern, (match) {
      final number = match.group(1)!;
      final placeholder = match.group(0)!;
      final token = '__NARRA_IMG_${number}__';
      tokenMap[token] = placeholder;
      return token;
    });
  }

  static String _restorePhotoPlaceholders(
    String text,
    Map<String, String> tokenMap,
  ) {
    if (tokenMap.isEmpty || text.isEmpty) {
      return text;
    }
    var restored = text;
    tokenMap.forEach((token, placeholder) {
      restored = restored.replaceAll(token, placeholder);
    });
    return restored;
  }

  static List<String> _restorePhotoPlaceholdersInList(
    List<dynamic> items,
    Map<String, String> tokenMap,
  ) {
    if (items.isEmpty) {
      return const <String>[];
    }
    return items
        .whereType<String>()
        .map((item) => _restorePhotoPlaceholders(item, tokenMap))
        .toList();
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
