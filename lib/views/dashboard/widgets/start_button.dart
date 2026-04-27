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
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;
  bool isStart = false;

  @override
  void initState() {
    super.initState();
    isStart = globalState.appState.runTime != null;
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
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void handleSwitchStart() {
    isStart = !isStart;
    debouncer.call(FunctionTag.updateStatus, () {
      globalState.appController.updateStatus(isStart);
    }, duration: commonDuration);
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
    final runTime = ref.watch(runTimeProvider);
    if (!state.isInit || !state.hasProfile) {
      return Container();
    }

    final isRunning = runTime != null;
    final colorScheme = Theme.of(context).colorScheme;
    final buttonColor = colorScheme.secondaryContainer.withValues(
      alpha: 0.85,
    );
    const shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
    );

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _pressController,
        builder: (_, __) => Transform.scale(
          scale: _scaleAnimation.value,
          child: AnimatedContainer(
            duration: commonDuration,
            curve: Curves.easeOutCubic,
            width: isRunning ? 112 : 56,
            height: 56,
            child: isRunning
                ? RawMaterialButton(
                    onPressed: handleSwitchStart,
                    fillColor: buttonColor,
                    elevation: 0,
                    hoverElevation: 0,
                    focusElevation: 0,
                    highlightElevation: 0,
                    shape: shape,
                    clipBehavior: Clip.antiAlias,
                    constraints: const BoxConstraints.expand(
                      width: 112,
                      height: 56,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.pause_rounded,
                            size: 26,
                            color: colorScheme.onSecondaryContainer,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                utils.getTimeText(runTime),
                                maxLines: 1,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSecondaryContainer,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : FloatingActionButton(
                    heroTag: null,
                    tooltip: appLocalizations.start,
                    onPressed: handleSwitchStart,
                    backgroundColor: buttonColor,
                    foregroundColor: colorScheme.onSecondaryContainer,
                    elevation: 0,
                    shape: shape,
                    child: Icon(
                      Icons.play_arrow_rounded,
                      size: 26,
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
