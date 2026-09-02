import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shrinks slightly under the finger with a light haptic tick, then springs
/// back — the tactile feedback every tappable surface in the app was missing.
class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double downScale;
  const PressableScale({super.key, required this.child, this.onTap, this.downScale = 0.93});

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null
          ? null
          : (_) {
              HapticFeedback.selectionClick();
              _c.forward();
            },
      onTapUp: widget.onTap == null
          ? null
          : (_) {
              _c.reverse();
              widget.onTap!();
            },
      onTapCancel: widget.onTap == null ? null : () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) => Transform.scale(scale: 1 - _c.value * (1 - widget.downScale), child: child),
        child: widget.child,
      ),
    );
  }
}

/// A bouncy scale+fade entrance for anything that should feel like it "pops"
/// onto the screen rather than just appearing. Optionally delayed so a list
/// of these can cascade in one after another.
class PopIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  const PopIn({super.key, required this.child, this.delay = Duration.zero});

  @override
  State<PopIn> createState() => _PopInState();
}

class _PopInState extends State<PopIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  late final Animation<double> _scale = CurvedAnimation(parent: _c, curve: Curves.elasticOut);
  late final Animation<double> _fade = CurvedAnimation(parent: _c, curve: const Interval(0, 0.5, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Opacity(
        opacity: _fade.value.clamp(0, 1),
        child: Transform.scale(scale: 0.7 + 0.3 * _scale.value, child: child),
      ),
      child: widget.child,
    );
  }
}

/// A gentle fade-up entrance — used for chat bubbles so new narration and
/// player lines drift in instead of popping into existence instantly.
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  const FadeSlideIn({super.key, required this.child});

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 280))..forward();
  late final Animation<double> _curve = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) => Opacity(
        opacity: _curve.value,
        child: Transform.translate(offset: Offset(0, (1 - _curve.value) * 14), child: child),
      ),
      child: widget.child,
    );
  }
}

/// Three bouncing dots — replaces static "thinking..." copy with something
/// that actually feels alive while the on-device model is generating.
class TypingDots extends StatefulWidget {
  final Color color;
  const TypingDots({super.key, this.color = Colors.white70});

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final t = ((_c.value - i * 0.2) % 1.0 + 1.0) % 1.0;
            final bounce = sin(t * pi).clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Transform.translate(
                offset: Offset(0, -4 * bounce),
                child: Container(width: 6, height: 6, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle)),
              ),
            );
          }),
        );
      },
    );
  }
}

/// A springy pop-in for dice-roll / check / attack badges — with a stronger
/// bounce and a haptic thump on critical hits and natural 20s.
class RollBadgePop extends StatefulWidget {
  final Widget child;
  final bool critical;
  const RollBadgePop({super.key, required this.child, this.critical = false});

  @override
  State<RollBadgePop> createState() => _RollBadgePopState();
}

class _RollBadgePopState extends State<RollBadgePop> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
  late final Animation<double> _bounce = CurvedAnimation(parent: _c, curve: Curves.elasticOut);

  @override
  void initState() {
    super.initState();
    if (widget.critical) HapticFeedback.mediumImpact();
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bounce,
      builder: (context, child) => Transform.scale(scale: _bounce.value, child: child),
      child: widget.child,
    );
  }
}

/// A slow breathing scale+glow loop — used for the player marker on the map
/// so the dungeon feels alive rather than static.
class Pulse extends StatefulWidget {
  final Widget child;
  final Duration duration;
  const Pulse({super.key, required this.child, this.duration = const Duration(milliseconds: 1100)});

  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration)..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_c.value);
        return Transform.scale(scale: 1 + 0.1 * t, child: Opacity(opacity: 0.85 + 0.15 * t, child: child));
      },
      child: widget.child,
    );
  }
}
