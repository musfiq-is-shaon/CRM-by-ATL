import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/config/crm_env_config.dart';
import '../../../core/services/business_card_extraction_service.dart';
import '../../../core/utils/business_card_ocr_canonical.dart';
import 'business_card_multi_capture_page.dart';

/// Multi-page business card scan + batched DocStrange OCR.
class BusinessCardScanFlow {
  BusinessCardScanFlow._();

  static final ImagePicker _picker = ImagePicker();

  /// Max card sides / images per scan (DocStrange sync supports small multi-page docs).
  static const int maxPages = 5;

  /// OCR requests processed in parallel per batch to balance speed and rate limits.
  static const int ocrBatchSize = 2;

  static Future<CanonicalBusinessCardContact?> pickAndExtract(
    BuildContext context, {
    required ImageSource source,
  }) async {
    if (!CrmEnvConfig.isNanonetsConfigured) {
      _showError(context, CrmEnvConfig.nanonetsSetupHint);
      return null;
    }

    final List<XFile> pages;
    if (source == ImageSource.gallery) {
      final images = await _picker.pickMultiImage(
        imageQuality: 92,
        limit: maxPages,
      );
      if (images.isEmpty || !context.mounted) return null;
      pages = images;
    } else {
      final captured = await Navigator.of(context).push<List<XFile>>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const BusinessCardMultiCapturePage(maxPages: maxPages),
        ),
      );
      if (captured == null || captured.isEmpty || !context.mounted) {
        return null;
      }
      pages = captured;
    }

    if (!context.mounted) return null;
    return _extractPagesWithDialog(context, pages);
  }

  static Future<CanonicalBusinessCardContact?> _extractPagesWithDialog(
    BuildContext context,
    List<XFile> pages,
  ) async {
    final progress = ValueNotifier<String>(
      'Reading page 1 of ${pages.length}…',
    );

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: ValueListenableBuilder<String>(
            valueListenable: progress,
            builder: (_, message, _) => Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 20),
                Expanded(child: Text(message)),
              ],
            ),
          ),
        ),
      ),
    );

    var lastCompleted = 0;
    try {
      final raws = await BusinessCardExtractionService.extractBusinessCardJsonBatch(
        pages,
        batchSize: ocrBatchSize,
        onProgress: (completed, total) {
          lastCompleted = completed;
          final batchNum = ((completed - 1) ~/ ocrBatchSize) + 1;
          final batchTotal = (total / ocrBatchSize).ceil();
          progress.value =
              'Reading page $completed of $total (batch $batchNum/$batchTotal)…';
        },
      );

      final canonical = mergeBusinessCardPages(
        raws.map(canonicalizeBusinessCardOcr).toList(),
      );

      if (!canonical.hasAnyField) {
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          _showError(
            context,
            pages.length > 1
                ? 'Could not find contact details on these pages. Try clearer photos.'
                : 'Could not find contact details on this card. Try a clearer photo.',
          );
        }
        return null;
      }

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      return canonical;
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showError(
          context,
          lastCompleted > 0
              ? 'Scan failed after page $lastCompleted: $e'
              : 'Scan failed: $e',
        );
      }
      return null;
    } finally {
      progress.dispose();
    }
  }

  static Future<void> showSourceSheet(
    BuildContext context, {
    required void Function(ImageSource source) onSource,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                'Capture all card sides (up to $maxPages pages)',
                style: Theme.of(ctx).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photos'),
              subtitle: const Text(
                'Camera reopens for each page until you tap Done',
              ),
              onTap: () {
                Navigator.pop(ctx);
                onSource(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              subtitle: Text('Select up to $maxPages images at once'),
              onTap: () {
                Navigator.pop(ctx);
                onSource(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  static void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
