import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('manifest rilis memuat izin Bluetooth dan tidak memuat INTERNET', () {
    final isi = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    // Dicocokkan beserta tanda kutip penutup: `contains('...BLUETOOTH')` saja
    // juga akan lolos untuk `BLUETOOTH_SCAN`/`BLUETOOTH_CONNECT`, sehingga
    // tidak punya daya menjaga izin telanjangnya.
    expect(isi, contains('android.permission.BLUETOOTH"'));
    expect(isi, contains('android.permission.BLUETOOTH_CONNECT'));
    expect(isi, contains('android.permission.BLUETOOTH_SCAN'));
    expect(isi, contains('android.permission.BLUETOOTH_ADMIN'));
    expect(isi, contains('android.permission.ACCESS_FINE_LOCATION'));

    // Seluruh janji "berjalan tanpa internet" bersandar pada baris ini.
    expect(isi, isNot(contains('android.permission.INTERNET')));
  });
}
