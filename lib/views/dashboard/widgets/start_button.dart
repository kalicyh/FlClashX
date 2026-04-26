import 'package:flclashx/common/common.dart';
import 'package:flclashx/enum/enum.dart';
import 'package:flclashx/providers/providers.dart';
import 'package:flclashx/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StartButton extends ConsumerStatefulWidget {
  const StartButton({super.key});

  @override
  ConsumerState<StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends ConsumerState<StartButton>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _pressController;
  late Animation<double> _animation;
  late Animation<double> _scaleAnimation;
  bool isStart = false;

  @override
  void initState() {
    super.initState();
    isStart = globalState.appState.runTime != null;
    _controller = AnimationController(
      vsync: this,
      value: isStart ? 1 : 0,
      duration: const Duration(milliseconds: 300),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _pressController, curve: Curves.easeOut));

    ref.listenManual(runTimeProvider.select((state) => state != null), (
      prev,
      next,
    ) {
      if (next != isStart) {
        isStart = next;
        updateController();
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _pressController.dispose();
    super.dispose();
  }

  void handleSwitchStart() {
    isStart = !isStart;
    updateController();
    debouncer.call(FunctionTag.updateStatus, () {
      globalState.appController.updateStatus(isStart);
    }, duration: commonDuration);
  }

  void updateController() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isStart) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  void _onTapDown(TapDownDetails details) {
    _pressController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _pressController.reverse();
  }

  void _onTapCancel() {
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(startButtonSelectorStateProvider);
    if (!state.isInit || !state.hasProfile) {
      return Container();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final activeColor = Colors.green.shade600.withValues(alpha: 0.9);
    final inactiveColor = colorScheme.secondaryContainer.withValues(
      alpha: 0.85,
    );

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: Listenable.merge([_controller, _pressController]),
        builder: (_, __) => Transform.scale(
          scale: _scaleAnimation.value,
          child: FloatingActionButton(
            heroTag: null,
            tooltip: isStart ? appLocalizations.stop : appLocalizations.start,
            onPressed: handleSwitchStart,
            backgroundColor: isStart ? activeColor : inactiveColor,
            foregroundColor:
                isStart ? Colors.white : colorScheme.onSecondaryContainer,
            elevation: isStart ? 4 : 0,
            child: AnimatedIcon(
              icon: AnimatedIcons.play_pause,
              progress: _animation,
              size: 28,
              color: isStart ? Colors.white : colorScheme.onSecondaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}
