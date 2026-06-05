import 'package:flutter/material.dart';

/// WhatsApp-style: tap to open full-screen viewer with dismiss
void showPhotoViewer(BuildContext context, String url) {
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.zero,
      child: GestureDetector(
        onTap: () => Navigator.pop(ctx),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.broken_image_rounded,
                    color: Colors.white54,
                    size: 64,
                  ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.paddingOf(ctx).top + 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Instagram-style: hold to preview, release to dismiss
class HoldToPreview extends StatefulWidget {
  const HoldToPreview({
    super.key,
    required this.imageUrl,
    required this.child,
  });

  final String imageUrl;
  final Widget child;

  @override
  State<HoldToPreview> createState() => _HoldToPreviewState();
}

class _HoldToPreviewState extends State<HoldToPreview> {
  OverlayEntry? _overlay;

  void _showPreview() {
    _overlay = OverlayEntry(
      builder: (_) => Material(
        color: Colors.black87,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                widget.imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.broken_image_rounded,
                  color: Colors.white54,
                  size: 64,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlay!);
  }

  void _hidePreview() {
    _overlay?.remove();
    _overlay = null;
  }

  @override
  void dispose() {
    _hidePreview();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) => _showPreview(),
      onLongPressEnd: (_) => _hidePreview(),
      onLongPressCancel: _hidePreview,
      child: widget.child,
    );
  }
}

/// Tappable photo that opens WhatsApp-style viewer. Use everywhere except profile.
class TappablePhoto extends StatelessWidget {
  const TappablePhoto({
    super.key,
    required this.url,
    required this.child,
  });

  final String url;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showPhotoViewer(context, url),
      child: child,
    );
  }
}
