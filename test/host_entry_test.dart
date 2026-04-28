import 'package:flclashx/common/hosts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('HostEntry stores disabled entries without changing display key', () {
    expect(HostEntry.isEnabled('nz.com'), isTrue);
    expect(HostEntry.displayKey('nz.com'), 'nz.com');
    expect(HostEntry.storageKey('nz.com', enabled: false), '!nz.com');

    expect(HostEntry.isEnabled('!nz.com'), isFalse);
    expect(HostEntry.displayKey('!nz.com'), 'nz.com');
    expect(HostEntry.storageKey('!nz.com', enabled: true), 'nz.com');
  });
}
