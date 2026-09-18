import 'package:flutter/material.dart';

/// Token warna dari `design-system/strukbangunan/MASTER.md`. Seluruh rasio
/// kontrasnya dihitung, bukan ditaksir; `tema_test.dart` yang menjaganya.
abstract final class Warna {
  static const latar = Color(0xFFF8FAFC);
  static const permukaan = Color(0xFFFFFFFF);
  static const isian = Color(0xFFEAEFF3);
  static const garis = Color(0xFFE2E8F0);
  static const teks = Color(0xFF0F172A);
  static const teksSekunder = Color(0xFF475569);
  static const aksen = Color(0xFF2563EB);
  static const merusak = Color(0xFFDC2626);
  static const tambah = Color(0xFF15803D);
}

/// Lantai ukuran dari spec bagian 5. Pengguna aplikasi ini berusia 50-70
/// tahun; angka-angka ini bukan selera, melainkan syarat.
abstract final class Ukuran {
  static const double sentuh = 48;
  static const double tombol = 56;
  static const double isian = 56;
  static const double radiusIsian = 16;
  static const double radiusKartu = 20;
  static const double jarak = 16;
}

ThemeData temaTerang() {
  const skema = ColorScheme.light(
    primary: Warna.aksen,
    onPrimary: Colors.white,
    surface: Warna.permukaan,
    onSurface: Warna.teks,
    error: Warna.merusak,
    onError: Colors.white,
    outline: Warna.garis,
  );

  const isi = TextStyle(fontSize: 18, height: 1.4, color: Warna.teks);

  return ThemeData(
    useMaterial3: true,
    colorScheme: skema,
    scaffoldBackgroundColor: Warna.latar,
    textTheme: const TextTheme(
      headlineSmall: TextStyle(
        fontSize: 24,
        height: 1.2,
        fontWeight: FontWeight.w700,
        color: Warna.teks,
      ),
      titleMedium: TextStyle(
        fontSize: 20,
        height: 1.2,
        fontWeight: FontWeight.w600,
        color: Warna.teks,
      ),
      bodyLarge: isi,
      bodyMedium: TextStyle(fontSize: 16, height: 1.4, color: Warna.teks),
      labelLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: Warna.teksSekunder,
      ),
      bodySmall: TextStyle(fontSize: 14, color: Warna.teksSekunder),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(Ukuran.tombol),
        textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        shape: const StadiumBorder(),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Warna.isian,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Ukuran.radiusIsian),
        borderSide: BorderSide.none,
      ),
      hintStyle: const TextStyle(fontSize: 18, color: Warna.teksSekunder),
    ),
    cardTheme: CardThemeData(
      color: Warna.permukaan,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Ukuran.radiusKartu),
        side: const BorderSide(color: Warna.garis),
      ),
    ),
  );
}
