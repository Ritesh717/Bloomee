import 'package:flutter/material.dart';

/// Gesture handlers for the music player
/// Provides swipe, pinch, and tap gesture recognition

class PlayerGestures extends StatefulWidget {
  final Widget child;
  final VoidCallback? onSwipeLeft;
  final VoidCallback? onSwipeRight;
  final VoidCallback? onSwipeDown;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;
  final Function(double scale)? onPinchZoom;

  const PlayerGestures({
    super.key,
    required this.child,
    this.onSwipeLeft,
    this.onSwipeRight,
    this.onSwipeDown,
    this.onDoubleTap,
    this.onLongPress,
    this.onPinchZoom,
  });

  @override
  State<PlayerGestures> createState() => _PlayerGesturesState();
}

class _PlayerGesturesState extends State<PlayerGestures> {
  double _initialScale = 1.0;
  double _currentScale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        // Swipe left/right detection
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity! < -500) {
            // Swipe left (next track)
            widget.onSwipeLeft?.call();
          } else if (details.primaryVelocity! > 500) {
            // Swipe right (previous track)
            widget.onSwipeRight?.call();
          }
        }
      },
      onVerticalDragEnd: (details) {
        // Swipe down detection (minimize player)
        if (details.primaryVelocity != null && details.primaryVelocity! > 500) {
          widget.onSwipeDown?.call();
        }
      },
      onDoubleTap: widget.onDoubleTap,
      onLongPress: widget.onLongPress,
      // Removed scale gestures to avoid conflict with drag gestures
      child: widget.child,
    );
  }
}

/// Swipe indicator widget to show visual feedback
class SwipeIndicator extends StatelessWidget {
  final String direction;
  final bool show;

  const SwipeIndicator({
    super.key,
    required this.direction,
    this.show = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!show) return const SizedBox.shrink();

    IconData icon;
    switch (direction) {
      case 'left':
        icon = Icons.skip_next;
        break;
      case 'right':
        icon = Icons.skip_previous;
        break;
      case 'down':
        icon = Icons.keyboard_arrow_down;
        break;
      default:
        icon = Icons.touch_app;
    }

    return AnimatedOpacity(
      opacity: show ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 48,
        ),
      ),
    );
  }
}
