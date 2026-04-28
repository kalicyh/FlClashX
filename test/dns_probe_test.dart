import 'dart:io';
import 'dart:typed_data';

import 'package:flclashx/common/dns_probe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DnsProbe resolves A records from a UDP DNS server', () async {
    final server =
        await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = server.listen((event) {
      if (event != RawSocketEvent.read) {
        return;
      }
      final datagram = server.receive();
      if (datagram == null) {
        return;
      }
      server.send(
        _buildARecordResponse(datagram.data, [192, 168, 31, 1]),
        datagram.address,
        datagram.port,
      );
    });

    try {
      final result = await DnsProbe.resolveA(
        domain: 'nz.com',
        server: InternetAddress.loopbackIPv4.address,
        port: server.port,
      );

      expect(result.addresses, ['192.168.31.1']);
      expect(result.matches('192.168.31.1'), isTrue);
    } finally {
      await subscription.cancel();
      server.close();
    }
  });
}

Uint8List _buildARecordResponse(Uint8List query, List<int> address) {
  final questionEnd = _questionEnd(query);
  final bytes = BytesBuilder()
    ..add(query.sublist(0, 2))
    ..add([0x81, 0x80, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00])
    ..add(query.sublist(12, questionEnd))
    ..add([
      0xc0,
      0x0c,
      0x00,
      0x01,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x04,
      ...address,
    ]);
  return bytes.toBytes();
}

int _questionEnd(Uint8List query) {
  var offset = 12;
  while (offset < query.length && query[offset] != 0) {
    offset += query[offset] + 1;
  }
  return offset + 5;
}
