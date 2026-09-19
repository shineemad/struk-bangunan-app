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
  test('aplikasi bernama Notaku, bukan nama paket Flutter', () {
    // Nama yang terlihat di layar peluncur. `struk_bangunan` adalah nama paket
    // Dart bawaan `flutter create` dan tidak pernah pantas dilihat pengguna.
    expect(
      _baca('android/app/src/main/AndroidManifest.xml'),
      contains('android:label="Notaku"'),
    );
  });

  test('ikon peluncur punya varian adaptif dan lawas', () {
    // Adaptif untuk Android 8+, PNG untuk 24-25 yang belum mendukungnya.
    expect(
      File(
        'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
      ).existsSync(),
      isTrue,
    );
    for (final kepadatan in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
      expect(
        File(
          'android/app/src/main/res/mipmap-$kepadatan/ic_launcher.png',
        ).existsSync(),
        isTrue,
        reason: 'ikon lawas $kepadatan hilang',
      );
    }
  });

  test('build rilis tidak memakai kunci debug bila kunci rilis tersedia', () {
    // TODO bawaan `flutter create` menandatangani rilis dengan kunci debug,
    // yang ditolak Play Store. Sekarang kunci debug hanya dipakai sebagai
    // cadangan selama `key.properties` belum dibuat.
    final gradle = _baca('android/app/build.gradle.kts');

    expect(gradle, contains('key.properties'));
    expect(gradle, contains('signingConfigs.getByName("release")'));
    expect(
      gradle,
      isNot(contains('// TODO: Add your own signing config')),
      reason: 'TODO bawaan flutter create masih ada',
    );
  });

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
