import 'package:flclashx/common/common.dart';
import 'package:flclashx/enum/enum.dart';
import 'package:flclashx/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfileLoadingOverlay extends ConsumerWidget {
  const ProfileLoadingOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(loadingProvider(LoadingTag.profiles));
    final colorScheme = context.colorScheme;
    return Positioned(
      top: MediaQuery.paddingOf(context).top + kToolbarHeight + 12,
      right: 16,
      child: IgnorePointer(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1).animate(animation),
              child: child,
            ),
          ),
          child: isLoading
              ? Container(
                  key: const ValueKey('profile-loading-overlay'),
                  height: 32,
                  padding: const EdgeInsets.only(left: 11, right: 14),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        appLocalizations.loading,
                        style: context.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 9),
                      SizedBox.square(
                        dimension: 21,
                        child: CommonCircleLoading(
                          color: colorScheme.primaryContainer,
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox(
                  key: ValueKey('profile-loading-overlay-empty'),
                ),
        ),
      ),
    );
  }
}

class CommonCircleLoading extends StatefulWidget {
  const CommonCircleLoading({super.key, this.color});

  final Color? color;

  @override
  State<CommonCircleLoading> createState() => _CommonCircleLoadingState();
}

class _CommonCircleLoadingState extends State<CommonCircleLoading>
    with TickerProviderStateMixin {
  late final AnimationController _rotateController;
  late final AnimationController _pointsController;
  late final Animation<double> _pointsAnimation;

  @override
  void initState() {
    super.initState();
    _rotateController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _pointsController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);

    _pointsAnimation = Tween<double>(begin: 3, end: 9).animate(
      CurvedAnimation(parent: _pointsController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _rotateController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    return RepaintBoundary(
      child: RotationTransition(
        turns: _rotateController,
        child: SizedBox.expand(
          child: AnimatedBuilder(
            animation: _pointsController,
            builder: (context, child) => CustomPaint(
              painter: _StarPainter(
                points: _pointsAnimation.value,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StarPainter extends CustomPainter {
  _StarPainter({
    required this.points,
    required this.color,
  }) : _paint = Paint()..color = color;

  final double points;
  final Color color;
  final Paint _paint;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final starBorder = StarBorder(
      points: points,
      innerRadiusRatio: 0.8,
      pointRounding: 0.5,
      valleyRounding: 0.1,
      squash: 0.5,
    );

    canvas.drawPath(starBorder.getOuterPath(rect), _paint);
  }

  @override
  bool shouldRepaint(covariant _StarPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.color != color;
}
