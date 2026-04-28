import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

class DnsProbeResult {
  const DnsProbeResult({
    required this.domain,
    required this.server,
    required this.port,
    required this.addresses,
  });

  final String domain;
  final String server;
  final int port;
  final List<String> addresses;

  bool matches(String expected) => addresses.contains(expected.trim());
}

class DnsProbe {
  const DnsProbe._();

  static Future<DnsProbeResult> resolveA({
    required String domain,
    required String server,
    required int port,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final queryId = Random.secure().nextInt(0xffff);
    final query = _buildQuery(queryId, domain);
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    try {
      socket.send(query, InternetAddress(server), port);
      final packet = await socket
          .where((event) => event == RawSocketEvent.read)
          .map((_) => socket.receive())
          .where((datagram) => datagram != null)
          .cast<Datagram>()
          .first
          .timeout(timeout);
      return DnsProbeResult(
        domain: domain,
        server: server,
        port: port,
        addresses: _parseARecords(packet.data, queryId),
      );
    } finally {
      socket.close();
    }
  }

  static Uint8List _buildQuery(int id, String domain) {
    final bytes = BytesBuilder()
      ..add([
        id >> 8,
        id & 0xff,
        0x01,
        0x00,
        0x00,
        0x01,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
      ]);
    for (final label in domain.split('.').where((label) => label.isNotEmpty)) {
      final codeUnits = label.codeUnits;
      bytes
        ..add([codeUnits.length])
        ..add(codeUnits);
    }
    bytes.add([0x00, 0x00, 0x01, 0x00, 0x01]);
    return bytes.toBytes();
  }

  static List<String> _parseARecords(Uint8List data, int expectedId) {
    if (data.length < 12) {
      throw const FormatException('DNS response is too short');
    }
    final id = (data[0] << 8) | data[1];
    if (id != expectedId) {
      throw const FormatException('DNS response id mismatch');
    }
    final questionCount = (data[4] << 8) | data[5];
    final answerCount = (data[6] << 8) | data[7];
    var offset = 12;
    for (var i = 0; i < questionCount; i++) {
      offset = _skipName(data, offset) + 4;
    }

    final addresses = <String>[];
    for (var i = 0; i < answerCount; i++) {
      offset = _skipName(data, offset);
      if (offset + 10 > data.length) {
        throw const FormatException('DNS answer is truncated');
      }
      final type = (data[offset] << 8) | data[offset + 1];
      final recordClass = (data[offset + 2] << 8) | data[offset + 3];
      final length = (data[offset + 8] << 8) | data[offset + 9];
      offset += 10;
      if (offset + length > data.length) {
        throw const FormatException('DNS record data is truncated');
      }
      if (type == 1 && recordClass == 1 && length == 4) {
        addresses.add(data.sublist(offset, offset + 4).join('.'));
      }
      offset += length;
    }
    return addresses;
  }

  static int _skipName(Uint8List data, int offset) {
    var currentOffset = offset;
    while (currentOffset < data.length) {
      final length = data[currentOffset];
      if ((length & 0xc0) == 0xc0) {
        return currentOffset + 2;
      }
      currentOffset++;
      if (length == 0) {
        return currentOffset;
      }
      currentOffset += length;
    }
    throw const FormatException('DNS name is truncated');
  }
}
