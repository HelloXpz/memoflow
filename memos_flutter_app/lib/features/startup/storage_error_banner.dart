import 'package:flutter/material.dart';

import '../../core/storage_read.dart';

class StorageErrorBanner extends StatelessWidget {
  const StorageErrorBanner({
    super.key,
    required this.error,
    required this.onRetry,
    required this.onExit,
  });

  final StorageLoadError? error;
  final VoidCallback onRetry;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final bg = Colors.orange.shade700;
    return SafeArea(
      bottom: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              blurRadius: 12,
              offset: const Offset(0, 6),
              color: Colors.black.withValues(alpha: 0.2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '存储读取失败，部分功能受限。',
                style: const TextStyle(color: Colors.white, fontSize: 12.5),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              child: const Text(
                '重试',
                style: TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(width: 4),
            TextButton(
              onPressed: onExit,
              child: const Text(
                '退出',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
