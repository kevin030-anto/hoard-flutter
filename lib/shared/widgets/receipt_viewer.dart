import 'dart:io';

import 'package:flutter/material.dart';

/// Full-screen, swipeable viewer for a transaction's receipt images.
Future<void> showReceiptViewer(BuildContext context, List<String> paths) {
  return showDialog(
    context: context,
    barrierColor: Colors.black87,
    builder: (_) => _ReceiptViewer(paths: paths),
  );
}

class _ReceiptViewer extends StatelessWidget {
  final List<String> paths;
  const _ReceiptViewer({required this.paths});

  @override
  Widget build(BuildContext context) {
    final controller = PageController();
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      child: Stack(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.75,
            child: PageView(
              controller: controller,
              children: [
                for (final p in paths)
                  InteractiveViewer(
                    child: Center(
                      child: File(p).existsSync()
                          ? Image.file(File(p))
                          : const Icon(Icons.broken_image_outlined,
                              color: Colors.white54, size: 64),
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const CircleAvatar(
                backgroundColor: Colors.black54,
                child: Icon(Icons.close, color: Colors.white),
              ),
            ),
          ),
          if (paths.length > 1)
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('${paths.length} images • swipe',
                      style: const TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
