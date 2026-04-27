import 'dart:async';
import 'dart:ui';

import 'package:flclashx/common/common.dart';
import 'package:flclashx/enum/enum.dart';
import 'package:flclashx/models/models.dart' hide Action;
import 'package:flclashx/pages/pages.dart';
import 'package:flclashx/providers/providers.dart';
import 'package:flclashx/state.dart';
import 'package:flclashx/views/profiles/edit_profile.dart';
import 'package:flclashx/views/profiles/override_profile.dart';
import 'package:flclashx/views/profiles/scripts.dart';
import 'package:flclashx/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'add_profile.dart';

class ProfilesView extends StatefulWidget {
  const ProfilesView({super.key});

  @override
  State<ProfilesView> createState() => _ProfilesViewState();
}

class _ProfilesViewState extends State<ProfilesView> with PageMixin {
  Function? applyConfigDebounce;

  void _handleShowAddExtendPage() {
    showExtend(
      globalState.navigatorKey.currentState!.context,
      builder: (_, type) => AdaptiveSheetScaffold(
        type: type,
        body: AddProfileView(
          context: globalState.navigatorKey.currentState!.context,
        ),
        title: "${appLocalizations.add}${appLocalizations.profile}",
      ),
    );
  }

  Future<void> _updateProfiles() async {
    final profiles = globalState.config.profiles;
    final messages = [];
    final updateProfiles = profiles.map<Future>(
      (profile) async {
        if (profile.type == ProfileType.file) return;
        globalState.appController.setProfile(
          profile.copyWith(isUpdating: true),
        );
        try {
          await globalState.appController.updateProfile(profile);
        } catch (e) {
          messages.add("${profile.label ?? profile.id}: $e \n");
          globalState.appController.setProfile(
            profile.copyWith(
              isUpdating: false,
            ),
          );
        }
      },
    );
    final titleMedium = context.textTheme.titleMedium;
    await Future.wait(updateProfiles);
    if (messages.isNotEmpty) {
      unawaited(globalState.showMessage(
        title: appLocalizations.tip,
        message: TextSpan(
          children: [
            for (final message in messages)
              TextSpan(text: message, style: titleMedium)
          ],
        ),
      ));
    }
  }

  @override
  List<Widget> get actions => [
        IconButton(
          onPressed: _updateProfiles,
          icon: const Icon(Icons.sync),
        ),
        IconButton(
          onPressed: () {
            showExtend(
              context,
              builder: (_, type) => const ScriptsView(),
            );
          },
          icon: Consumer(
            builder: (context, ref, __) {
              final isScriptMode = ref.watch(
                  scriptStateProvider.select((state) => state.realId != null));
              return Icon(
                Icons.functions,
                color: isScriptMode ? context.colorScheme.primary : null,
              );
            },
          ),
        ),
        IconButton(
          onPressed: () {
            final profiles = globalState.config.profiles;
            showSheet(
              context: context,
              builder: (_, type) => ReorderableProfilesSheet(
                type: type,
                profiles: profiles,
              ),
            );
          },
          icon: const Icon(Icons.sort),
          iconSize: 26,
        ),
      ];

  @override
  Widget? get floatingActionButton => FloatingActionButton(
        heroTag: null,
        onPressed: _handleShowAddExtendPage,
        child: const Icon(
          Icons.add,
        ),
      );

