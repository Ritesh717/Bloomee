import 'package:flutter/material.dart';

/// Reusable animations for the music player UI
/// Provides smooth transitions and visual effects

class PlayerAnimations {
  // Animation durations
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);

  // Animation curves
  static const Curve defaultCurve = Curves.easeOutCubic;
  static const Curve bounceCurve = Curves.elasticOut;
  static const Curve smoothCurve = Curves.easeInOutCubic;

  /// Fade transition animation
  static Widget fadeTransition({
    required Widget child,
    required Animation<double> animation,
    Curve curve = defaultCurve,
  }) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: curve),
      child: child,
    );
  }

  /// Slide transition from bottom
  static Widget slideFromBottom({
    required Widget child,
    required Animation<double> animation,
    Curve curve = defaultCurve,
  }) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: curve)),
      child: child,
    );
  }

  /// Slide transition from right
  static Widget slideFromRight({
    required Widget child,
    required Animation<double> animation,
    Curve curve = defaultCurve,
  }) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: curve)),
      child: child,
    );
  }

  /// Scale animation with fade
  static Widget scaleWithFade({
    required Widget child,
    required Animation<double> animation,
    Curve curve = defaultCurve,
    double initialScale = 0.8,
  }) {
    final curvedAnimation = CurvedAnimation(parent: animation, curve: curve);
    return FadeTransition(
      opacity: curvedAnimation,
      child: ScaleTransition(
        scale: Tween<double>(begin: initialScale, end: 1.0)
            .animate(curvedAnimation),
        child: child,
      ),
    );
  }

  /// Rotation animation for vinyl effect
  static Widget rotateVinyl({
    required Widget child,
    required Animation<double> animation,
    bool isPlaying = false,
  }) {
    return RotationTransition(
      turns: animation,
      child: child,
    );
  }

  /// Shimmer loading effect
  static Widget shimmerLoading({
    required Widget child,
    bool isLoading = true,
  }) {
    if (!isLoading) return child;

    return ShaderMask(
      shaderCallback: (bounds) {
        return LinearGradient(
          colors: const [
            Colors.transparent,
            Colors.white24,
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(bounds);
      },
      child: child,
    );
  }

  /// Pulse animation for active states
  static Widget pulse({
    required Widget child,
    required Animation<double> animation,
    double minScale = 0.95,
    double maxScale = 1.05,
  }) {
    return ScaleTransition(
      scale: Tween<double>(begin: minScale, end: maxScale).animate(
        CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOut,
        ),
      ),
      child: child,
    );
  }

  /// Bounce animation for button press
  static Widget bounceOnTap({
    required Widget child,
    required VoidCallback onTap,
    double scale = 0.95,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.0, end: 1.0),
      duration: fast,
      curve: bounceCurve,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: child,
        );
      },
      child: GestureDetector(
        onTapDown: (_) {},
        onTapUp: (_) => onTap(),
        onTapCancel: () {},
        child: child,
      ),
    );
  }

  /// Glassmorphism effect
  static Widget glassmorphism({
    required Widget child,
    double blur = 10.0,
    double opacity = 0.1,
    BorderRadius? borderRadius,
  }) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(opacity),
            borderRadius: borderRadius ?? BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Animation controller helper for player
class PlayerAnimationController {
  final TickerProvider vsync;
  late AnimationController _controller;

  PlayerAnimationController({required this.vsync}) {
    _controller = AnimationController(
      vsync: vsync,
      duration: PlayerAnimations.normal,
    );
  }

  AnimationController get controller => _controller;

  void forward() => _controller.forward();
  void reverse() => _controller.reverse();
  void reset() => _controller.reset();
  void repeat() => _controller.repeat();
  void stop() => _controller.stop();

  void dispose() {
    _controller.dispose();
  }
}
