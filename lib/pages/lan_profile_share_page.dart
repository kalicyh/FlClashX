import 'package:flclashx/common/common.dart';
import 'package:flclashx/services/lan_profile_share_service.dart';
import 'package:flutter/material.dart';

class LanProfileSharePage extends StatefulWidget {
  const LanProfileSharePage({
    super.key,
    required this.profileUrl,
    this.profileName,
  });

  final String profileUrl;
  final String? profileName;

  @override
  State<LanProfileSharePage> createState() => _LanProfileSharePageState();
}

class _LanProfileSharePageState extends State<LanProfileSharePage> {
  late final LanProfileShareServer _server;
  Future<void>? _startFuture;

  @override
  void initState() {
    super.initState();
    _server = LanProfileShareServer(
      profileUrl: widget.profileUrl,
      profileName: widget.profileName ?? appLocalizations.profile,
    );
    _startFuture = _server.start();
  }

  @override
  void dispose() {
    _server.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(appLocalizations.sendToTvTitle)),
        body: FutureBuilder<void>(
          future: _startFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.wifi_tethering,
                        size: 48,
                        color: context.colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        appLocalizations.sendToTvTitle,
                        style: context.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_server.host}:${_server.port}',
                        style: context.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.stop_circle_outlined),
                        label: Text(appLocalizations.cancel),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
}
