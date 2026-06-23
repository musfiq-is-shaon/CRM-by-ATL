import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../config/crm_env_config.dart';

/// Parsed DocStrange JSON extraction (`result.json.content` + optional metadata).
class DocStrangeJsonResult {
  const DocStrangeJsonResult({
    required this.content,
    this.metadata,
    this.recordId,
    this.processingTimeSeconds,
  });

  /// Field map from `result.json.content` (DocStrange canonical payload).
  final Map<String, dynamic> content;

  /// `result.json.metadata` — confidence scores, bounding boxes, etc.
  final Map<String, dynamic>? metadata;

  final String? recordId;
  final double? processingTimeSeconds;

  Map<String, dynamic>? get confidenceScores {
    final meta = metadata;
    if (meta == null) return null;
    final cs = meta['confidence_score'] ?? meta['confidenceScore'];
    if (cs is Map) return Map<String, dynamic>.from(cs);
    return null;
  }
}

/// Nanonets DocStrange document extraction client.
///
/// Official flow (sync JSON):
/// ```bash
/// curl -X POST "https://extraction-api.nanonets.com/api/v1/extract/sync" \
///   -H "Authorization: Bearer $KEY" \
///   -F "file=@card.jpg" \
///   -F "output_format=json" \
///   -F 'json_options=["name","company","email"]'
/// ```
///
/// Response shape: `{ success, status, result: { json: { content: {...}, metadata: {} } } }`
///
/// Docs: https://docstrange.nanonets.com/docs/examples
class DocStrangeExtractionService {
  DocStrangeExtractionService._();

  static const String _base = 'https://extraction-api.nanonets.com';
  static const String _syncPath = '/api/v1/extract/sync';
  static const String _resultsPath = '/api/v1/extract/results';

  static const int _max429Attempts = 5;
  static const int _maxPollRounds = 90;
  static const Duration _pollEvery = Duration(seconds: 2);

  static void _needKey() {
    if (!CrmEnvConfig.isNanonetsConfigured) {
      throw StateError(CrmEnvConfig.nanonetsSetupHint);
    }
  }

  static String _fileName(XFile file) =>
      file.name.isNotEmpty ? file.name : file.path.split(RegExp(r'[/\\]')).last;

