import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Secrets and DocStrange tuning for CRM business-card OCR.
///
/// Docs: https://docstrange.nanonets.com/docs/examples
/// Priority: `--dart-define` → bundled `.env` → built-in defaults.
abstract final class CrmEnvConfig {
  static String _read(String key, {String defaultValue = ''}) {
    final fromDefine =
        String.fromEnvironment(key, defaultValue: defaultValue).trim();
    if (fromDefine.isNotEmpty) return fromDefine;

    final fromDotenv = dotenv.maybeGet(key)?.trim();
    if (fromDotenv != null && fromDotenv.isNotEmpty) return fromDotenv;

    return defaultValue;
  }

  static String get nanonetsApiKey {
    final primary = _read('NANONETS_API_KEY');
    if (primary.isNotEmpty) return primary;
    return _read('NANONETS_OCR_KEY');
  }

  /// Override DocStrange `json_options` (field list, schema JSON, or `hierarchy_output`).
  static String get nanonetsJsonOptionsOverride => _read('NANONETS_JSON_OPTIONS');

  /// DocStrange JSON schema for business-card field extraction (`output_format=json`).
  ///
  /// See: JSON with Custom Schema — docstrange.nanonets.com/docs/examples
  static const String defaultBusinessCardJsonSchema = '''
{
  "type": "object",
  "properties": {
    "name": {
      "type": "string",
      "description": "Full name of the person on the business card"
    },
    "company": {
      "type": "string",
      "description": "Company or organization name printed on the card"
    },
    "location": {
      "type": "string",
      "description": "Company office address, city, or location printed on the card"
    },
    "designation": {
      "type": "string",
      "description": "Job title, role, or designation on the card"
    },
    "mobile": {
      "type": "string",
      "description": "Primary phone or mobile number"
    },
    "email": {
      "type": "string",
      "description": "Email address on the card"
    }
  }
}''';

  /// Field list fallback if schema is disabled via env.
  static const String defaultBusinessCardFieldList =
      '["name","company","location","designation","mobile","email"]';

  /// Sent as multipart `json_options` unless [nanonetsJsonOptionsOverride] is set.
  static String get businessCardJsonOptions {
    final override = nanonetsJsonOptionsOverride;
    if (override.isNotEmpty) return override;
    return defaultBusinessCardJsonSchema;
  }

  /// Optional: `confidence_score`, `bounding_boxes`, comma-separated.
  static String get nanonetsIncludeMetadata => _read('NANONETS_INCLUDE_METADATA');

  static bool get isNanonetsConfigured => nanonetsApiKey.isNotEmpty;

  static String get nanonetsSetupHint =>
      'Add NANONETS_API_KEY to .env or run: '
      'flutter run --dart-define-from-file=.env';
}