  @override
  Widget build(BuildContext context) => Consumer(
        builder: (_, ref, __) {
          ref.listenManual(
            isCurrentPageProvider(PageLabel.profiles),
            (prev, next) {
              if (prev != next && next == true) {
                initPageState();
              }
            },
            fireImmediately: true,
          );
          final profilesSelectorState =
              ref.watch(profilesSelectorStateProvider);
          if (profilesSelectorState.profiles.isEmpty) {
            return NullStatus(
              label: appLocalizations.nullProfileDesc,
            );
          }
          return Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: 88,
              ),
              child: Grid(
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                crossAxisCount: profilesSelectorState.columns,
                children: [
                  for (int i = 0;
                      i < profilesSelectorState.profiles.length;
                      i++)
                    GridItem(
                      child: ProfileItem(
                        key: Key(profilesSelectorState.profiles[i].id),
                        profile: profilesSelectorState.profiles[i],
                        groupValue: profilesSelectorState.currentProfileId,
                        onChanged: (profileId) {
                          ref.read(currentProfileIdProvider.notifier).value =
                              profileId;
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );
}

class ProfileItem extends StatefulWidget {
  const ProfileItem({
    super.key,
    required this.profile,
    required this.groupValue,
    required this.onChanged,
  });
  final Profile profile;
  final String? groupValue;
  final void Function(String? value) onChanged;

  @override
  State<ProfileItem> createState() => _ProfileItemState();
}

class _ProfileItemState extends State<ProfileItem> {
  final FocusNode _menuFocusNode = FocusNode();
  bool _isMenuFocused = false;
  bool _isTV = false;

  @override
  void initState() {
    super.initState();
    _checkIfTV();
    _menuFocusNode.addListener(() {
      if (mounted) {
        setState(() {
          _isMenuFocused = _menuFocusNode.hasFocus;
        });
      }
    });
  }

  Future<void> _checkIfTV() async {
    final isTV = await system.isAndroidTV;
    if (mounted) {
      setState(() {
        _isTV = isTV;
      });
    }
  }

  @override
  void dispose() {
    _menuFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleDeleteProfile(BuildContext context) async {
    final res = await globalState.showMessage(
      title: appLocalizations.tip,
      message: TextSpan(
        text: appLocalizations.deleteTip(appLocalizations.profile),
      ),
    );
    if (res != true) {
      return;
    }
    await globalState.appController.deleteProfile(widget.profile.id);
  }

  Future updateProfile() async {
    final appController = globalState.appController;
    if (widget.profile.type == ProfileType.file) return;
    await globalState.safeRun(silence: false, () async {
      try {
        appController.setProfile(
          widget.profile.copyWith(
            isUpdating: true,
          ),
        );
        await appController.updateProfile(widget.profile);
      } catch (e) {
        appController.setProfile(
          widget.profile.copyWith(
            isUpdating: false,
          ),
        );
        rethrow;
      }
    });
  }

  void _handleShowEditExtendPage(BuildContext context) {
    showExtend(
      context,
      builder: (_, type) => AdaptiveSheetScaffold(
        type: type,
        disableBackground: false,
        body: EditProfileView(
          profile: widget.profile,
          context: context,
        ),
        title: "${appLocalizations.edit}${appLocalizations.profile}",
      ),
    );
  }

  List<Widget> _buildUrlProfileInfo(BuildContext context) {
    final subscriptionInfo =
        widget.profile.subscriptionInfo ?? const SubscriptionInfo();
    final isUnlimited = subscriptionInfo.total == 0;
    final usedTrafficValue =
        subscriptionInfo.upload + subscriptionInfo.download;
    final progress = isUnlimited
        ? 0.0
        : (usedTrafficValue / subscriptionInfo.total).clamp(0.0, 1.0);
    final totalTraffic = TrafficValue(value: subscriptionInfo.total);
    final usedTraffic = TrafficValue(value: usedTrafficValue);
    final trafficText = isUnlimited
        ? appLocalizations.noTrafficInfo
        : '${usedTraffic.showValue} ${usedTraffic.showUnit} / ${totalTraffic.showValue} ${totalTraffic.showUnit}';
    final expireText = subscriptionInfo.expire > 0
        ? DateTime.fromMillisecondsSinceEpoch(subscriptionInfo.expire * 1000)
            .show
        : appLocalizations.noExpireInfo;
    final updateText = widget.profile.lastUpdateDate?.lastUpdateTimeDesc ??
        appLocalizations.just;

    return [
      const SizedBox(height: 4),
      ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: LinearProgressIndicator(
          value: progress,
          minHeight: 6,
          backgroundColor:
              Theme.of(context).colorScheme.surfaceContainerHighest,
          valueColor: AlwaysStoppedAnimation<Color>(
            switch (progress) {
              > 0.9 => Colors.red,
              > 0.7 => Colors.orange,
              _ => Colors.green,
            },
          ),
        ),
      ),
      const SizedBox(height: 6),
      Text(
        '$trafficText · $expireText',
        style: context.textTheme.bodySmall,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      const SizedBox(height: 4),
      Text(
        updateText,
        style: context.textTheme.labelMedium?.toLight,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ];
  }

  Future<void> _handleExportFile(BuildContext context) async {
    final commonScaffoldState = context.commonScaffoldState;
    final res = await commonScaffoldState?.loadingRun<bool>(
      () async {
        final file = await widget.profile.getFile();
        final value = await picker.saveFile(
          widget.profile.label ?? widget.profile.id,
          file.readAsBytesSync(),
        );
        if (value == null) return false;
        return true;
      },
      title: appLocalizations.tip,
    );
    if (res == true && context.mounted) {
      unawaited(context.showNotifier(appLocalizations.exportSuccess));
    }
  }

  void _handlePushGenProfilePage(BuildContext context, String id) {
    final overrideProfileView = OverrideProfileView(
      profileId: id,
    );
    BaseNavigator.modal(
      context,
      overrideProfileView,
    );
  }

  Future<void> _handleCopyLink(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: widget.profile.url));
    if (context.mounted) {
      unawaited(context.showNotifier(appLocalizations.copySuccess));
    }
  }

  @override
  Widget build(BuildContext context) => CommonCard(
        isSelected: widget.profile.id == widget.groupValue,
        onPressed: _isTV
            ? null
            : () {
                widget.onChanged(widget.profile.id);
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap:
                      _isTV ? () => widget.onChanged(widget.profile.id) : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.profile.label ?? widget.profile.id,
                        style: context.textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      ..._buildUrlProfileInfo(context)
                    ],
                  ),
                ),
              ),
              SizedBox(
                height: 40,
                width: 40,
                child: FadeThroughBox(
                  child: widget.profile.isUpdating
                      ? const Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(),
                        )
                      : CommonPopupBox(
                          popup: CommonPopupMenu(
                            items: [
                              if (_isTV)
                                PopupMenuItemData(
                                  icon: Icons.check_circle_outline,
                                  label: appLocalizations.selectProfile,
                                  onPressed: () {
                                    widget.onChanged(widget.profile.id);
                                  },
                                ),
                              PopupMenuItemData(
                                icon: Icons.edit_outlined,
                                label: appLocalizations.edit,
                                onPressed: () {
                                  _handleShowEditExtendPage(context);
                                },
                              ),
                              if (widget.profile.type == ProfileType.url) ...[
                                PopupMenuItemData(
                                  icon: Icons.sync_alt_sharp,
                                  label: appLocalizations.sync,
                                  onPressed: updateProfile,
                                ),
                              ],
                              PopupMenuItemData(
                                icon: Icons.emergency_outlined,
                                label: appLocalizations.more,
                                subItems: [
                                  if (system.isMobile && !_isTV)
                                    PopupMenuItemData(
                                      icon: Icons.tv_outlined,
                                      label: appLocalizations.sendToTv,
                                      onPressed: () {
                                        BaseNavigator.push(
                                          context,
                                          SendToTvPage(
                                            profileUrl: widget.profile.url,
                                          ),
                                        );
                                      },
                                    ),
                                  if (widget.profile
                                              .providerHeaders['support-url'] !=
                                          null &&
                                      widget
                                          .profile
                                          .providerHeaders['support-url']!
                                          .isNotEmpty &&
                                      !_isTV)
                                    PopupMenuItemData(
                                      icon: widget.profile
                                              .providerHeaders['support-url']!
                                              .toLowerCase()
                                              .contains('t.me')
                                          ? Icons.telegram
                                          : Icons.insert_link,
                                      label: appLocalizations.support,
                                      onPressed: () {
                                        globalState.openUrl(
                                          widget.profile
                                              .providerHeaders['support-url']!,
                                        );
                                      },
                                    ),
                                  PopupMenuItemData(
                                    icon: Icons.extension_outlined,
                                    label: appLocalizations.override,
                                    onPressed: () {
                                      _handlePushGenProfilePage(
                                        context,
                                        widget.profile.id,
                                      );
                                    },
                                  ),
                                  if (widget.profile.type == ProfileType.url)
                                    PopupMenuItemData(
                                      icon: Icons.copy,
                                      label: appLocalizations.copyLink,
                                      onPressed: () {
                                        _handleCopyLink(context);
                                      },
                                    ),
                                  PopupMenuItemData(
                                    icon: Icons.file_copy_outlined,
                                    label: appLocalizations.exportFile,
                                    onPressed: () {
                                      _handleExportFile(context);
                                    },
                                  ),
                                ],
                              ),
                              PopupMenuItemData(
                                danger: true,
                                icon: Icons.delete_outlined,
                                label: appLocalizations.delete,
                                onPressed: () {
                                  _handleDeleteProfile(context);
                                },
                              ),
                            ],
                          ),
                          targetBuilder: (open) => Focus(
                            focusNode: _menuFocusNode,
                            canRequestFocus: true,
                            child: Material(
                              color: _isMenuFocused
                                  ? Theme.of(context).focusColor
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              child: IconButton(
                                onPressed: open,
                                icon: const Icon(Icons.more_vert),
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      );
}

class ReorderableProfilesSheet extends StatefulWidget {
  const ReorderableProfilesSheet({
    super.key,
    required this.profiles,
    required this.type,
  });
  final List<Profile> profiles;
  final SheetType type;

  @override
  State<ReorderableProfilesSheet> createState() =>
      _ReorderableProfilesSheetState();
}

class _ReorderableProfilesSheetState extends State<ReorderableProfilesSheet> {
  late List<Profile> profiles;

  @override
  void initState() {
    super.initState();
    profiles = List.from(widget.profiles);
  }

  Widget proxyDecorator(
    Widget child,
    int index,
    Animation<double> animation,
  ) {
    final profile = profiles[index];
    return AnimatedBuilder(
      animation: animation,
      builder: (_, child) {
        final animValue = Curves.easeInOut.transform(animation.value);
        final scale = lerpDouble(1, 1.02, animValue)!;
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: Container(
        key: Key(profile.id),
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: CommonCard(
          type: CommonCardType.filled,
          child: ListTile(
            contentPadding: const EdgeInsets.only(
              right: 44,
              left: 16,
            ),
            title: Text(profile.label ?? profile.id),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AdaptiveSheetScaffold(
        type: widget.type,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).pop();
              globalState.appController.setProfiles(profiles);
            },
            icon: const Icon(
              Icons.save,
            ),
          )
        ],
        body: Padding(
          padding: const EdgeInsets.only(
            bottom: 32,
            top: 16,
          ),
          child: ReorderableListView.builder(
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
            ),
            proxyDecorator: proxyDecorator,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                var targetIndex = newIndex;
                if (oldIndex < newIndex) {
                  targetIndex -= 1;
                }
                final profile = profiles.removeAt(oldIndex);
                profiles.insert(targetIndex, profile);
              });
            },
            itemBuilder: (_, index) {
              final profile = profiles[index];
              return Container(
                key: Key(profile.id),
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: CommonCard(
                  type: CommonCardType.filled,
                  child: ListTile(
                    contentPadding: const EdgeInsets.only(
                      right: 16,
                      left: 16,
                    ),
                    title: Text(profile.label ?? profile.id),
                    trailing: ReorderableDragStartListener(
                      index: index,
                      child: const Icon(Icons.drag_handle),
                    ),
                  ),
                ),
              );
            },
            itemCount: profiles.length,
          ),
        ),
        title: appLocalizations.profilesSort,
      );
}
