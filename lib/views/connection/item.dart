import 'dart:io';

import 'package:flclashx/common/common.dart';
import 'package:flclashx/enum/enum.dart';
import 'package:flclashx/models/models.dart';
import 'package:flclashx/plugins/app.dart';
import 'package:flclashx/providers/config.dart';
import 'package:flclashx/state.dart';
import 'package:flclashx/views/profiles/override_profile.dart';
import 'package:flclashx/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConnectionItem extends ConsumerWidget {
  const ConnectionItem({
    super.key,
    required this.connection,
    this.onClickKeyword,
    this.trailing,
  });
  final Connection connection;
  final Function(String)? onClickKeyword;
  final Widget? trailing;

  Future<ImageProvider?> _getPackageIcon(Connection connection) async =>
      await app?.getPackageIcon(connection.metadata.process);

  String _getSourceText(Connection connection) {
    final metadata = connection.metadata;
    if (metadata.process.isEmpty) {
      return connection.start.lastUpdateTimeDesc;
    }
    return "${metadata.process} · ${connection.start.lastUpdateTimeDesc}";
  }

  bool _isIp(String value) {
    if (value.isEmpty) {
      return false;
    }
    return RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(value) ||
        value.contains(":");
  }

  String _getRuleTarget(ClashConfigSnippet snippet) {
    final targets = {
      ...snippet.proxyGroups.map((item) => item.name),
      ...RuleTarget.values.map((item) => item.name),
    };
    for (final chain in connection.chains) {
      if (targets.contains(chain)) {
        return chain;
      }
    }
    if (connection.chains.isNotEmpty) {
      return connection.chains.first;
    }
    return RuleTarget.DIRECT.name;
  }

  Rule _buildRule(ClashConfigSnippet snippet) {
    final metadata = connection.metadata;
    final host = metadata.host.trim();
    final destinationIP = metadata.destinationIP.trim();
    final process = metadata.process.trim();
    final target = _getRuleTarget(snippet);

    final ParsedRule parsedRule;
    if (host.isNotEmpty && !_isIp(host)) {
      parsedRule = ParsedRule(
        ruleAction: RuleAction.DOMAIN,
        content: host,
        ruleTarget: target,
      );
    } else if (destinationIP.isNotEmpty) {
      final isIpv6 = destinationIP.contains(":");
      parsedRule = ParsedRule(
        ruleAction: isIpv6 ? RuleAction.IP_CIDR6 : RuleAction.IP_CIDR,
        content: "$destinationIP/${isIpv6 ? 128 : 32}",
        ruleTarget: target,
        noResolve: true,
      );
    } else if (process.isNotEmpty) {
      parsedRule = ParsedRule(
        ruleAction: RuleAction.PROCESS_NAME,
        content: process,
        ruleTarget: target,
      );
    } else {
      parsedRule = ParsedRule(
        ruleAction: RuleAction.MATCH,
        ruleTarget: target,
      );
    }

    return Rule.value(parsedRule.value);
  }

  Future<ClashConfigSnippet> _loadSnippet() async {
    final profileId = globalState.config.currentProfileId;
    if (profileId == null) {
      return const ClashConfigSnippet();
    }
    final rawConfig = await globalState.getProfileConfig(profileId);
    return ClashConfigSnippet.fromJson(rawConfig);
  }

  Future<void> _handleQuickRule(BuildContext context, WidgetRef ref) async {
    final snippet = await _loadSnippet();
    if (!context.mounted) {
      return;
    }
    final rule = _buildRule(snippet);
    final res = await globalState.showCommonDialog<Rule>(
      child: AddRuleDialog(
        rule: rule,
        snippet: snippet,
      ),
    );
    if (res == null) {
      return;
    }
    ref.read(patchClashConfigProvider.notifier).updateState(
          (state) => state.copyWith(
            rule: [
              res.value,
              ...state.rule.where((item) => item != res.value),
            ],
          ),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(
      patchClashConfigProvider.select(
        (state) =>
            state.findProcessMode == FindProcessMode.always &&
            Platform.isAndroid,
      ),
    );
    final title = Text(
      connection.desc,
      style: context.textTheme.bodyLarge,
    );
    final subTitle = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(
          height: 8,
        ),
        Text(
          _getSourceText(connection),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(
          height: 8,
        ),
        Wrap(
          runSpacing: 6,
          spacing: 6,
          children: [
            for (final chain in connection.chains)
              CommonChip(
                label: chain,
                onPressed: () {
                  if (onClickKeyword == null) return;
                  onClickKeyword!(chain);
                },
              ),
          ],
        ),
      ],
    );
    return InkWell(
      onTap: () => _handleQuickRule(context, ref),
      child: ListItem(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 4,
        ),
        tileTitleAlignment: ListTileTitleAlignment.titleHeight,
        leading: value
            ? GestureDetector(
                onTap: () {
                  if (onClickKeyword == null) return;
                  final process = connection.metadata.process;
                  if (process.isEmpty) return;
                  onClickKeyword!(process);
                },
                child: Container(
                  margin: const EdgeInsets.only(top: 4),
                  width: 48,
                  height: 48,
                  child: FutureBuilder<ImageProvider?>(
                    future: _getPackageIcon(connection),
                    builder: (_, snapshot) {
                      if (!snapshot.hasData && snapshot.data == null) {
                        return Container();
                      } else {
                        return Image(
                          image: snapshot.data!,
                          gaplessPlayback: true,
                          width: 48,
                          height: 48,
                        );
                      }
                    },
                  ),
                ),
              )
            : null,
        title: title,
        subtitle: subTitle,
        trailing: trailing,
      ),
    );
  }
}
