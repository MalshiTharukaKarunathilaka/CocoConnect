import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Why: CDO must open estate NIC / land-title uploads, not only see the file name.
Future<void> showFertDocViewer(
  BuildContext context, {
  required String title,
  required String fileName,
  String path = '',
  List<int>? bytes,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) {
      Widget preview;
      if (bytes != null && bytes.isNotEmpty) {
        preview = InteractiveViewer(
          child: Image.memory(
            Uint8List.fromList(bytes),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _fallback(fileName),
          ),
        );
      } else if (!kIsWeb && path.isNotEmpty && File(path).existsSync()) {
        preview = InteractiveViewer(
          child: Image.file(
            File(path),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _fallback(fileName),
          ),
        );
      } else {
        preview = _fallback(fileName);
      }

      return Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: preview,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Text(
                  fileName.isEmpty ? 'Uploaded document' : fileName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _fallback(String fileName) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.greenSoft,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.green.withValues(alpha: 0.35)),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.badge_outlined, size: 64, color: AppColors.green),
        const SizedBox(height: 12),
        const Text(
          'Document on file',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const SizedBox(height: 6),
        Text(
          fileName.isEmpty
              ? 'Estate owner uploaded this document.'
              : fileName,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted, fontSize: 13),
        ),
        const SizedBox(height: 10),
        const Text(
          'Preview is shown for demo uploads when the original photo bytes are not stored.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11.5, color: AppColors.muted),
        ),
      ],
    ),
  );
}
