import 'dart:async';

import 'package:flclashx/common/common.dart';
import 'package:flclashx/services/lan_profile_share_service.dart';
import 'package:flclashx/state.dart';
import 'package:flclashx/widgets/widgets.dart';
import 'package:flutter/material.dart';

class LanProfileDiscoveryPage extends StatefulWidget {
  const LanProfileDiscoveryPage({super.key});

  @override
  State<LanProfileDiscoveryPage> createState() =>
      _LanProfileDiscoveryPageState();
}

class _LanProfileDiscoveryPageState extends State<LanProfileDiscoveryPage> {
  late final LanProfileDiscovery _discovery;
  StreamSubscription<List<LanProfileShareAnnouncement>>? _subscription;
  List<LanProfileShareAnnouncement> _items = [];
  bool _isLoading = true;
  String? _error;
  String? _fetchingDeviceId;

  @override
  void initState() {
    super.initState();
    _discovery = LanProfileDiscovery();
    _start();
  }

  Future<void> _start() async {
    try {
      _subscription = _discovery.stream.listen((items) {
        if (!mounted) return;
        setState(() {
          _items = items;
          _isLoading = false;
        });
      });
      await _discovery.start();
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleFetch(LanProfileShareAnnouncement item) async {
    setState(() {
      _fetchingDeviceId = item.deviceId;
    });
    try {
      final url = await _discovery.fetchProfileUrl(item);
      if (!mounted) return;
      Navigator.of(context).pop(url);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fetchingDeviceId = null;
      });
      await globalState.showMessage(message: TextSpan(text: e.toString()));
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _discovery.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(appLocalizations.addFromPhoneTitle)),
        body: _buildBody(),
      );

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.radar_outlined,
                size: 48,
                color: context.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                appLocalizations.addFromPhoneSubtitle,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        final isFetching = _fetchingDeviceId == item.deviceId;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: CommonCard(
            child: ListItem(
              leading: const Icon(Icons.devices_other_outlined),
              title: Text(item.deviceName),
              subtitle: Text(
                [
                  if (item.profileName.isNotEmpty) item.profileName,
                  '${item.host}:${item.port}',
                ].join(' · '),
              ),
              trailing: isFetching
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_outlined),
              onTap: isFetching ? null : () => _handleFetch(item),
            ),
          ),
        );
      },
    );
  }
}
