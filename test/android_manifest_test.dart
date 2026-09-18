import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('manifest rilis memuat izin Bluetooth dan tidak memuat INTERNET', () {
    final isi = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(isi, contains('android.permission.BLUETOOTH_CONNECT'));
    expect(isi, contains('android.permission.BLUETOOTH_SCAN'));
    expect(isi, contains('android.permission.BLUETOOTH_ADMIN'));
    expect(isi, contains('android.permission.ACCESS_FINE_LOCATION'));

    // Seluruh janji "berjalan tanpa internet" bersandar pada baris ini.
    expect(isi, isNot(contains('android.permission.INTERNET')));
  });
}
