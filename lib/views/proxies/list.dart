import 'dart:math';

import 'package:flclashx/common/common.dart';
import 'package:flclashx/enum/enum.dart';
import 'package:flclashx/models/models.dart';
import 'package:flclashx/providers/config.dart';
import 'package:flclashx/providers/state.dart';
import 'package:flclashx/state.dart';
import 'package:flclashx/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'card.dart';
import 'common.dart';

class ProxiesListView extends StatefulWidget {
  const ProxiesListView({super.key});

  @override
  State<ProxiesListView> createState() => _ProxiesListViewState();
}

class _ProxiesListViewState extends State<ProxiesListView> {
  final _controller = ScrollController();
  final _headerStateNotifier = ValueNotifier<ProxiesListHeaderSelectorState?>(
    null,
  );
  List<double> _headerOffset = [];
  double _containerHeight = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_adjustHeader);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _adjustHeader();
    });
  }

  @override
  void dispose() {
    _headerStateNotifier.dispose();
    _controller
      ..removeListener(_adjustHeader)
      ..dispose();
    super.dispose();
  }

  ProxiesListHeaderSelectorState _getHeaderState(double offset) {
    final index = _headerOffset.findInterval(offset);
    var headerOffset = 0.0;
    if (index + 1 <= _headerOffset.length - 1) {
      final endOffset = _headerOffset[index + 1];
      final startOffset = endOffset - listHeaderHeight - 8;
      if (offset > startOffset && offset < endOffset) {
        headerOffset = offset - startOffset;
      }
    }
    return ProxiesListHeaderSelectorState(
      offset: max(headerOffset, 0),
      currentIndex: index,
    );
  }

  void _adjustHeader() {
    _headerStateNotifier.value = _getHeaderState(
      !_controller.hasClients ? 0 : _controller.offset,
    );
  }

  double _getListItemHeight(Type type, ProxyCardType proxyCardType) =>
      switch (type) {
        const (SizedBox) => 8,
        const (ListHeader) => listHeaderHeight,
        Type() => getItemHeight(proxyCardType),
      };

  void _handleChange(Set<String> currentUnfoldSet, String groupName) {
    _autoScrollToGroup(groupName);
    final nextUnfoldSet = Set<String>.from(currentUnfoldSet);
    if (nextUnfoldSet.contains(groupName)) {
      nextUnfoldSet.remove(groupName);
    } else {
      nextUnfoldSet.add(groupName);
    }
    globalState.appController.updateCurrentUnfoldSet(nextUnfoldSet);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _adjustHeader();
    });
  }

  List<double> _getItemHeightList(
    List<Widget> items,
    ProxyCardType proxyCardType,
  ) {
    final itemHeightList = <double>[];
    final headerOffset = <double>[];
    var currentHeight = 0.0;
    for (final item in items) {
      if (item.runtimeType == ListHeader) {
        headerOffset.add(currentHeight);
      }
      final itemHeight = _getListItemHeight(item.runtimeType, proxyCardType);
      itemHeightList.add(itemHeight);
      currentHeight += itemHeight;
    }
    _headerOffset = headerOffset;
    return itemHeightList;
  }

  List<Widget> _buildItems(
    WidgetRef ref, {
    required List<String> groupNames,
    required int columns,
    required Set<String> currentUnfoldSet,
    required ProxyCardType cardType,
    required String query,
  }) {
    final items = <Widget>[];
    for (final groupName in groupNames) {
      final group = ref.watch(
        currentGroupsStateProvider.select(
          (state) => state.value.getGroup(groupName),
        ),
      );
      if (group == null) {
        continue;
      }
      final isExpand = currentUnfoldSet.contains(groupName);
      items.addAll([
        ListHeader(
          onScrollToSelected: _scrollToGroupSelected,
          isExpand: isExpand,
          group: group,
          onChange: (value) {
            _handleChange(currentUnfoldSet, value);
          },
        ),
        const SizedBox(height: 8),
      ]);
      if (!isExpand) {
        continue;
      }

      final proxies = globalState.appController.getSortProxies(
        group.all
            .where((item) => item.name.toLowerCase().contains(query))
            .toList(),
        group.testUrl,
      );
      final rows = proxies.chunks(columns).map<Widget>((proxies) {
        final children = proxies
            .map<Widget>(
              (proxy) => Flexible(
                child: SizedBox(
                  height: getItemHeight(cardType),
                  child: RepaintBoundary(
                    child: ProxyCard(
                      testUrl: group.testUrl,
                      type: cardType,
                      groupType: group.type,
                      key: ValueKey('$groupName.${proxy.name}'),
                      proxy: proxy,
                      groupName: groupName,
                    ),
                  ),
                ),
              ),
            )
            .fill(
              columns,
              filler: (_) => const Flexible(child: SizedBox()),
            )
            .separated(const SizedBox(width: 8));

        return Row(children: children.toList());
      }).separated(
        SizedBox(
          height: cardType == ProxyCardType.oneline ? 4 : 8,
        ),
      );
      items.addAll([...rows, const SizedBox(height: 8)]);
    }
    return items;
  }

  Widget _buildHeader({
    required Group group,
    required Set<String> currentUnfoldSet,
  }) {
    final groupName = group.name;
    final isExpand = currentUnfoldSet.contains(groupName);
    return SizedBox(
      height: listHeaderHeight,
      child: ListHeader(
        enterAnimated: false,
        onScrollToSelected: _scrollToGroupSelected,
        key: Key(groupName),
        isExpand: isExpand,
        group: group,
        onChange: (value) {
          _handleChange(currentUnfoldSet, value);
        },
      ),
    );
  }

  double _getGroupOffset(String groupName) {
    if (!_controller.hasClients || _controller.position.maxScrollExtent == 0) {
      return 0;
    }
    final currentGroups = globalState.appController.getCurrentGroups();
    final findIndex = currentGroups.indexWhere(
      (item) => item.name == groupName,
    );
    final index = findIndex != -1 ? findIndex : 0;
    if (index >= _headerOffset.length) {
      return 0;
    }
    return _headerOffset[index];
  }

  void _scrollToMakeVisibleWithPadding({
    required double containerHeight,
    required double pixels,
    required double start,
    required double end,
    double padding = 24,
  }) {
    final visibleStart = pixels;
    final visibleEnd = pixels + containerHeight;

    if (start >= visibleStart && end <= visibleEnd) {
      return;
    }

    double targetScrollOffset;
    if (end <= visibleStart) {
      targetScrollOffset = start;
    } else if (start >= visibleEnd) {
      targetScrollOffset = end - containerHeight + padding;
    } else {
      final visibleTopPart = end - visibleStart;
      final visibleBottomPart = visibleEnd - start;
      targetScrollOffset = visibleTopPart.abs() >= visibleBottomPart.abs()
          ? end - containerHeight + padding
          : start;
    }

    _controller.jumpTo(
      targetScrollOffset.clamp(
        _controller.position.minScrollExtent,
        _controller.position.maxScrollExtent,
      ),
    );
  }

  void _autoScrollToGroup(String groupName) {
    if (!_controller.hasClients) {
      return;
    }
    final pixels = _controller.position.pixels;
    final offset = _getGroupOffset(groupName);
    _scrollToMakeVisibleWithPadding(
      containerHeight: _containerHeight,
      pixels: pixels,
      start: offset,
      end: offset + listHeaderHeight,
    );
  }

  void _scrollToGroupSelected(String groupName) {
    final currentInitOffset = _getGroupOffset(groupName);
    final currentGroups = globalState.appController.getCurrentGroups();
    final group = currentGroups.getGroup(groupName);
    final query = globalState.appState.proxiesQuery.toLowerCase();
    final proxies = group == null
        ? <Proxy>[]
        : globalState.appController.getSortProxies(
            group.all
                .where((item) => item.name.toLowerCase().contains(query))
                .toList(),
            group.testUrl,
          );
    _jumpTo(
      currentInitOffset +
          8 +
          getScrollToSelectedOffset(
            groupName: groupName,
            proxies: proxies,
          ),
    );
  }

  void _jumpTo(double offset) {
    if (mounted && _controller.hasClients) {
      _controller.animateTo(
        offset.clamp(
          _controller.position.minScrollExtent,
          _controller.position.maxScrollExtent,
        ),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeIn,
      );
    }
  }

  @override
  Widget build(BuildContext context) => Consumer(
        builder: (_, ref, __) {
          final state = ref.watch(proxiesListSelectorStateProvider);
          ref.watch(themeSettingProvider.select((state) => state.textScale));
          if (state.groupNames.isEmpty) {
            return NullStatus(
              label: appLocalizations.nullTip(appLocalizations.proxies),
            );
          }
          final items = _buildItems(
            ref,
            groupNames: state.groupNames,
            currentUnfoldSet: state.currentUnfoldSet,
            columns: state.columns,
            cardType: state.proxyCardType,
            query: state.query,
          );
          final itemsOffset = _getItemHeightList(items, state.proxyCardType);
          return RepaintBoundary(
            child: CommonScrollBar(
              controller: _controller,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ScrollConfiguration(
                      behavior: HiddenBarScrollBehavior(),
                      child: FocusTraversalGroup(
                        policy: WidgetOrderTraversalPolicy(),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          controller: _controller,
                          itemExtentBuilder: (index, _) => itemsOffset[index],
                          itemCount: items.length,
                          itemBuilder: (_, index) => items[index],
                        ),
                      ),
                    ),
                  ),
                  LayoutBuilder(
                    builder: (_, container) {
                      _containerHeight = container.maxHeight;
                      return ValueListenableBuilder(
                        valueListenable: _headerStateNotifier,
                        builder: (_, headerState, __) {
                          if (headerState == null) {
                            return const SizedBox();
                          }
                          final index = headerState.currentIndex >
                                  state.groupNames.length - 1
                              ? 0
                              : headerState.currentIndex;
                          if (index < 0 || state.groupNames.isEmpty) {
                            return const SizedBox();
                          }
                          final groupName = state.groupNames[index];
                          final group = ref.watch(
                            currentGroupsStateProvider.select(
                              (state) => state.value.getGroup(groupName),
                            ),
                          );
                          if (group == null) {
                            return const SizedBox();
                          }
                          return Stack(
                            children: [
                              Positioned(
                                top: -headerState.offset,
                                child: Container(
                                  width: container.maxWidth,
                                  color: context.colorScheme.surface,
                                  padding: const EdgeInsets.only(
                                    top: 16,
                                    left: 16,
                                    right: 16,
                                    bottom: 8,
                                  ),
                                  child: _buildHeader(
                                    group: group,
                                    currentUnfoldSet: state.currentUnfoldSet,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );
}

class ListHeader extends StatefulWidget {
  const ListHeader({
    super.key,
    this.enterAnimated = true,
    required this.group,
    required this.onChange,
    required this.onScrollToSelected,
    required this.isExpand,
  });

  final Group group;
  final Function(String groupName) onChange;
  final Function(String groupName) onScrollToSelected;
  final bool isExpand;
  final bool enterAnimated;

  @override
  State<ListHeader> createState() => _ListHeaderState();
}

class _ListHeaderState extends State<ListHeader> {
  bool _isLock = false;

  String get icon => widget.group.icon;

  String get groupName => widget.group.name;

  String get groupType => widget.group.type.name;

  bool get isExpand => widget.isExpand;

  Future<void> _delayTest() async {
    if (_isLock) return;
    _isLock = true;
    await delayTest(widget.group.all, widget.group.testUrl);
    _isLock = false;
  }

  void _handleChange(String groupName) {
    widget.onChange(groupName);
  }

  Widget _buildIcon() => Consumer(
        builder: (_, ref, __) {
          final iconStyle = ref.watch(
            proxiesStyleSettingProvider.select((state) => state.iconStyle),
          );
          final icon = ref.watch(proxiesStyleSettingProvider.select((state) {
            final iconMapEntryList = state.iconMap.entries.toList();
            final index = iconMapEntryList.indexWhere((item) {
              try {
                return RegExp(item.key).hasMatch(groupName);
              } catch (_) {
                return false;
              }
            });
            if (index != -1) {
              return iconMapEntryList[index].value;
            }
            return this.icon;
          }));
          return switch (iconStyle) {
            ProxiesIconStyle.icon => Container(
                margin: const EdgeInsets.only(right: 16),
                child: LayoutBuilder(
                  builder: (_, constraints) => CommonTargetIcon(
                    src: icon,
                    size: constraints.maxHeight - 8,
                  ),
                ),
              ),
            ProxiesIconStyle.none => Container(),
          };
        },
      );

  @override
  Widget build(BuildContext context) => CommonCard(
        enterAnimated: widget.enterAnimated,
        key: widget.key,
        radius: 18.ap,
        type: CommonCardType.filled,
        onPressed: () => _handleChange(groupName),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  children: [
                    _buildIcon(),
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          EmojiText(
                            groupName,
                            style: context.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Flexible(
                            flex: 1,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  groupType,
                                  style: context.textTheme.labelMedium?.toLight,
                                ),
                                Flexible(
                                  flex: 1,
                                  child: Consumer(
                                    builder: (_, ref, __) {
                                      final proxyName = ref
                                          .watch(
                                            getSelectedProxyNameProvider(
                                              groupName,
                                            ),
                                          )
                                          .getSafeValue("");
                                      if (proxyName.isEmpty) {
                                        return const SizedBox();
                                      }
                                      return EmojiText(
                                        overflow: TextOverflow.ellipsis,
                                        ' · $proxyName',
                                        style: context
                                            .textTheme.labelMedium?.toLight,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  if (isExpand) ...[
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(2),
                      onPressed: () {
                        widget.onScrollToSelected(groupName);
                      },
                      style: const ButtonStyle(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      iconSize: 19,
                      icon: const Icon(Icons.adjust),
                    ),
                    const SizedBox(width: 2),
                    IconButton(
                      iconSize: 20,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(2),
                      onPressed: _delayTest,
                      style: const ButtonStyle(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.network_ping),
                    ),
                    const SizedBox(width: 6),
                  ] else
                    const SizedBox(width: 6),
                  IconButton.filledTonal(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(2),
                    iconSize: 24,
                    style: const ButtonStyle(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      _handleChange(groupName);
                    },
                    icon: CommonExpandIcon(expand: isExpand),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}
