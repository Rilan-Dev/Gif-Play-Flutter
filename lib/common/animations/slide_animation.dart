import 'package:flutter/material.dart';

/// Direction of the slide animation.
enum SlideDirection {
  /// Slide horizontally (left/right).
  horizontal,
  
  /// Slide vertically (up/down).
  vertical,
}

/// A controller for slide animations.
///
/// This class provides a controller for slide animations, with support
/// for different directions and customization options.
///
/// Example usage:
/// ```dart
/// final slideController = SlideAnimationController(
///   vsync: this,
///   direction: SlideDirection.horizontal,
/// );
///
/// // Use the animation in your widget
/// return SlideTransition(
///   position: slideController.animation,
///   child: yourWidget,
/// );
/// ```
class SlideAnimationController {
  /// The animation controller.
  final AnimationController controller;
  
  /// The direction of the slide.
  final SlideDirection direction;
  
  /// Whether the slide is forward (true) or backward (false).
  bool _isForward = true;
  
  /// The animation for the slide.
  late Animation<Offset> _animation;
  
  /// Creates a slide animation controller.
  SlideAnimationController({
    required TickerProvider vsync,
    this.direction = SlideDirection.horizontal,
    Duration duration = const Duration(milliseconds: 300),
  }) : controller = AnimationController(
         vsync: vsync,
         duration: duration,
       ) {
    _updateAnimation();
  }
  
  /// The animation for the slide.
  Animation<Offset> get animation => _animation;
  
  /// Whether the slide is forward (true) or backward (false).
  bool get isForward => _isForward;
  
  /// Sets the direction of the slide.
  set isForward(bool value) {
    if (_isForward != value) {
      _isForward = value;
      _updateAnimation();
    }
  }
  
  /// Updates the animation based on the current direction and forward/backward state.
  void _updateAnimation() {
    final begin = const Offset(0, 0);
    final end = _isForward
        ? (direction == SlideDirection.horizontal ? const Offset(-1.0, 0) : const Offset(0, -1.0))
        : (direction == SlideDirection.horizontal ? const Offset(1.0, 0) : const Offset(0, 1.0));
    
    _animation = Tween<Offset>(
      begin: begin,
      end: end,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOut,
    ));
  }
  
  /// Starts the animation.
  Future<void> forward() async {
    controller.reset();
    return controller.forward();
  }
  
  /// Reverses the animation.
  Future<void> reverse() async {
    return controller.reverse();
  }
  
  /// Disposes the controller.
  void dispose() {
    controller.dispose();
  }
}

/// A widget that applies a slide animation to its child.
///
/// This widget is a convenience wrapper around SlideTransition that
/// uses a SlideAnimationController.
///
/// Example usage:
/// ```dart
/// SlideAnimatedWidget(
///   controller: slideController,
///   child: yourWidget,
/// )
/// ```
class SlideAnimatedWidget extends StatelessWidget {
  /// The controller for the animation.
  final SlideAnimationController controller;
  
  /// The child widget to animate.
  final Widget child;

  const SlideAnimatedWidget({
    Key? key,
    required this.controller,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller.animation,
      builder: (context, child) {
        return Transform.translate(
          offset: controller.animation.value * MediaQuery.of(context).size.width,
          child: child,
        );
      },
      child: child,
    );
  }
}

