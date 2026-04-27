import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flclashx/common/common.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart' as shelf_router;

const _lanShareType = 'flclashx_lan_profile_share';
const _lanShareVersion = 1;
const lanProfileShareBroadcastPort = 38991;

String _randomToken() {
  final random = Random.secure();
  final values = List<int>.generate(24, (_) => random.nextInt(256));
  return base64UrlEncode(values).replaceAll('=', '');
}

class LanProfileShareAnnouncement {
  const LanProfileShareAnnouncement({
    required this.deviceId,
    required this.deviceName,
    required this.host,
    required this.port,
    required this.token,
    required this.profileName,
    required this.timestamp,
  });

  final String deviceId;
  final String deviceName;
  final String host;
  final int port;
  final String token;
  final String profileName;
  final DateTime timestamp;

  Uri get profileUri => Uri(
        scheme: 'http',
        host: host,
        port: port,
        path: '/profile',
        queryParameters: {'token': token},
      );

  Map<String, dynamic> toJson() => {
        'type': _lanShareType,
        'version': _lanShareVersion,
        'deviceId': deviceId,
        'deviceName': deviceName,
        'host': host,
        'port': port,
        'token': token,
        'profileName': profileName,
        'timestamp': timestamp.millisecondsSinceEpoch,
      };

  static LanProfileShareAnnouncement? fromJson(Map<String, dynamic> json) {
    if (json['type'] != _lanShareType || json['version'] != _lanShareVersion) {
      return null;
    }
    final host = json['host'] as String?;
    final port = json['port'] as int?;
    final token = json['token'] as String?;
    final deviceId = json['deviceId'] as String?;
    if (host == null || port == null || token == null || deviceId == null) {
      return null;
    }
    return LanProfileShareAnnouncement(
      deviceId: deviceId,
      deviceName: json['deviceName'] as String? ?? 'FlClashX',
      host: host,
      port: port,
      token: token,
      profileName: json['profileName'] as String? ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        json['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

class LanProfileShareServer {
  LanProfileShareServer({
    required this.profileUrl,
    required this.profileName,
  });

  final String profileUrl;
  final String profileName;
  final String token = _randomToken();
  final String deviceId = _randomToken();

  HttpServer? _server;
  RawDatagramSocket? _broadcastSocket;
  Timer? _broadcastTimer;
  String? _host;
  String? _deviceName;

  int? get port => _server?.port;

  String? get host => _host;

  Future<void> start() async {
    _host = await utils.getLocalIpAddress();
    if (_host == null || _host!.isEmpty) {
      throw Exception('Could not get local IP address');
    }

    _deviceName = Platform.localHostname;

    final router = shelf_router.Router()
      ..get(
        '/info',
        (shelf.Request request) => shelf.Response.ok(
          jsonEncode(_announcement().toJson()),
          headers: {'content-type': 'application/json'},
        ),
      )
      ..get('/profile', (shelf.Request request) {
        final requestToken = request.url.queryParameters['token'];
        if (requestToken != token) {
          return shelf.Response.forbidden('Invalid token');
        }
        return shelf.Response.ok(
          jsonEncode({'url': profileUrl}),
          headers: {'content-type': 'application/json'},
        );
      });

    _server = await shelf_io.serve(router.call, InternetAddress.anyIPv4, 0);
    _broadcastSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    _broadcastSocket?.broadcastEnabled = true;
    _broadcastTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _broadcast(),
    );
    _broadcast();
  }

  LanProfileShareAnnouncement _announcement() => LanProfileShareAnnouncement(
        deviceId: deviceId,
        deviceName: _deviceName ?? 'FlClashX',
        host: _host!,
        port: _server!.port,
        token: token,
        profileName: profileName,
        timestamp: DateTime.now(),
      );

  void _broadcast() {
    final socket = _broadcastSocket;
    if (socket == null || _server == null || _host == null) return;
    final bytes = utf8.encode(jsonEncode(_announcement().toJson()));
    socket.send(
      bytes,
      InternetAddress('255.255.255.255'),
      lanProfileShareBroadcastPort,
    );
  }

  Future<void> stop() async {
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    _broadcastSocket?.close();
    _broadcastSocket = null;
    await _server?.close(force: true);
    _server = null;
  }
}

class LanProfileDiscovery {
  final _controller =
      StreamController<List<LanProfileShareAnnouncement>>.broadcast();
  final Map<String, LanProfileShareAnnouncement> _announcements = {};
  RawDatagramSocket? _socket;
  Timer? _cleanupTimer;

  Stream<List<LanProfileShareAnnouncement>> get stream => _controller.stream;

  Future<void> start() async {
    _socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      lanProfileShareBroadcastPort,
      reuseAddress: true,
      reusePort: Platform.isMacOS || Platform.isIOS,
    );
    _socket?.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = _socket?.receive();
      if (datagram == null) return;
      try {
        final json = jsonDecode(utf8.decode(datagram.data));
        if (json is! Map<String, dynamic>) return;
        final announcement = LanProfileShareAnnouncement.fromJson(json);
        if (announcement == null) return;
        _announcements[announcement.deviceId] = announcement;
        _emit();
      } catch (_) {
        return;
      }
    });
    _cleanupTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _removeExpired(),
    );
    _emit();
  }

  Future<String> fetchProfileUrl(
    LanProfileShareAnnouncement announcement,
  ) async {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
    ));
    final response = await dio.getUri<Map<String, dynamic>>(
      announcement.profileUri,
    );
    final url = response.data?['url'] as String?;
    if (url == null || url.isEmpty) {
      throw Exception('Profile URL not found');
    }
    return url;
  }

  void _removeExpired() {
    final now = DateTime.now();
    _announcements.removeWhere(
      (_, item) => now.difference(item.timestamp) > const Duration(seconds: 10),
    );
    _emit();
  }

  void _emit() {
    final items = _announcements.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    _controller.add(items);
  }

  Future<void> stop() async {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    _socket?.close();
    _socket = null;
    await _controller.close();
  }
}
