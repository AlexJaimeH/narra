import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:narra/supabase/narra_client.dart';

class AIUsageRepository {
  const AIUsageRepository._();

  static SupabaseClient get _client => NarraSupabaseClient.client;

  /// Registra el uso de una API de IA
  ///
  /// [usageType]: 'ghost_writer', 'suggestions', o 'transcription'
  /// [modelUsed]: nombre del modelo usado (ej: 'gpt-4.1', 'gpt-4o-mini-transcribe')
  /// [totalTokens]: cantidad total de tokens usados
  /// [promptTokens]: tokens del prompt (opcional)
  /// [completionTokens]: tokens de la respuesta (opcional)
  /// [estimatedCostUsd]: costo estimado en USD (opcional)
  /// [storyId]: ID de la historia asociada (opcional)
  /// [requestMetadata]: metadata adicional de la solicitud (opcional)
  /// [responseMetadata]: metadata adicional de la respuesta (opcional)
  static Future<void> logUsage({
    required String usageType,
    required String modelUsed,
    required int totalTokens,
    int? promptTokens,
    int? completionTokens,
    double? estimatedCostUsd,
    String? storyId,
    Map<String, dynamic>? requestMetadata,
    Map<String, dynamic>? responseMetadata,
  }) async {
    try {
      final user = NarraSupabaseClient.currentUser;
      if (user == null) {
        // Si no hay usuario autenticado, no registramos
        return;
      }

      final payload = <String, dynamic>{
        'user_id': user.id,
        'usage_type': usageType,
        'model_used': modelUsed,
        'total_tokens': totalTokens,
        if (promptTokens != null) 'prompt_tokens': promptTokens,
        if (completionTokens != null) 'completion_tokens': completionTokens,
        if (estimatedCostUsd != null) 'estimated_cost_usd': estimatedCostUsd,
        if (storyId != null && storyId.trim().isNotEmpty) 'story_id': storyId,
        'request_metadata': requestMetadata ?? {},
        'response_metadata': responseMetadata ?? {},
      };

      // Usar service role para insertar sin problemas de RLS
      await _client.from('ai_usage_logs').insert(payload);
    } catch (error) {
      // No queremos que un error de logging rompa la funcionalidad
      // Solo imprimimos el error en debug
      print('⚠️ [AIUsageRepository] Error logging AI usage: $error');
    }
  }

  /// Calcula el costo estimado basado en el modelo y tokens
  static double estimateCost({
    required String model,
    required int promptTokens,
    required int completionTokens,
  }) {
    // Precios por 1M tokens (según OpenAI pricing de Nov 2024)
    final Map<String, Map<String, double>> pricing = {
      'gpt-4.1': {
        'prompt': 10.00, // $10 por 1M tokens de input
        'completion': 30.00, // $30 por 1M tokens de output
      },
      'gpt-4.1-mini': {
        'prompt': 0.40, // $0.40 por 1M tokens de input
        'completion': 1.60, // $1.60 por 1M tokens de output
      },
      'gpt-4o': {
        'prompt': 2.50,
        'completion': 10.00,
      },
      'gpt-4o-mini': {
        'prompt': 0.15,
        'completion': 0.60,
      },
      'gpt-4o-mini-transcribe': {
        'prompt': 0.15,
        'completion': 0.60,
      },
      'gpt-4o-transcribe': {
        'prompt': 2.50,
        'completion': 10.00,
      },
      'whisper-1': {
        'prompt': 0.006, // $0.006 por minuto de audio (asumimos ~1000 tokens = 1 min)
        'completion': 0.0,
      },
    };

    final modelPricing = pricing[model.toLowerCase()];
    if (modelPricing == null) {
      // Si no conocemos el modelo, asumimos precios de GPT-4
      return ((promptTokens / 1000000) * 10.0) +
          ((completionTokens / 1000000) * 30.0);
    }

    final promptCost = (promptTokens / 1000000) * (modelPricing['prompt'] ?? 0);
    final completionCost =
        (completionTokens / 1000000) * (modelPricing['completion'] ?? 0);

    return promptCost + completionCost;
  }
}
