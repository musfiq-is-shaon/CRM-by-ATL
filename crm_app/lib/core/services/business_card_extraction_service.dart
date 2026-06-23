import 'package:image_picker/image_picker.dart';

import '../config/crm_env_config.dart';
import 'docstrange_extraction_service.dart';

/// Business-card OCR via DocStrange JSON extraction + CRM field schema.
class BusinessCardExtractionService {
  BusinessCardExtractionService._();

  /// Runs DocStrange sync JSON extraction with the CRM business-card schema.
  ///
  /// Returns raw `result.json.content` map (canonical DocStrange payload).
  static Future<Map<String, dynamic>> extractBusinessCardJson(XFile file) async {
    final result = await DocStrangeExtractionService.extractJsonSync(
      file,
      jsonOptions: CrmEnvConfig.businessCardJsonOptions,
    );
    return result.content;
  }

  static Future<Map<String, dynamic>> extractBusinessCardJsonWithRetry(
    XFile file,
  ) async {
    final result = await DocStrangeExtractionService.extractJsonSyncWithRetry(
      file,
      jsonOptions: CrmEnvConfig.businessCardJsonOptions,
    );
    return result.content;
  }

  /// OCR multiple card images in sequential batches (parallel within each batch).
  static Future<List<Map<String, dynamic>>> extractBusinessCardJsonBatch(
    List<XFile> files, {
    int batchSize = 2,
    void Function(int completed, int total)? onProgress,
  }) async {
    if (files.isEmpty) return [];

    final results = <Map<String, dynamic>>[];
    for (var start = 0; start < files.length; start += batchSize) {
      final end = start + batchSize > files.length
          ? files.length
          : start + batchSize;
      final batch = files.sublist(start, end);
      final batchResults = await Future.wait(
        batch.map(extractBusinessCardJsonWithRetry),
      );
      results.addAll(batchResults);
      onProgress?.call(results.length, files.length);
    }
    return results;
  }
}
