import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:struk_bangunan/ui/tema.dart';

/// Luminansi relatif menurut WCAG 2.1.
double _luminansi(Color c) {
  double kanal(double v) =>
      v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * kanal(c.r) + 0.7152 * kanal(c.g) + 0.0722 * kanal(c.b);
}

double rasioKontras(Color a, Color b) {
  final la = _luminansi(a);
  final lb = _luminansi(b);
  final terang = math.max(la, lb);
  final gelap = math.min(la, lb);
  return (terang + 0.05) / (gelap + 0.05);
}

void main() {
  test('setiap pasangan teks dan latar lolos ambang 4,5:1', () {
    final pasangan = <String, (Color, Color)>{
      'teks di kartu': (Warna.teks, Warna.permukaan),
      'teks di latar': (Warna.teks, Warna.latar),
      'teks di isian': (Warna.teks, Warna.isian),
      'teks sekunder di kartu': (Warna.teksSekunder, Warna.permukaan),
      'teks sekunder di isian': (Warna.teksSekunder, Warna.isian),
      'putih di atas aksen': (Colors.white, Warna.aksen),
      'putih di atas merusak': (Colors.white, Warna.merusak),
      'putih di atas tambah': (Colors.white, Warna.tambah),
    };

    for (final entri in pasangan.entries) {
      final (depan, belakang) = entri.value;
      expect(
        rasioKontras(depan, belakang),
        greaterThanOrEqualTo(4.5),
        reason: '${entri.key} terlalu tipis',
      );
    }
  });

  test('tombol utama setinggi lantai area sentuh', () {
    final tema = temaTerang();
    final ukuran = tema.filledButtonTheme.style!.minimumSize!.resolve({});

    expect(ukuran!.height, Ukuran.tombol);
    expect(ukuran.height, greaterThanOrEqualTo(Ukuran.sentuh));
  });

  test('teks tombol utama 20 dan isian 18', () {
    final tema = temaTerang();

    expect(tema.filledButtonTheme.style!.textStyle!.resolve({})!.fontSize, 20);
    expect(tema.textTheme.bodyLarge!.fontSize, 18);
  });

  test('tema tidak memaksakan keluarga font kustom', () {
    // Font antarmuka = bawaan sistem (design system bagian 4). Yang dijaga di
    // sini adalah tidak adanya keluarga font yang kita paksakan sendiri, bukan
    // nama fontnya — nama itu berbeda antar platform host. `ThemeData` di SDK
    // ini (Flutter 3.38.5) tidak lagi punya getter/parameter `fontFamily`
    // puncak sama sekali (dihapus dari kelasnya), jadi satu-satunya tempat
    // font bisa dipaksakan adalah lewat `textTheme` — itulah yang diperiksa.
    final bawaan = ThemeData(
      useMaterial3: true,
    ).textTheme.bodyLarge!.fontFamily;

    expect(temaTerang().textTheme.bodyLarge!.fontFamily, bawaan);
  });

  test('pubspec tidak memuat google_fonts dan tidak membundel font', () {
    // `google_fonts` mengunduh saat dijalankan, dan aplikasi ini tidak punya
    // izin INTERNET — jadi ia haram di proyek ini. Font apa pun yang dinamai
    // di tema wajib sudah dibundel, dan sampai ada yang dibundel, bagian
    // `fonts:` harus tetap absen.
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(pubspec, isNot(contains('google_fonts')));
    expect(pubspec, isNot(matches(RegExp(r'^\s{2}fonts:', multiLine: true))));
  });
}
