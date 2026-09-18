import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Izin yang disuntikkan `print_bluetooth_thermal` lewat manifest-nya sendiri,
/// sehingga hanya bisa dicabut dari sisi kita.
const _izinDariPlugin = [
  'android.permission.INTERNET',
  'android.permission.BLUETOOTH',
  'android.permission.BLUETOOTH_ADMIN',
  'android.permission.BLUETOOTH_CONNECT',
  'android.permission.BLUETOOTH_SCAN',
];

String _baca(String jalur) => File(jalur).readAsStringSync();

void main() {
  test('manifest main tidak meminta izin apa pun', () {
    // Fitur cetak ditunda, jadi tidak ada satu pun izin yang punya pemakai.
    expect(
      _baca('android/app/src/main/AndroidManifest.xml'),
      isNot(contains('uses-permission')),
    );
  });

  test('manifest rilis mencabut setiap izin suntikan plugin', () {
    // Manifest `main` yang bersih tidak cukup: penggabungan manifest Android
    // menambahkan izin milik plugin ke APK, dan itu sempat membuat APK rilis
    // meminta INTERNET padahal spec bagian 4 dan 10 menjanjikan sebaliknya.
    final isi = _baca('android/app/src/release/AndroidManifest.xml');

    for (final izin in _izinDariPlugin) {
      final pola = RegExp(
        'android:name="${RegExp.escape(izin)}"\\s+tools:node="remove"',
      );
      expect(
        pola.hasMatch(isi),
        isTrue,
        reason: 'izin $izin tidak dicabut di manifest rilis',
      );
    }
  });
}
