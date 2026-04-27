import 'package:flclashx/common/common.dart';
import 'package:flclashx/models/clash_config.dart';
import 'package:flclashx/providers/config.dart' show patchClashConfigProvider;
import 'package:flclashx/state.dart';
import 'package:flclashx/views/config/dns.dart';
import 'package:flclashx/views/config/general.dart';
import 'package:flclashx/views/config/network.dart';
import 'package:flclashx/views/config/rules.dart';
import 'package:flclashx/views/profiles/scripts.dart';
import 'package:flclashx/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConfigView extends StatefulWidget {
  const ConfigView({super.key});

  @override
  State<ConfigView> createState() => _ConfigViewState();
}

class _ConfigViewState extends State<ConfigView> {
  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      ListItem.open(
        title: Text(appLocalizations.general),
        subtitle: Text(appLocalizations.generalDesc),
        leading: const Icon(Icons.build),
        delegate: OpenDelegate(
          title: appLocalizations.general,
          widget: generateListView(
            generalItems,
          ),
          blur: false,
        ),
      ),
      ListItem.open(
        title: Text(appLocalizations.network),
        subtitle: Text(appLocalizations.networkDesc),
        leading: const Icon(Icons.vpn_key),
        delegate: OpenDelegate(
          title: appLocalizations.network,
          blur: false,
          widget: const NetworkListView(),
        ),
      ),
      ListItem.open(
        title: const Text("DNS"),
        subtitle: Text(appLocalizations.dnsDesc),
        leading: const Icon(Icons.dns),
        delegate: OpenDelegate(
          title: "DNS",
          action: Consumer(
              builder: (_, ref, __) => IconButton(
                    onPressed: () async {
                      final res = await globalState.showMessage(
                        title: appLocalizations.reset,
                        message: TextSpan(
                          text: appLocalizations.resetTip,
                        ),
                      );
                      if (res != true) {
                        return;
                      }
                      ref.read(patchClashConfigProvider.notifier).updateState(
                            (state) => state.copyWith(
                              dns: defaultDns,
                            ),
                          );
                    },
                    tooltip: appLocalizations.reset,
                    icon: const Icon(
                      Icons.replay,
                    ),
                  )),
          widget: const DnsListView(),
          blur: false,
        ),
      ),
      ListItem(
        title: Text(appLocalizations.addedRules),
        subtitle: Text(appLocalizations.controlGlobalAddedRules),
        leading: const Icon(Icons.library_books),
        onTap: () => showExtend(
          context,
          props: const ExtendProps(blur: false),
          builder: (_, __) => const AddedRulesView(),
        ),
      ),
      ListItem(
        title: Text(appLocalizations.script),
        subtitle: Text(appLocalizations.overrideScript),
        leading: const Icon(Icons.rocket, fontWeight: FontWeight.w900),
        onTap: () => showExtend(
          context,
          props: const ExtendProps(blur: false),
          builder: (_, __) => const ScriptsView(),
        ),
      ),
    ];
    return generateListView(
      items
          .separated(
            const Divider(
              height: 0,
            ),
          )
          .toList(),
    );
  }
}