  static Future<http.Response> _postMultipartRetry(
    http.MultipartRequest Function() build,
  ) async {
    for (var i = 0; i < _max429Attempts; i++) {
      final streamed = await build().send();
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode == 429 && i < _max429Attempts - 1) {
        await Future<void>.delayed(Duration(seconds: 1 << i));
        continue;
      }
      return res;
    }
    throw Exception('429 after $_max429Attempts POST attempts');
  }

  static Future<http.Response> _getResultsRetry(Uri uri) async {
    final apiKey = CrmEnvConfig.nanonetsApiKey;
    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Accept': 'application/json',
    };
    for (var i = 0; i < _max429Attempts; i++) {
      final res = await http.get(uri, headers: headers);
      if (res.statusCode == 429 && i < _max429Attempts - 1) {
        await Future<void>.delayed(Duration(seconds: 1 << i));
        continue;
      }
      return res;
    }
    throw Exception('429 after $_max429Attempts GET attempts');
  }

  static Map<String, dynamic> _decodeJsonMap(http.Response res) {
    final dynamic j = jsonDecode(res.body);
    if (j is Map<String, dynamic>) return j;
    if (j is Map) return Map<String, dynamic>.from(j);
    throw FormatException('Expected JSON object, got ${j.runtimeType}');
  }

  static bool _isPendingStatus(String? status) {
    switch ((status ?? '').toLowerCase()) {
      case 'processing':
      case 'queued':
      case 'pending':
      case 'running':
      case 'in_progress':
      case 'started':
      case 'submitted':
        return true;
      default:
        return false;
    }
  }

  static bool _stillRunningMessage(String? message) {
    if (message == null || message.isEmpty) return false;
    final m = message.toLowerCase();
    return m.contains('try again later') ||
        m.contains('still processing') ||
        m.contains('being processed') ||
        m.contains('not yet complete') ||
        m.contains('please wait') ||
        m.contains('not ready');
  }

  /// DocStrange wraps each format as `{ content, metadata? }`.
  static Map<String, dynamic> _contentMapFromFormatNode(dynamic fmt) {
    if (fmt == null) return {};
    if (fmt is Map) {
      final m = Map<String, dynamic>.from(fmt);
      final content = m['content'];
      if (content is Map) return Map<String, dynamic>.from(content);
      if (content is String) {
        final t = content.trim();
        if (t.isEmpty) return {};
        try {
          final decoded = jsonDecode(t);
          if (decoded is Map) return Map<String, dynamic>.from(decoded);
        } catch (_) {
          return {'full_document_text': t};
        }
      }
      // Some responses omit the wrapper when content is the map itself.
      if (!m.containsKey('content') && m.isNotEmpty) {
        final copy = Map<String, dynamic>.from(m);
        copy.remove('metadata');
        return copy;
      }
    }
    if (fmt is String) {
      final t = fmt.trim();
      if (t.isEmpty) return {};
      try {
        final decoded = jsonDecode(t);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        return {'full_document_text': t};
      }
    }
    return {};
  }

  static Map<String, dynamic>? _metadataFromFormatNode(dynamic fmt) {
    if (fmt is! Map) return null;
    final meta = fmt['metadata'];
    if (meta is Map) return Map<String, dynamic>.from(meta);
    return null;
  }

  /// Parses completed DocStrange API response per OpenAPI `ExtractResponse`.
  @visibleForTesting
  static DocStrangeJsonResult parseExtractResponse(Map<String, dynamic> root) {
    final recordId = root['record_id']?.toString();
    final processingTime = root['processing_time'];
    double? pt;
    if (processingTime is num) pt = processingTime.toDouble();

    final result = root['result'];
    if (result is Map) {
      final jsonNode = result['json'];
      if (jsonNode != null) {
        return DocStrangeJsonResult(
          content: _contentMapFromFormatNode(jsonNode),
          metadata: _metadataFromFormatNode(jsonNode),
          recordId: recordId,
          processingTimeSeconds: pt,
        );
      }
    }

    // Legacy / alternate wrappers (pre-v1 or misaligned proxies).
    for (final key in ['json', 'data', 'extracted_data', 'extractedData']) {
      final node = root[key];
      if (node != null) {
        return DocStrangeJsonResult(
          content: _contentMapFromFormatNode(node),
          metadata: _metadataFromFormatNode(node),
          recordId: recordId,
          processingTimeSeconds: pt,
        );
      }
    }

    return DocStrangeJsonResult(
      content: _contentMapFromFormatNode(root),
      recordId: recordId,
      processingTimeSeconds: pt,
    );
  }

  static Future<DocStrangeJsonResult> _pollRecordJson(String recordId) async {
    final uri = Uri.parse('$_base$_resultsPath/$recordId').replace(
      queryParameters: const {'include_content': 'true'},
    );

    for (var round = 0; round < _maxPollRounds; round++) {
      final res = await _getResultsRetry(uri);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('GET results ${res.statusCode}: ${res.body}');
      }

      final map = _decodeJsonMap(res);
      final status = map['status']?.toString().trim().toLowerCase() ?? '';

      if (status == 'failed' || status == 'error') {
        throw Exception(map['message']?.toString() ?? 'DocStrange extraction failed');
      }

      if (status == 'completed' || map['success'] == true) {
        final parsed = parseExtractResponse(map);
        if (parsed.content.isNotEmpty) return parsed;
        throw Exception(
          map['message']?.toString() ?? 'completed but empty json content',
        );
      }

      if (_isPendingStatus(status)) {
        await Future<void>.delayed(_pollEvery);
        continue;
      }

      if (map['success'] == false) {
        final msg = map['message']?.toString();
        if (_stillRunningMessage(msg)) {
          await Future<void>.delayed(_pollEvery);
          continue;
        }
        throw Exception(msg ?? 'DocStrange extraction failed');
      }

      await Future<void>.delayed(_pollEvery);
    }

    throw TimeoutException(
      'DocStrange poll timeout after $_maxPollRounds rounds (record=$recordId)',
    );
  }

  static void _applyJsonExtractFields(Map<String, String> fields, String jsonOptions) {
    fields['output_format'] = 'json';
    fields['json_options'] = jsonOptions;
    // Do NOT send custom_instructions with JSON mode — breaks structured output.
    final includeMeta = CrmEnvConfig.nanonetsIncludeMetadata.trim();
    if (includeMeta.isNotEmpty) {
      fields['include_metadata'] = includeMeta;
    }
  }

  /// Sync JSON extraction — `POST /api/v1/extract/sync` (≤5 pages).
  static Future<DocStrangeJsonResult> extractJsonSync(
    XFile file, {
    required String jsonOptions,
  }) async {
    _needKey();
    final bytes = await file.readAsBytes();
    final apiKey = CrmEnvConfig.nanonetsApiKey;

    final res = await _postMultipartRetry(() {
      final req = http.MultipartRequest(
        'POST',
        Uri.parse('$_base$_syncPath'),
      );
      req.headers['Authorization'] = 'Bearer $apiKey';
      req.headers['Accept'] = 'application/json';

      final fields = <String, String>{};
      _applyJsonExtractFields(fields, jsonOptions);
      req.fields.addAll(fields);

      req.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: _fileName(file)),
      );
      return req;
    });

    // DocStrange returns 200 (completed) or 202 (accepted → poll).
    if (res.statusCode != 200 &&
        res.statusCode != 202 &&
        (res.statusCode < 200 || res.statusCode >= 300)) {
      throw Exception('DocStrange sync failed (${res.statusCode}): ${res.body}');
    }

    final map = _decodeJsonMap(res);
    if (map['success'] == false) {
      throw Exception(map['message']?.toString() ?? 'DocStrange rejected request');
    }

    final status = map['status']?.toString().trim().toLowerCase() ?? '';
    final recordId = map['record_id']?.toString();

    if (status == 'failed' || status == 'error') {
      throw Exception(map['message']?.toString() ?? 'DocStrange extraction failed');
    }

    if (_isPendingStatus(status)) {
      if (recordId != null && recordId.isNotEmpty) {
        return _pollRecordJson(recordId);
      }
      throw Exception(
        map['message']?.toString() ?? 'processing but no record_id',
      );
    }

    final parsed = parseExtractResponse(map);
    if (parsed.content.isNotEmpty) return parsed;

    if (recordId != null && recordId.isNotEmpty) {
      return _pollRecordJson(recordId);
    }

    throw Exception('DocStrange returned empty JSON content');
  }

  static const int _retryExtract = 3;
  static const Duration _retryDelay = Duration(milliseconds: 650);

  static Future<DocStrangeJsonResult> extractJsonSyncWithRetry(
    XFile file, {
    required String jsonOptions,
  }) async {
    Object? last;
    for (var attempt = 1; attempt <= _retryExtract; attempt++) {
      try {
        return await extractJsonSync(file, jsonOptions: jsonOptions);
      } catch (e, st) {
        last = e;
        if (kDebugMode) {
          debugPrint(
            'DocStrange JSON attempt $attempt/$_retryExtract: $e\n$st',
          );
        }
        if (attempt < _retryExtract) {
          await Future<void>.delayed(_retryDelay * attempt);
        }
      }
    }
    throw Exception(
      'DocStrange JSON failed after $_retryExtract tries: $last',
    );
  }
}
