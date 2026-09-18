# StrukBangunan — Rencana 4: Fondasi antarmuka dan alur inti kasir

> **Untuk pekerja agentik:** SUB-SKILL WAJIB: pakai `superpowers:subagent-driven-development` (disarankan) atau `superpowers:executing-plans` untuk mengerjakan rencana ini tugas per tugas. Setiap langkah memakai checkbox (`- [ ]`) untuk penanda kemajuan.

**Goal:** Membuat aplikasi yang benar-benar bisa dipakai berjualan: kasir mengetik barang, menambahkannya ke daftar, melihat pratinjau struk, menyimpan transaksinya, lalu mengirimkannya ke WhatsApp.

**Architecture:** Empat lapis yang sudah ada — `domain/`, `data/`, `output/` — diberi dua lapis di atasnya. `state/` memegang keranjang berjalan dan daftar favorit sebagai `ChangeNotifier`, dan tidak pernah menyentuh widget. `ui/` hanya membaca state dan memanggil metodenya. Seluruh angka, aturan struk, dan penyimpanan sudah selesai di lapisan bawah; rencana ini tidak menambah satu pun aturan bisnis baru.

**Tech Stack:** Flutter 3.38.5, Dart 3.10.4, Material 3, `provider` untuk pengikatan state ke widget. Tidak ada paket baru selain itu.

**Spec:** `docs/superpowers/specs/2026-09-17-strukbangunan-app-design.md` — terutama bagian 5 (alur layar), 7 (penanganan kesalahan), 8 (pengujian), dan 10 (kriteria keberhasilan).

**Design system:** `design-system/strukbangunan/MASTER.md` — mengikat untuk warna, ukuran huruf, jarak, sudut, dan komponen. Bila rencana ini dan design system berbeda, design system yang menang untuk hal visual; spec menang untuk perilaku.

**Rencana sebelumnya:** Rencana 1 (mesin struk), 2 (penyimpanan lokal), dan 3 (keluaran), ketiganya selesai dan tergabung ke `main`.

## Mengapa rencana ini dipecah dua

Rencana 4 semula berbunyi "Antarmuka & Rilis" — itu lima layar, pengelolaan state, alur izin, konfigurasi rilis, dan checklist manual dalam satu rencana. Terlalu besar untuk satu rangkaian review, dan sebagian besarnya tidak saling bergantung.

**Rencana 4 (dokumen ini)** menghasilkan aplikasi yang sudah bisa dipakai sungguhan untuk satu pekerjaan utuh: dari kasir mengetik sampai struk sampai ke WhatsApp pembeli. Itu sudah memenuhi FT-02, FT-03, FT-04, FT-06, FT-07, FT-08, dan FT-10.

**Rencana 5** menyusul dengan onboarding, Riwayat beserta rekap harian, Pengaturan, cadangkan/pulihkan, banner pengingat, ikon dan nama aplikasi, penandatanganan rilis, serta checklist rilis. Di sanalah `file_picker` dan `intl` masuk, dan di sanalah utang `_rakit` soal subtotal tersimpan ditutup — karena Riwayat-lah yang pertama kali mencetak ulang nota lama.

## Keputusan yang saya ambil saat menulis rencana ini

1. **Cetak thermal tidak muncul di antarmuka.** Pemilik proyek menundanya pada 18 Sep 2026; yang dibutuhkan sekarang hanya kirim WhatsApp. Seluruh lapisan printer tetap ada, teruji, dan tidak disentuh — layar Pratinjau hanya belum menampilkan tombolnya. **Biaya bila salah:** satu tombol yang harus ditambahkan kelak, bukan lapisan yang harus dibangun ulang.
2. **`provider` dipakai, bukan state management lain.** Spec bagian 9 sudah menyebutnya, dan kebutuhan di sini hanya "beri tahu widget bahwa keranjang berubah". **Biaya bila salah:** satu paket yang harus dicabut.
3. **`ProfilToko` untuk sementara dibaca dengan nilai bawaan bila belum pernah diisi.** Onboarding milik Rencana 5, tetapi layar Kasir sudah butuh nama toko untuk struk. Bila profil kosong, dipakai `ProfilToko(namaToko: 'TOKO BANGUNAN')`. **Biaya bila salah:** struk uji coba bernama generik sampai Rencana 5 masuk.
4. **Favorit dicatat setelah transaksi tersimpan, dipanggil berurutan.** `FavoritRepository.catatPemakaian` membuka transaksinya sendiri dan tidak punya varian `...Dalam`; memanggilnya dari dalam transaksi lain menggantung selamanya. **Biaya bila salah:** aplikasi menggantung — karena itu rencana ini memaksanya berurutan dan menguji urutannya.
5. **Kuantitas dibatasi dua angka desimal di titik masukan,** seperti tuntutan spec bagian 4, lewat `TextInputFormatter`. **Biaya bila salah:** angka di struk bisa berbeda dari angka yang dipakai menghitung.

## Global Constraints

- Flutter 3.38.5, Dart 3.10.4, SDK `^3.10.0`. Android saja. **Aplikasi tidak boleh punya izin `INTERNET`.**
- **Paket `google_fonts` haram di proyek ini** — ia mengunduh font saat dijalankan, dan aplikasi ini tidak punya izin jaringan. Font antarmuka memakai bawaan sistem.
- `lib/domain/` **tidak boleh diubah oleh rencana ini.** Bila sebuah tugas merasa perlu, itu temuan yang dilaporkan.
- `lib/data/` tidak boleh mengimpor `package:flutter/*`. `lib/state/` **boleh** (butuh `ChangeNotifier`), tetapi tidak boleh mengimpor `package:flutter/material.dart` — cukup `package:flutter/foundation.dart`.
- Semua nilai uang `int` rupiah penuh. Kuantitas `double`, maksimal dua angka desimal saat dimasukkan. Subtotal dibulatkan **tepat sekali**, di konstruktor `ItemBelanja`.
- **Tidak ada warna atau ukuran huruf mentah di dalam widget.** Semuanya lewat `Theme.of(context)` atau token di `lib/ui/tema.dart`.
- Area sentuh minimal **48 dp**, jarak antar target minimal **8**. Isian 18, teks tombol utama 20 — lantai dari spec bagian 5.
- **Aturan yang tidak bisa ditawar (spec bagian 7): transaksi disimpan ke basis data sebelum dikirim atau dicetak.**
- Gerbang mutu tiap tugas: `flutter test` hijau, `flutter analyze` bersih, `dart format --output=none --set-exit-if-changed .` keluar kode 0. **Keluaran test juga harus bersih.**
- Setiap tugas diakhiri satu commit, lalu push.

## Fakta yang sudah diverifikasi — percayai, jangan tebak ulang

| Fakta                                                                                                               | Sumber                                          |
| ------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------- |
| `ItemBelanja({required nama, required qty, required satuan, required hargaSatuan})` — `subtotal` dihitung di dalam   | inventaris kode 18 Sep 2026                     |
| `ItemBelanja` melempar `ArgumentError` untuk nama kosong, `qty <= 0`, harga negatif, dan harga > `maksRupiah`        | guard di `item_belanja.dart`                    |
| `maksRupiah = 999999999`; `formatRupiah(int)`, `parseRupiah(String) -> int?`, `formatJumlah(double)`                 | `uang.dart`                                     |
| `Transaksi({required nomorNota, required waktu, required items, bayar})`, punya `total` dan `kembali`                | `transaksi.dart`                                |
| `bangunStruk({required ProfilToko profil, required Transaksi transaksi}) -> ReceiptDocument`                         | `receipt_builder.dart`                          |
| `ProfilToko.lebarKolom` hanya pernah bernilai 32 atau 48                                                             | `profil_toko.dart`                              |
| `TransaksiRepository.simpan({required items, required waktu, int? bayar})` **membuka transaksinya sendiri**          | inventaris kode                                 |
| `FavoritRepository.catatPemakaian(nama, satuan, waktu)` **membuka transaksinya sendiri, tanpa varian `...Dalam`**    | inventaris kode                                 |
| `FavoritRepository.daftar({int batas = 40}) -> List<BahanFavorit>`; `BahanFavorit` punya `nama`, `satuanTerakhir`, `jumlahPakai`, `bawaan` | inventaris kode          |
| `DrafRepository.muat()`, `.simpan(List<ItemBelanja>)`, `.hapus()` — menelan data rusak diam-diam                     | inventaris kode                                 |
| `ambilPng(GlobalKey, {double pixelRatio = 3})` melempar `StateError` bila kunci tidak menunjuk `RepaintBoundary`     | `png_renderer.dart`                             |
| Di dalam `testWidgets`, `ambilPng` **wajib** dibungkus `tester.runAsync()`                                           | probe Rencana 3                                 |
| `ShareService(BerkasSementara, {PengirimBerkas? kirim})`, `bagikan({required nama, required isi, String? teks})`     | `share_service.dart`                            |
| `namaBerkasStruk(nomorNota, FormatKiriman) -> 'struk-0142.png'`                                                      | `share_service.dart`                            |
| `susunPdf({required Uint8List png, required int lebarKolom})`                                                        | `pdf_renderer.dart`                             |
| `bukaBasisdataUji()` di `test/bantuan_basisdata.dart` membuka `singleInstance: false` + `PRAGMA foreign_keys = ON`   | Rencana 2                                       |
| Setiap test yang membuka basis data wajib `addTearDown(db.close)`                                                    | Rencana 2                                       |
| Palet: latar `#F8FAFC`, kartu `#FFFFFF`, isian `#EAEFF3`, garis `#E2E8F0`, teks `#0F172A`, sekunder `#475569`, aksen `#2563EB`, merusak `#DC2626`, hijau tambah `#15803D` | `design-system/strukbangunan/MASTER.md` |

## Struktur berkas yang dihasilkan rencana ini

| Berkas                                | Tanggung jawab                                                     |
| ------------------------------------- | ------------------------------------------------------------------ |
| `lib/ui/tema.dart`                    | Token warna dan ukuran dari design system, dirakit jadi `ThemeData` |
| `lib/app/wadah.dart`                  | Membuka basis data dan prefs sekali, merakit seluruh repository     |
| `lib/state/keranjang_controller.dart` | Keranjang berjalan, draf otomatis, dan penyimpanan transaksi        |
| `lib/state/favorit_controller.dart`   | Daftar favorit dan penyembunyiannya                                 |
| `lib/state/pengirim_struk.dart`       | PNG/PDF dari widget struk lalu diserahkan ke share sheet            |
| `lib/ui/komponen/isian.dart`          | `TextInputFormatter` rupiah dan jumlah, plus kolom isian bertema    |
| `lib/ui/komponen/chip_satuan.dart`    | Pemilih satuan                                                      |
| `lib/ui/komponen/baris_item.dart`     | Satu baris barang di daftar belanja                                 |
| `lib/ui/kasir/layar_kasir.dart`       | Layar utama                                                         |
| `lib/ui/struk/layar_pratinjau.dart`   | Pratinjau, uang bayar, simpan, kirim WA                             |

Berkas yang **diubah**: `lib/main.dart`, `pubspec.yaml`.

---

### Task 1: Tema dari design system

**Files:**

- Modify: `pubspec.yaml`
- Create: `lib/ui/tema.dart`
- Test: `test/ui/tema_test.dart`

**Interfaces:**

- Produces:
  - `abstract final class Warna` dengan `latar`, `permukaan`, `isian`, `garis`, `teks`, `teksSekunder`, `aksen`, `merusak`, `tambah` — semuanya `static const Color`
  - `abstract final class Ukuran` dengan `static const double sentuh = 48`, `tombol = 56`, `isian = 56`, `radiusIsian = 16`, `radiusKartu = 20`, `jarak = 16`
  - `ThemeData temaTerang()`

- [ ] **Step 1: Tambahkan paket provider**

```bash
flutter pub add provider
```

Jangan mematok versinya manual di `pubspec.yaml`; biarkan `pub add` yang menuliskannya.

- [ ] **Step 2: Tulis test yang gagal**

Buat `test/ui/tema_test.dart`:

```dart
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

  test('tidak memakai font yang harus diunduh', () {
    // `google_fonts` mengunduh saat dijalankan, dan aplikasi ini tidak punya
    // izin INTERNET. Font apa pun yang dinamai di sini wajib sudah dibundel.
    expect(temaTerang().textTheme.bodyLarge!.fontFamily, isNull);
  });
}
```

- [ ] **Step 3: Jalankan test untuk memastikan gagal**

Jalankan: `flutter test test/ui/tema_test.dart`
Diharapkan: GAGAL dengan galat kompilasi — `lib/ui/tema.dart` belum ada.

- [ ] **Step 4: Tulis temanya**

Buat `lib/ui/tema.dart`:

```dart
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
```

- [ ] **Step 5: Jalankan test untuk memastikan lulus**

Jalankan: `flutter test test/ui/tema_test.dart`
Diharapkan: PASS, 4 test.

- [ ] **Step 6: Gerbang mutu dan commit**

```bash
flutter test
flutter analyze
dart format --output=none --set-exit-if-changed .
git add pubspec.yaml pubspec.lock lib/ui/tema.dart test/ui/tema_test.dart
git commit -m "feat(ui): tema dan token dari design system"
git push origin rencana-4-antarmuka
```

---

### Task 2: Wadah aplikasi dan titik masuk

**Files:**

- Create: `lib/app/wadah.dart`
- Modify: `lib/main.dart`
- Test: `test/app/wadah_test.dart`

**Interfaces:**

- Consumes: seluruh repository di `lib/data/`
- Produces:
  - `class Wadah` dengan field `Database db`, `SharedPreferences prefs`, dan getter `profil`, `pengaturan`, `draf`, `transaksi`, `favorit`
  - `Wadah(this.db, this.prefs)` — konstruktor positional, dipakai test
  - `static Future<Wadah> buat()` — jalur aplikasi sungguhan
  - `Future<void> siapkan()` — mengisi favorit bawaan bila tabelnya kosong

- [ ] **Step 1: Tulis test yang gagal**

Buat `test/app/wadah_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:struk_bangunan/app/wadah.dart';
import 'package:struk_bangunan/data/basisdata.dart';

import '../bantuan_basisdata.dart';

Future<Wadah> _siap() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  final db = await bukaBasisdataUji();
  await siapkanSkema(db);
  addTearDown(db.close);
  return Wadah(db, await SharedPreferences.getInstance());
}

void main() {
  test('menyiapkan favorit bawaan sekali saja', () async {
    final wadah = await _siap();

    await wadah.siapkan();
    final pertama = (await wadah.favorit.daftar()).length;
    await wadah.siapkan();

    expect(pertama, greaterThan(0));
    expect((await wadah.favorit.daftar()).length, pertama);
  });

  test('repository memakai basis data dan prefs yang sama', () async {
    final wadah = await _siap();
    await wadah.siapkan();

    await wadah.favorit.catatPemakaian('Semen', 'sak', DateTime(2026, 9, 18));
    final daftar = await wadah.favorit.daftar();

    expect(daftar.first.nama, 'Semen');
    expect(wadah.transaksi, isNotNull);
    expect(wadah.draf, isNotNull);
    expect(wadah.profil, isNotNull);
    expect(wadah.pengaturan, isNotNull);
  });
}
```

- [ ] **Step 2: Jalankan test untuk memastikan gagal**

Jalankan: `flutter test test/app/wadah_test.dart`
Diharapkan: GAGAL dengan galat kompilasi — `lib/app/wadah.dart` belum ada.

- [ ] **Step 3: Tulis wadahnya**

Buat `lib/app/wadah.dart`:

```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../data/basisdata.dart';
import '../data/draf_repository.dart';
import '../data/favorit_repository.dart';
import '../data/pengaturan_keluaran_repository.dart';
import '../data/profil_repository.dart';
import '../data/transaksi_repository.dart';

/// Satu-satunya tempat basis data dan preferensi dibuka, supaya tidak ada
/// layar yang diam-diam membuka koneksinya sendiri.
class Wadah {
  final Database db;
  final SharedPreferences prefs;

  Wadah(this.db, this.prefs);

  static Future<Wadah> buat() async {
    final db = await bukaBasisdata();
    final prefs = await SharedPreferences.getInstance();
    final wadah = Wadah(db, prefs);
    await wadah.siapkan();
    return wadah;
  }

  late final ProfilRepository profil = ProfilRepository(prefs);
  late final PengaturanKeluaranRepository pengaturan =
      PengaturanKeluaranRepository(prefs);
  late final DrafRepository draf = DrafRepository(prefs);
  late final TransaksiRepository transaksi = TransaksiRepository(db);
  late final FavoritRepository favorit = FavoritRepository(db);

  /// Aman dipanggil berulang: isian bawaan hanya masuk saat tabelnya kosong.
  Future<void> siapkan() => favorit.isiBawaanBilaKosong();
}
```

- [ ] **Step 4: Jalankan test untuk memastikan lulus**

Jalankan: `flutter test test/app/wadah_test.dart`
Diharapkan: PASS, 2 test.

- [ ] **Step 5: Ganti isi main.dart**

Ganti **seluruh** isi `lib/main.dart` dengan:

```dart
import 'package:flutter/material.dart';

import 'app/wadah.dart';
import 'ui/tema.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(AplikasiStruk(wadah: await Wadah.buat()));
}

class AplikasiStruk extends StatelessWidget {
  final Wadah wadah;

  const AplikasiStruk({super.key, required this.wadah});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StrukBangunan',
      debugShowCheckedModeBanner: false,
      theme: temaTerang(),
      home: const Scaffold(
        body: Center(child: Text('Layar Kasir menyusul di Tugas 6')),
      ),
    );
  }
}
```

Layar sementara itu diganti di Tugas 6. Ia ada supaya aplikasi tetap bisa dijalankan dan tema bisa dilihat di perangkat sejak sekarang.

- [ ] **Step 6: Gerbang mutu dan commit**

```bash
flutter test
flutter analyze
dart format --output=none --set-exit-if-changed .
git add lib/app/wadah.dart lib/main.dart test/app/wadah_test.dart
git commit -m "feat(app): wadah repository dan titik masuk aplikasi"
git push origin rencana-4-antarmuka
```

---

### Task 3: Keranjang berjalan

**Files:**

- Create: `lib/state/keranjang_controller.dart`
- Test: `test/state/keranjang_controller_test.dart`

**Interfaces:**

- Consumes: `DrafRepository`, `TransaksiRepository`, `FavoritRepository`, `ItemBelanja`, `Transaksi`
- Produces:
  - `class KeranjangController extends ChangeNotifier`
  - `KeranjangController({required DrafRepository draf, required TransaksiRepository transaksi, required FavoritRepository favorit})`
  - `List<ItemBelanja> get items`, `int get total`, `bool get kosong`
  - `Future<void> muatDraf()`, `Future<void> tambah(ItemBelanja)`, `Future<void> hapusPada(int)`, `Future<void> kosongkan()`
  - `Future<Transaksi> simpan({int? bayar, DateTime? waktu})`

- [ ] **Step 1: Tulis test yang gagal**

Buat `test/state/keranjang_controller_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:struk_bangunan/data/basisdata.dart';
import 'package:struk_bangunan/data/draf_repository.dart';
import 'package:struk_bangunan/data/favorit_repository.dart';
import 'package:struk_bangunan/data/transaksi_repository.dart';
import 'package:struk_bangunan/domain/item_belanja.dart';
import 'package:struk_bangunan/state/keranjang_controller.dart';

import '../bantuan_basisdata.dart';

ItemBelanja _semen({double qty = 3}) =>
    ItemBelanja(nama: 'Semen', qty: qty, satuan: 'sak', hargaSatuan: 65000);

Future<(Database, DrafRepository, KeranjangController)> _siap() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  final db = await bukaBasisdataUji();
  await siapkanSkema(db);
  addTearDown(db.close);
  final draf = DrafRepository(await SharedPreferences.getInstance());
  return (
    db,
    draf,
    KeranjangController(
      draf: draf,
      transaksi: TransaksiRepository(db),
      favorit: FavoritRepository(db),
    ),
  );
}

void main() {
  test('menambah item memperbarui total dan memberi tahu pendengar', () async {
    final (_, _, keranjang) = await _siap();
    var pemberitahuan = 0;
    keranjang.addListener(() => pemberitahuan++);

    await keranjang.tambah(_semen());

    expect(keranjang.items, hasLength(1));
    expect(keranjang.total, 195000);
    expect(keranjang.kosong, isFalse);
    expect(pemberitahuan, 1);
  });

  test('item yang ditambahkan ikut tersimpan sebagai draf', () async {
    final (_, draf, keranjang) = await _siap();

    await keranjang.tambah(_semen());

    expect(await draf.muat(), hasLength(1));
  });

  test('draf dipulihkan saat aplikasi dibuka kembali', () async {
    final (db, draf, _) = await _siap();
    await draf.simpan([_semen()]);

    final lain = KeranjangController(
      draf: draf,
      transaksi: TransaksiRepository(db),
      favorit: FavoritRepository(db),
    );
    await lain.muatDraf();

    expect(lain.items.single.nama, 'Semen');
    expect(lain.total, 195000);
  });

  test('menghapus satu item menyisakan sisanya', () async {
    final (_, _, keranjang) = await _siap();
    await keranjang.tambah(_semen());
    await keranjang.tambah(
      ItemBelanja(nama: 'Pasir', qty: 1, satuan: 'rit', hargaSatuan: 850000),
    );

    await keranjang.hapusPada(0);

    expect(keranjang.items.single.nama, 'Pasir');
    expect(keranjang.total, 850000);
  });

  test('mengosongkan keranjang juga menghapus drafnya', () async {
    final (_, draf, keranjang) = await _siap();
    await keranjang.tambah(_semen());

    await keranjang.kosongkan();

    expect(keranjang.kosong, isTrue);
    expect(await draf.muat(), isEmpty);
  });

  test('menyimpan menghasilkan nota dan mengosongkan keranjang', () async {
    final (db, draf, keranjang) = await _siap();
    await keranjang.tambah(_semen());

    final nota = await keranjang.simpan(bayar: 200000);

    expect(nota.nomorNota, '0001');
    expect(nota.total, 195000);
    expect(nota.kembali, 5000);
    expect(keranjang.kosong, isTrue);
    expect(await draf.muat(), isEmpty);
    expect(await TransaksiRepository(db).ambil('0001'), isNotNull);
  });

  test('menyimpan mencatat pemakaian favorit untuk setiap barang', () async {
    // `catatPemakaian` membuka transaksinya sendiri. Bila kelak ia dipanggil
    // dari dalam transaksi `simpan`, test ini tidak gagal — ia menggantung.
    final (db, _, keranjang) = await _siap();
    await keranjang.tambah(_semen());
    await keranjang.tambah(
      ItemBelanja(nama: 'Pasir', qty: 1, satuan: 'rit', hargaSatuan: 850000),
    );

    await keranjang.simpan();

    final favorit = await FavoritRepository(db).daftar();
    final nama = favorit.map((f) => f.nama).toList();
    expect(nama, containsAll(<String>['Semen', 'Pasir']));
  });

  test('keranjang kosong menolak disimpan tanpa memakai nomor nota', () async {
    final (db, _, keranjang) = await _siap();

    await expectLater(keranjang.simpan(), throwsArgumentError);

    final baris = await db.query(
      'meta',
      where: 'kunci = ?',
      whereArgs: ['nomor_nota_berikutnya'],
    );
    expect(baris.first['nilai'], '1');
  });
}
```

- [ ] **Step 2: Jalankan test untuk memastikan gagal**

Jalankan: `flutter test test/state/keranjang_controller_test.dart`
Diharapkan: GAGAL dengan galat kompilasi — berkasnya belum ada.

- [ ] **Step 3: Tulis controllernya**

Buat `lib/state/keranjang_controller.dart`:

```dart
import 'package:flutter/foundation.dart';

import '../data/draf_repository.dart';
import '../data/favorit_repository.dart';
import '../data/transaksi_repository.dart';
import '../domain/item_belanja.dart';
import '../domain/transaksi.dart';

/// Keranjang belanja yang sedang berjalan.
///
/// Setiap perubahan langsung ditulis sebagai draf: toko bangunan sering
/// terinterupsi, dan kehilangan keranjang setengah jadi adalah kegagalan
/// yang mahal.
class KeranjangController extends ChangeNotifier {
  final DrafRepository _draf;
  final TransaksiRepository _transaksi;
  final FavoritRepository _favorit;

  KeranjangController({
    required DrafRepository draf,
    required TransaksiRepository transaksi,
    required FavoritRepository favorit,
  }) : _draf = draf,
       _transaksi = transaksi,
       _favorit = favorit;

  final List<ItemBelanja> _items = [];

  List<ItemBelanja> get items => List.unmodifiable(_items);

  int get total => _items.fold(0, (jumlah, item) => jumlah + item.subtotal);

  bool get kosong => _items.isEmpty;

  Future<void> muatDraf() async {
    _items
      ..clear()
      ..addAll(await _draf.muat());
    notifyListeners();
  }

  Future<void> tambah(ItemBelanja item) async {
    _items.add(item);
    await _draf.simpan(_items);
    notifyListeners();
  }

  Future<void> hapusPada(int indeks) async {
    _items.removeAt(indeks);
    await _draf.simpan(_items);
    notifyListeners();
  }

  Future<void> kosongkan() async {
    _items.clear();
    await _draf.hapus();
    notifyListeners();
  }

  /// Menyimpan nota, lalu mencatat pemakaian favorit **berurutan sesudahnya**.
  ///
  /// `catatPemakaian` membuka transaksinya sendiri dan tidak punya varian
  /// yang menerima executor. Memanggilnya dari dalam transaksi `simpan` akan
  /// menggantung selamanya, bukan gagal.
  Future<Transaksi> simpan({int? bayar, DateTime? waktu}) async {
    final nota = await _transaksi.simpan(
      items: _items,
      waktu: waktu ?? DateTime.now(),
      bayar: bayar,
    );

    for (final item in nota.items) {
      await _favorit.catatPemakaian(item.nama, item.satuan, nota.waktu);
    }

    await kosongkan();
    return nota;
  }
}
```

- [ ] **Step 4: Jalankan test untuk memastikan lulus**

Jalankan: `flutter test test/state/keranjang_controller_test.dart`
Diharapkan: PASS, 8 test.

- [ ] **Step 5: Gerbang mutu dan commit**

```bash
flutter test
flutter analyze
dart format --output=none --set-exit-if-changed .
git add lib/state/keranjang_controller.dart test/state/keranjang_controller_test.dart
git commit -m "feat(state): keranjang berjalan dengan draf otomatis"
git push origin rencana-4-antarmuka
```

---

### Task 4: Daftar favorit

**Files:**

- Create: `lib/state/favorit_controller.dart`
- Test: `test/state/favorit_controller_test.dart`

**Interfaces:**

- Consumes: `FavoritRepository`, `BahanFavorit`
- Produces:
  - `class FavoritController extends ChangeNotifier`
  - `FavoritController(FavoritRepository repo)`
  - `List<BahanFavorit> get daftar`, `bool get sedangMemuat`
  - `Future<void> muat()`, `Future<void> sembunyikan(String nama)`

- [ ] **Step 1: Tulis test yang gagal**

Buat `test/state/favorit_controller_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:struk_bangunan/data/basisdata.dart';
import 'package:struk_bangunan/data/favorit_repository.dart';
import 'package:struk_bangunan/state/favorit_controller.dart';

import '../bantuan_basisdata.dart';

Future<(FavoritRepository, FavoritController)> _siap() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final db = await bukaBasisdataUji();
  await siapkanSkema(db);
  addTearDown(db.close);
  final repo = FavoritRepository(db);
  return (repo, FavoritController(repo));
}

void main() {
  test('sebelum dimuat daftarnya kosong dan ditandai memuat', () async {
    final (_, favorit) = await _siap();

    expect(favorit.daftar, isEmpty);
    expect(favorit.sedangMemuat, isTrue);
  });

  test('memuat mengisi daftar dan memberi tahu pendengar', () async {
    final (repo, favorit) = await _siap();
    await repo.isiBawaanBilaKosong();
    var pemberitahuan = 0;
    favorit.addListener(() => pemberitahuan++);

    await favorit.muat();

    expect(favorit.daftar, isNotEmpty);
    expect(favorit.sedangMemuat, isFalse);
    expect(pemberitahuan, greaterThanOrEqualTo(1));
  });

  test('yang paling sering dipakai berada di urutan pertama', () async {
    final (repo, favorit) = await _siap();
    await repo.catatPemakaian('Pasir', 'rit', DateTime(2026, 9, 17));
    await repo.catatPemakaian('Semen', 'sak', DateTime(2026, 9, 17));
    await repo.catatPemakaian('Semen', 'sak', DateTime(2026, 9, 18));

    await favorit.muat();

    expect(favorit.daftar.first.nama, 'Semen');
    expect(favorit.daftar.first.jumlahPakai, 2);
  });

  test('menyembunyikan membuang bahan dari daftar', () async {
    final (repo, favorit) = await _siap();
    await repo.catatPemakaian('Semen', 'sak', DateTime(2026, 9, 18));
    await favorit.muat();

    await favorit.sembunyikan('Semen');

    expect(favorit.daftar.where((f) => f.nama == 'Semen'), isEmpty);
  });
}
```

- [ ] **Step 2: Jalankan test untuk memastikan gagal**

Jalankan: `flutter test test/state/favorit_controller_test.dart`
Diharapkan: GAGAL dengan galat kompilasi — berkasnya belum ada.

- [ ] **Step 3: Tulis controllernya**

Buat `lib/state/favorit_controller.dart`:

```dart
import 'package:flutter/foundation.dart';

import '../data/favorit_repository.dart';

/// Baris favorit di layar Kasir. Urutannya sudah diputuskan repository:
/// paling sering dipakai lebih dulu, lalu yang paling baru dipakai.
class FavoritController extends ChangeNotifier {
  final FavoritRepository _repo;

  FavoritController(this._repo);

  List<BahanFavorit> _daftar = const [];
  bool _sedangMemuat = true;

  List<BahanFavorit> get daftar => List.unmodifiable(_daftar);

  bool get sedangMemuat => _sedangMemuat;

  Future<void> muat() async {
    _daftar = await _repo.daftar();
    _sedangMemuat = false;
    notifyListeners();
  }

  Future<void> sembunyikan(String nama) async {
    await _repo.sembunyikan(nama);
    await muat();
  }
}
```

- [ ] **Step 4: Jalankan test untuk memastikan lulus**

Jalankan: `flutter test test/state/favorit_controller_test.dart`
Diharapkan: PASS, 4 test.

- [ ] **Step 5: Gerbang mutu dan commit**

```bash
flutter test
flutter analyze
dart format --output=none --set-exit-if-changed .
git add lib/state/favorit_controller.dart test/state/favorit_controller_test.dart
git commit -m "feat(state): daftar favorit untuk layar kasir"
git push origin rencana-4-antarmuka
```

---

### Task 5: Isian yang mencegah kesalahan

Spec bagian 7: "Kesalahan dicegah, bukan ditegur." Harga memformat dirinya sendiri sambil diketik, nominal di atas batas ditolak saat diketik, dan kuantitas dibatasi dua angka desimal **di titik masukan** — bukan saat mencetak — supaya angka yang disimpan dan angka yang ditampilkan selalu sama.

**Files:**

- Create: `lib/ui/komponen/isian.dart`
- Create: `lib/ui/komponen/chip_satuan.dart`
- Test: `test/ui/komponen/isian_test.dart`

**Interfaces:**

- Consumes: `formatRupiah`, `parseRupiah`, `maksRupiah` dari `lib/domain/uang.dart`
- Produces:
  - `class FormatterRupiah extends TextInputFormatter`
  - `class FormatterJumlah extends TextInputFormatter`
  - `double? bacaJumlah(String teks)` — mengubah `1,5` menjadi `1.5`
  - `class KolomIsian extends StatelessWidget` dengan `label`, `controller`, `hint`, `angka`, `onChanged`, `autofocus`
  - `class ChipSatuan extends StatelessWidget` dengan `satuan`, `terpilih`, `onPilih`
  - `const satuanBawaan = <String>['sak', 'kg', 'batang', 'lembar', 'm', 'rit', 'pcs']`

- [ ] **Step 1: Tulis test yang gagal**

Buat `test/ui/komponen/isian_test.dart`:

```dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:struk_bangunan/ui/komponen/isian.dart';

TextEditingValue _nilai(String teks) =>
    TextEditingValue(text: teks, selection: TextSelection.collapsed(offset: teks.length));

String _ketik(TextInputFormatter formatter, String lama, String baru) =>
    formatter.formatEditUpdate(_nilai(lama), _nilai(baru)).text;

void main() {
  group('FormatterRupiah', () {
    final formatter = FormatterRupiah();

    test('memberi titik ribuan sambil diketik', () {
      expect(_ketik(formatter, '6', '65'), '65');
      expect(_ketik(formatter, '65', '650'), '650');
      expect(_ketik(formatter, '650', '6500'), '6.500');
      expect(_ketik(formatter, '6.500', '65000'), '65.000');
    });

    test('mengabaikan karakter selain angka', () {
      expect(_ketik(formatter, '65.000', '65.000a'), '65.000');
    });

    test('menolak nominal di atas batas dengan menahan nilai lama', () {
      expect(_ketik(formatter, '999.999.999', '9999999991'), '999.999.999');
    });

    test('mengosongkan kolom tetap boleh', () {
      expect(_ketik(formatter, '65.000', ''), '');
    });

    test('nol diizinkan karena barang bonus itu nyata', () {
      expect(_ketik(formatter, '', '0'), '0');
    });
  });

  group('FormatterJumlah', () {
    final formatter = FormatterJumlah();

    test('menerima bilangan bulat dan pecahan dua angka', () {
      expect(_ketik(formatter, '1', '1,5'), '1,5');
      expect(_ketik(formatter, '1,5', '1,55'), '1,55');
    });

    test('menolak angka desimal ketiga', () {
      expect(_ketik(formatter, '1,55', '1,555'), '1,55');
    });

    test('menolak koma kedua', () {
      expect(_ketik(formatter, '1,5', '1,5,'), '1,5');
    });

    test('menolak titik sebagai pemisah desimal', () {
      expect(_ketik(formatter, '1', '1.'), '1');
    });
  });

  group('bacaJumlah', () {
    test('membaca koma sebagai pemisah desimal', () {
      expect(bacaJumlah('1,5'), 1.5);
      expect(bacaJumlah('3'), 3);
    });

    test('mengembalikan null untuk isian yang tidak sah', () {
      expect(bacaJumlah(''), isNull);
      expect(bacaJumlah('abc'), isNull);
    });
  });
}
```

- [ ] **Step 2: Jalankan test untuk memastikan gagal**

Jalankan: `flutter test test/ui/komponen/isian_test.dart`
Diharapkan: GAGAL dengan galat kompilasi — `lib/ui/komponen/isian.dart` belum ada.

- [ ] **Step 3: Tulis isiannya**

Buat `lib/ui/komponen/isian.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/uang.dart';
import '../tema.dart';

/// Memformat nominal menjadi `65.000` sambil diketik, dan menolak nominal di
/// atas batas pada saat pengetikan — bukan dengan pesan galat setelahnya.
class FormatterRupiah extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue lama,
    TextEditingValue baru,
  ) {
    final angka = baru.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (angka.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final nilai = int.tryParse(angka);
    if (nilai == null || nilai > maksRupiah) return lama;

    final teks = formatRupiah(nilai);
    return TextEditingValue(
      text: teks,
      selection: TextSelection.collapsed(offset: teks.length),
    );
  }
}

/// Membatasi kuantitas pada dua angka di belakang koma **saat dimasukkan**.
///
/// Spec bagian 4: tanpa batas ini, `0,333` tampil sebagai `0,33` sementara
/// subtotalnya dihitung dari `0,333`, dan pembeli berhak mempertanyakannya.
class FormatterJumlah extends TextInputFormatter {
  static final _sah = RegExp(r'^\d{0,6}(,\d{0,2})?$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue lama,
    TextEditingValue baru,
  ) => _sah.hasMatch(baru.text) ? baru : lama;
}

/// `1,5` menjadi `1.5`. Mengembalikan null bila isiannya belum sah.
double? bacaJumlah(String teks) => double.tryParse(teks.replaceAll(',', '.'));

class KolomIsian extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool angka;
  final bool autofocus;
  final List<TextInputFormatter>? formatters;
  final ValueChanged<String>? onChanged;

  const KolomIsian({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.angka = false,
    this.autofocus = false,
    this.formatters,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label tetap terlihat setelah kolom terisi; placeholder saja akan
        // menghilang justru saat pengguna paling butuh tahu ini kolom apa.
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        SizedBox(
          height: Ukuran.isian,
          child: TextField(
            controller: controller,
            autofocus: autofocus,
            onChanged: onChanged,
            style: Theme.of(context).textTheme.bodyLarge,
            keyboardType: angka
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            inputFormatters: formatters,
            decoration: InputDecoration(hintText: hint),
          ),
        ),
      ],
    );
  }
}
```

Buat `lib/ui/komponen/chip_satuan.dart`:

```dart
import 'package:flutter/material.dart';

import '../tema.dart';

const satuanBawaan = <String>[
  'sak',
  'kg',
  'batang',
  'lembar',
  'm',
  'rit',
  'pcs',
];

class ChipSatuan extends StatelessWidget {
  final String satuan;
  final bool terpilih;
  final VoidCallback onPilih;

  const ChipSatuan({
    super.key,
    required this.satuan,
    required this.terpilih,
    required this.onPilih,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: Ukuran.sentuh,
      child: Material(
        color: terpilih ? Warna.aksen : Warna.isian,
        borderRadius: BorderRadius.circular(Ukuran.radiusIsian),
        child: InkWell(
          onTap: onPilih,
          borderRadius: BorderRadius.circular(Ukuran.radiusIsian),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text(
                satuan,
                style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                  color: terpilih ? Colors.white : Warna.teks,
                  fontWeight: terpilih ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Jalankan test untuk memastikan lulus**

Jalankan: `flutter test test/ui/komponen/isian_test.dart`
Diharapkan: PASS, 11 test.

- [ ] **Step 5: Gerbang mutu dan commit**

```bash
flutter test
flutter analyze
dart format --output=none --set-exit-if-changed .
git add lib/ui/komponen/isian.dart lib/ui/komponen/chip_satuan.dart test/ui/komponen/isian_test.dart
git commit -m "feat(ui): isian rupiah dan kuantitas yang mencegah salah ketik"
git push origin rencana-4-antarmuka
```

---

### Task 6: Layar Kasir

**Files:**

- Create: `lib/ui/komponen/baris_item.dart`
- Create: `lib/ui/kasir/layar_kasir.dart`
- Modify: `lib/main.dart`
- Test: `test/ui/kasir/layar_kasir_test.dart`

**Interfaces:**

- Consumes: `KeranjangController`, `FavoritController`, `KolomIsian`, `ChipSatuan`, `FormatterRupiah`, `FormatterJumlah`, `bacaJumlah`
- Produces:
  - `class BarisItem extends StatelessWidget` dengan `item`, `indeks`, `onHapus`
  - `class LayarKasir extends StatefulWidget` dengan satu parameter `VoidCallback onKirim`

- [ ] **Step 1: Tulis test yang gagal**

Buat `test/ui/kasir/layar_kasir_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:struk_bangunan/data/basisdata.dart';
import 'package:struk_bangunan/data/draf_repository.dart';
import 'package:struk_bangunan/data/favorit_repository.dart';
import 'package:struk_bangunan/data/transaksi_repository.dart';
import 'package:struk_bangunan/domain/item_belanja.dart';
import 'package:struk_bangunan/state/favorit_controller.dart';
import 'package:struk_bangunan/state/keranjang_controller.dart';
import 'package:struk_bangunan/ui/kasir/layar_kasir.dart';
import 'package:struk_bangunan/ui/tema.dart';

import '../../bantuan_basisdata.dart';

Future<KeranjangController> _pasang(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final db = await bukaBasisdataUji();
  await siapkanSkema(db);
  addTearDown(db.close);
  final prefs = await SharedPreferences.getInstance();
  final keranjang = KeranjangController(
    draf: DrafRepository(prefs),
    transaksi: TransaksiRepository(db),
    favorit: FavoritRepository(db),
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: keranjang),
        ChangeNotifierProvider.value(value: FavoritController(FavoritRepository(db))),
      ],
      child: MaterialApp(
        theme: temaTerang(),
        home: LayarKasir(onKirim: () {}),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return keranjang;
}

Future<void> _isiForm(
  WidgetTester tester, {
  String nama = 'Semen',
  String jumlah = '3',
  String harga = '65000',
}) async {
  await tester.enterText(find.byKey(const Key('kolom-nama')), nama);
  await tester.enterText(find.byKey(const Key('kolom-jumlah')), jumlah);
  await tester.enterText(find.byKey(const Key('kolom-harga')), harga);
  await tester.pump();
}

String _isiKolom(WidgetTester tester, String kunci) => tester
    .widget<TextField>(
      find.descendant(
        of: find.byKey(Key(kunci)),
        matching: find.byType(TextField),
      ),
    )
    .controller!
    .text;

void main() {
  testWidgets('tombol tambah nonaktif selama nama bahan kosong', (tester) async {
    await _pasang(tester);

    final tombol = tester.widget<FilledButton>(
      find.byKey(const Key('tombol-tambah')),
    );
    expect(tombol.onPressed, isNull);

    await _isiForm(tester);
    final sesudah = tester.widget<FilledButton>(
      find.byKey(const Key('tombol-tambah')),
    );
    expect(sesudah.onPressed, isNotNull);
  });

  testWidgets('menambah item memperbarui daftar dan total', (tester) async {
    final keranjang = await _pasang(tester);
    await _isiForm(tester);

    await tester.tap(find.byKey(const Key('tombol-tambah')));
    await tester.pumpAndSettle();

    expect(keranjang.items, hasLength(1));
    expect(keranjang.total, 195000);
    expect(find.text('Semen'), findsOneWidget);
    expect(find.text('Rp 195.000'), findsOneWidget);
  });

  testWidgets('kolom dikosongkan setelah item masuk', (tester) async {
    await _pasang(tester);
    await _isiForm(tester);

    await tester.tap(find.byKey(const Key('tombol-tambah')));
    await tester.pumpAndSettle();

    expect(_isiKolom(tester, 'kolom-nama'), isEmpty);
    expect(_isiKolom(tester, 'kolom-jumlah'), '1');
  });

  testWidgets('tombol kurang dan tambah mengubah jumlah', (tester) async {
    await _pasang(tester);

    await tester.tap(find.byKey(const Key('jumlah-tambah')));
    await tester.pump();
    expect(_isiKolom(tester, 'kolom-jumlah'), '2');

    await tester.tap(find.byKey(const Key('jumlah-kurang')));
    await tester.pump();
    expect(_isiKolom(tester, 'kolom-jumlah'), '1');

    // Tidak pernah turun ke nol: jumlah nol ditolak konstruktor ItemBelanja,
    // dan kasir tidak boleh menemui galat untuk sesuatu yang bisa dicegah.
    await tester.tap(find.byKey(const Key('jumlah-kurang')));
    await tester.pump();
    expect(_isiKolom(tester, 'kolom-jumlah'), '1');
  });

  testWidgets('menghapus item meminta konfirmasi lebih dulu', (tester) async {
    final keranjang = await _pasang(tester);
    await keranjang.tambah(
      ItemBelanja(nama: 'Semen', qty: 3, satuan: 'sak', hargaSatuan: 65000),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('hapus-0')));
    await tester.pumpAndSettle();

    expect(find.text('Hapus barang ini?'), findsOneWidget);
    expect(keranjang.items, hasLength(1));

    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    expect(keranjang.items, isEmpty);
  });

  testWidgets('membatalkan konfirmasi menyisakan itemnya', (tester) async {
    final keranjang = await _pasang(tester);
    await keranjang.tambah(
      ItemBelanja(nama: 'Semen', qty: 3, satuan: 'sak', hargaSatuan: 65000),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('hapus-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    expect(keranjang.items, hasLength(1));
  });

  testWidgets('tombol kirim nonaktif saat keranjang kosong', (tester) async {
    final keranjang = await _pasang(tester);

    final tombol = tester.widget<FilledButton>(
      find.byKey(const Key('tombol-kirim')),
    );
    expect(tombol.onPressed, isNull);

    await keranjang.tambah(
      ItemBelanja(nama: 'Semen', qty: 3, satuan: 'sak', hargaSatuan: 65000),
    );
    await tester.pumpAndSettle();

    final sesudah = tester.widget<FilledButton>(
      find.byKey(const Key('tombol-kirim')),
    );
    expect(sesudah.onPressed, isNotNull);
  });

  testWidgets('menekan favorit mengisi nama dan satuannya', (tester) async {
    await _pasang(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Semen').first);
    await tester.pumpAndSettle();

    expect(_isiKolom(tester, 'kolom-nama'), 'Semen');
  });
}
```

- [ ] **Step 2: Jalankan test untuk memastikan gagal**

Jalankan: `flutter test test/ui/kasir/layar_kasir_test.dart`
Diharapkan: GAGAL dengan galat kompilasi — `layar_kasir.dart` belum ada.

- [ ] **Step 3: Tulis baris item**

Buat `lib/ui/komponen/baris_item.dart`:

```dart
import 'package:flutter/material.dart';

import '../../domain/item_belanja.dart';
import '../../domain/uang.dart';
import '../tema.dart';

/// Satu barang di daftar belanja.
///
/// Tombol hapus berukuran penuh di ujung kanan, dan tidak ada geser-untuk-
/// hapus: gerakan itu terlalu mudah terpicu tidak sengaja dan jarang
/// ditemukan pengguna lansia.
class BarisItem extends StatelessWidget {
  final ItemBelanja item;
  final int indeks;
  final VoidCallback onHapus;

  const BarisItem({
    super.key,
    required this.item,
    required this.indeks,
    required this.onHapus,
  });

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;

    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Warna.garis)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.nama, style: teks.bodyLarge),
                const SizedBox(height: 4),
                Text(
                  '${formatJumlah(item.qty)} ${item.satuan} '
                  'x ${formatRupiah(item.hargaSatuan)}',
                  style: teks.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatRupiah(item.subtotal),
            style: teks.bodyLarge!.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: Ukuran.sentuh,
            height: Ukuran.sentuh,
            child: IconButton(
              key: Key('hapus-$indeks'),
              onPressed: onHapus,
              tooltip: 'Hapus ${item.nama}',
              icon: const Icon(Icons.delete_outline, color: Warna.merusak),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Tulis layar kasir**

Buat `lib/ui/kasir/layar_kasir.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/item_belanja.dart';
import '../../domain/uang.dart';
import '../../state/favorit_controller.dart';
import '../../state/keranjang_controller.dart';
import '../komponen/baris_item.dart';
import '../komponen/chip_satuan.dart';
import '../komponen/isian.dart';
import '../tema.dart';

class LayarKasir extends StatefulWidget {
  /// Dipanggil saat kasir menekan tombol kirim. Layar ini tidak tahu apa pun
  /// tentang tujuan berikutnya — pemanggilnya yang memutuskan.
  final VoidCallback onKirim;

  const LayarKasir({super.key, required this.onKirim});

  @override
  State<LayarKasir> createState() => _LayarKasirState();
}

class _LayarKasirState extends State<LayarKasir> {
  final _nama = TextEditingController();
  final _jumlah = TextEditingController(text: '1');
  final _harga = TextEditingController();
  final _fokusHarga = FocusNode();
  String _satuan = satuanBawaan.first;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<KeranjangController>().muatDraf();
      context.read<FavoritController>().muat();
    });
  }

  @override
  void dispose() {
    _nama.dispose();
    _jumlah.dispose();
    _harga.dispose();
    _fokusHarga.dispose();
    super.dispose();
  }

  bool get _bolehTambah => _nama.text.trim().isNotEmpty;

  /// Spec bagian 5: jumlah terisi otomatis 1, dengan tombol besar di kiri dan
  /// kanannya. Tidak pernah turun ke nol — `ItemBelanja` menolaknya, dan
  /// kesalahan yang bisa dicegah tidak boleh jadi pesan galat.
  void _ubahJumlah(int langkah) {
    final sekarang = bacaJumlah(_jumlah.text) ?? 1;
    final baru = (sekarang + langkah).clamp(1, 999999);
    setState(() => _jumlah.text = formatJumlah(baru.toDouble()));
  }

  Future<void> _tambah() async {
    final qty = bacaJumlah(_jumlah.text) ?? 1;
    final harga = parseRupiah(_harga.text) ?? 0;
    if (qty <= 0) return;

    await context.read<KeranjangController>().tambah(
      ItemBelanja(
        nama: _nama.text.trim(),
        qty: qty,
        satuan: _satuan,
        hargaSatuan: harga,
      ),
    );

    setState(() {
      _nama.clear();
      _jumlah.text = '1';
      _harga.clear();
    });
  }

  Future<void> _tanyaHapus(int indeks) async {
    final setuju = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Hapus barang ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Hapus', style: TextStyle(color: Warna.merusak)),
          ),
        ],
      ),
    );

    if (setuju ?? false) {
      if (!mounted) return;
      await context.read<KeranjangController>().hapusPada(indeks);
    }
  }

  void _pakaiFavorit(String nama, String satuan) {
    setState(() {
      _nama.text = nama;
      if (satuan.isNotEmpty) _satuan = satuan;
    });
    _fokusHarga.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final keranjang = context.watch<KeranjangController>();
    final favorit = context.watch<FavoritController>();
    final keyboardTerbuka = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Kasir')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(Ukuran.jarak),
            child: Column(
              children: [
                KolomIsian(
                  key: const Key('kolom-nama'),
                  label: 'Nama bahan',
                  controller: _nama,
                  hint: 'Semen, pasir, paku...',
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _TombolJumlah(
                      key: const Key('jumlah-kurang'),
                      ikon: Icons.remove,
                      onTekan: () => _ubahJumlah(-1),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: KolomIsian(
                        key: const Key('kolom-jumlah'),
                        label: 'Jumlah',
                        controller: _jumlah,
                        angka: true,
                        formatters: [FormatterJumlah()],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _TombolJumlah(
                      key: const Key('jumlah-tambah'),
                      ikon: Icons.add,
                      onTekan: () => _ubahJumlah(1),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                KolomIsian(
                  key: const Key('kolom-harga'),
                  label: 'Harga satuan',
                  controller: _harga,
                  hint: '0',
                  angka: true,
                  formatters: [FormatterRupiah()],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: Ukuran.sentuh,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: satuanBawaan.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => ChipSatuan(
                      satuan: satuanBawaan[i],
                      terpilih: satuanBawaan[i] == _satuan,
                      onPilih: () => setState(() => _satuan = satuanBawaan[i]),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('tombol-tambah'),
                  onPressed: _bolehTambah ? _tambah : null,
                  style: FilledButton.styleFrom(backgroundColor: Warna.tambah),
                  child: const Text('+ TAMBAH KE DAFTAR'),
                ),
              ],
            ),
          ),
          if (!favorit.sedangMemuat && favorit.daftar.isNotEmpty)
            SizedBox(
              height: Ukuran.sentuh + 16,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: Ukuran.jarak),
                itemCount: favorit.daftar.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final bahan = favorit.daftar[i];
                  return ChipSatuan(
                    satuan: bahan.nama,
                    terpilih: false,
                    onPilih: () =>
                        _pakaiFavorit(bahan.nama, bahan.satuanTerakhir),
                  );
                },
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: keranjang.items.length,
              itemBuilder: (_, i) => BarisItem(
                key: Key('baris-$i'),
                item: keranjang.items[i],
                indeks: i,
                onHapus: () => _tanyaHapus(i),
              ),
            ),
          ),
          if (!keyboardTerbuka)
            Container(
              padding: const EdgeInsets.all(Ukuran.jarak),
              decoration: const BoxDecoration(
                color: Warna.permukaan,
                border: Border(top: BorderSide(color: Warna.garis)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TOTAL',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'Rp ${formatRupiah(keranjang.total)}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Warna.teks,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    key: const Key('tombol-kirim'),
                    onPressed: keranjang.kosong ? null : widget.onKirim,
                    child: const Text('KIRIM & CETAK STRUK'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Tombol besar pengapit kolom jumlah. Lebarnya mengikuti lantai area sentuh,
/// bukan ukuran ikonnya.
class _TombolJumlah extends StatelessWidget {
  final IconData ikon;
  final VoidCallback onTekan;

  const _TombolJumlah({super.key, required this.ikon, required this.onTekan});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 0),
      child: SizedBox(
        width: Ukuran.tombol,
        height: Ukuran.isian,
        child: Material(
          color: Warna.isian,
          borderRadius: BorderRadius.circular(Ukuran.radiusIsian),
          child: InkWell(
            onTap: onTekan,
            borderRadius: BorderRadius.circular(Ukuran.radiusIsian),
            child: Icon(ikon, size: 28, color: Warna.teks),
          ),
        ),
      ),
    );
  }
}
```

Tombol kirim memanggil `widget.onKirim`, dan Tugas 7 yang mengisinya dengan perpindahan ke layar Pratinjau. Konstruktor `LayarKasir` **tidak akan berubah lagi** setelah tugas ini, sehingga test pada Step 1 tidak perlu ditulis ulang.

- [ ] **Step 5: Sambungkan ke titik masuk**

Di `lib/main.dart`, ganti `home:` dengan pohon provider:

```dart
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => KeranjangController(
              draf: wadah.draf,
              transaksi: wadah.transaksi,
              favorit: wadah.favorit,
            ),
          ),
          ChangeNotifierProvider(
            create: (_) => FavoritController(wadah.favorit),
          ),
        ],
        child: LayarKasir(onKirim: () {}),
      ),
```

Tambahkan impornya:

```dart
import 'package:provider/provider.dart';

import 'state/favorit_controller.dart';
import 'state/keranjang_controller.dart';
import 'ui/kasir/layar_kasir.dart';
```

- [ ] **Step 6: Jalankan test untuk memastikan lulus**

Jalankan: `flutter test test/ui/kasir/layar_kasir_test.dart`
Diharapkan: PASS, 8 test.

- [ ] **Step 7: Gerbang mutu dan commit**

```bash
flutter test
flutter analyze
dart format --output=none --set-exit-if-changed .
git add lib/ui/komponen/baris_item.dart lib/ui/kasir/layar_kasir.dart lib/main.dart test/ui/kasir/layar_kasir_test.dart
git commit -m "feat(ui): layar kasir dengan favorit dan daftar belanja"
git push origin rencana-4-antarmuka
```

---

### Task 7: Pratinjau struk dan kirim WhatsApp

**Aturan yang tidak bisa ditawar:** transaksi disimpan ke basis data **sebelum** berkas dibuat atau dibagikan. Urutan terbalik berarti satu kegagalan berbagi menghapus penjualan yang sudah terjadi.

**Files:**

- Create: `lib/state/pengirim_struk.dart`
- Create: `lib/ui/struk/layar_pratinjau.dart`
- Modify: `lib/main.dart`
- Test: `test/state/pengirim_struk_test.dart`
- Test: `test/ui/struk/layar_pratinjau_test.dart`

**Interfaces:**

- Consumes: `ambilPng`, `susunPdf`, `ShareService`, `namaBerkasStruk`, `PengaturanKeluaranRepository`, `bangunStruk`, `ReceiptWidget`, `KeranjangController`
- Produces:
  - `abstract interface class PengirimStrukKontrak` dengan satu metode `Future<void> kirim({required GlobalKey kunciBoundary, required Transaksi nota, required int lebarKolom})`
  - `class PengirimStruk implements PengirimStrukKontrak` dengan `PengirimStruk(PengaturanKeluaranRepository pengaturan, ShareService berbagi)`
  - `class LayarPratinjau extends StatefulWidget` dengan `ProfilToko profil`, `KeranjangController keranjang`, `PengirimStrukKontrak pengirim`

**Mengapa ada kontrak terpisah.** `ambilPng` menuntut `tester.runAsync()`, sedangkan `tester.pumpAndSettle()` **tidak boleh** dipanggil di dalam `runAsync`. Artinya satu widget test tidak bisa sekaligus menekan tombol dan menjalankan penangkapan PNG sungguhan. Kontrak ini memisahkan keduanya: `pengirim_struk_test.dart` menguji jalur PNG/PDF sungguhan tanpa menekan tombol, dan `layar_pratinjau_test.dart` menguji urutan simpan-lalu-bagikan dengan pengirim palsu.

- [ ] **Step 1: Tulis test pengirim yang gagal**

Buat `test/state/pengirim_struk_test.dart`:

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:struk_bangunan/data/pengaturan_keluaran_repository.dart';
import 'package:struk_bangunan/domain/item_belanja.dart';
import 'package:struk_bangunan/domain/receipt/receipt_document.dart';
import 'package:struk_bangunan/domain/transaksi.dart';
import 'package:struk_bangunan/output/berkas_sementara.dart';
import 'package:struk_bangunan/output/receipt_widget.dart';
import 'package:struk_bangunan/output/share_service.dart';
import 'package:struk_bangunan/state/pengirim_struk.dart';

Transaksi _nota() => Transaksi(
  nomorNota: '0142',
  waktu: DateTime(2026, 9, 18, 14, 30),
  items: [
    ItemBelanja(nama: 'Semen', qty: 3, satuan: 'sak', hargaSatuan: 65000),
  ],
);

Future<GlobalKey> _pasangStruk(WidgetTester tester) async {
  final kunci = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: RepaintBoundary(
          key: kunci,
          child: ReceiptWidget(
            dokumen: ReceiptDocument(
              lebar: 32,
              baris: const [BarisStruk('TOTAL               Rp   195.000')],
            ),
          ),
        ),
      ),
    ),
  );
  return kunci;
}

void main() {
  testWidgets('mengirim PNG dengan nama berkas dari nomor nota', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final folder = await Directory.systemTemp.createTemp('struk_kirim');
    addTearDown(() => folder.delete(recursive: true));

    String? jalur;
    final pengirim = PengirimStruk(
      PengaturanKeluaranRepository(await SharedPreferences.getInstance()),
      ShareService(
        BerkasSementara(Directory(p.join(folder.path, 'struk'))),
        kirim: (berkas, _) async => jalur = berkas,
      ),
    );
    final kunci = await _pasangStruk(tester);

    await tester.runAsync(() async {
      await pengirim.kirim(kunciBoundary: kunci, nota: _nota(), lebarKolom: 32);
    });

    expect(p.basename(jalur!), 'struk-0142.png');
    expect(await File(jalur!).readAsBytes(), isNotEmpty);
  });

  testWidgets('setelan PDF menghasilkan berkas PDF', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final folder = await Directory.systemTemp.createTemp('struk_kirim');
    addTearDown(() => folder.delete(recursive: true));

    final pengaturan = PengaturanKeluaranRepository(
      await SharedPreferences.getInstance(),
    );
    await pengaturan.simpan(
      const PengaturanKeluaran(formatKiriman: FormatKiriman.pdf),
    );

    String? jalur;
    final pengirim = PengirimStruk(
      pengaturan,
      ShareService(
        BerkasSementara(Directory(p.join(folder.path, 'struk'))),
        kirim: (berkas, _) async => jalur = berkas,
      ),
    );
    final kunci = await _pasangStruk(tester);

    await tester.runAsync(() async {
      await pengirim.kirim(kunciBoundary: kunci, nota: _nota(), lebarKolom: 32);
    });

    expect(p.basename(jalur!), 'struk-0142.pdf');
    final isi = await File(jalur!).readAsBytes();
    expect(String.fromCharCodes(isi.take(5)), '%PDF-');
  });
}
```

- [ ] **Step 2: Tulis test layar pratinjau yang gagal**

Buat `test/ui/struk/layar_pratinjau_test.dart`:

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:struk_bangunan/data/basisdata.dart';
import 'package:struk_bangunan/data/draf_repository.dart';
import 'package:struk_bangunan/data/favorit_repository.dart';
import 'package:struk_bangunan/data/transaksi_repository.dart';
import 'package:struk_bangunan/domain/item_belanja.dart';
import 'package:struk_bangunan/domain/profil_toko.dart';
import 'package:struk_bangunan/domain/transaksi.dart';
import 'package:struk_bangunan/state/keranjang_controller.dart';
import 'package:struk_bangunan/state/pengirim_struk.dart';
import 'package:struk_bangunan/ui/struk/layar_pratinjau.dart';
import 'package:struk_bangunan/ui/tema.dart';

import '../../bantuan_basisdata.dart';

/// Pengirim palsu yang mencatat kapan ia dipanggil.
///
/// Jalur PNG/PDF sungguhan diuji terpisah di `pengirim_struk_test.dart`:
/// `ambilPng` menuntut `tester.runAsync()`, sementara `pumpAndSettle` tidak
/// boleh dipanggil dari dalamnya, jadi satu test tidak bisa melakukan
/// keduanya sekaligus.
class _PengirimPalsu implements PengirimStrukKontrak {
  final List<String> jejak = [];
  String? nomorNotaTerkirim;

  @override
  Future<void> kirim({
    required GlobalKey kunciBoundary,
    required Transaksi nota,
    required int lebarKolom,
  }) async {
    jejak.add('bagikan');
    nomorNotaTerkirim = nota.nomorNota;
  }
}

void main() {
  testWidgets('menyimpan lebih dulu, baru membagikan', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = await bukaBasisdataUji();
    await siapkanSkema(db);
    addTearDown(db.close);
    final prefs = await SharedPreferences.getInstance();

    final keranjang = KeranjangController(
      draf: DrafRepository(prefs),
      transaksi: TransaksiRepository(db),
      favorit: FavoritRepository(db),
    );
    await keranjang.tambah(
      ItemBelanja(nama: 'Semen', qty: 3, satuan: 'sak', hargaSatuan: 65000),
    );

    final pengirim = _PengirimPalsu();

    await tester.pumpWidget(
      MaterialApp(
        theme: temaTerang(),
        home: LayarPratinjau(
          profil: const ProfilToko(namaToko: 'TB. SINAR BANGUNAN'),
          keranjang: keranjang,
          pengirim: pengirim,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tombol-kirim-wa')));
    await tester.pumpAndSettle();

    // Nota sudah ada di basis data, dan nomor yang dikirim adalah nomor yang
    // tersimpan — bukti bahwa penyimpanan mendahului pembagian.
    expect(
      await TransaksiRepository(db).ambil('0001'),
      isNotNull,
      reason: 'transaksi wajib tersimpan lebih dulu',
    );
    expect(pengirim.jejak, ['bagikan']);
    expect(pengirim.nomorNotaTerkirim, '0001');
    expect(keranjang.kosong, isTrue);
  });

  testWidgets('menyimpan saja tidak membagikan apa pun', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = await bukaBasisdataUji();
    await siapkanSkema(db);
    addTearDown(db.close);
    final prefs = await SharedPreferences.getInstance();

    final pengirim = _PengirimPalsu();
    final keranjang = KeranjangController(
      draf: DrafRepository(prefs),
      transaksi: TransaksiRepository(db),
      favorit: FavoritRepository(db),
    );
    await keranjang.tambah(
      ItemBelanja(nama: 'Semen', qty: 3, satuan: 'sak', hargaSatuan: 65000),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: temaTerang(),
        home: LayarPratinjau(
          profil: const ProfilToko(namaToko: 'TB. SINAR BANGUNAN'),
          keranjang: keranjang,
          pengirim: pengirim,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tombol-simpan')));
    await tester.pumpAndSettle();

    expect(await TransaksiRepository(db).ambil('0001'), isNotNull);
    expect(pengirim.jejak, isEmpty);
    expect(find.textContaining('Tersimpan #0001'), findsOneWidget);
  });

  testWidgets('uang bayar menampilkan kembalian di struk', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = await bukaBasisdataUji();
    await siapkanSkema(db);
    addTearDown(db.close);
    final prefs = await SharedPreferences.getInstance();

    final keranjang = KeranjangController(
      draf: DrafRepository(prefs),
      transaksi: TransaksiRepository(db),
      favorit: FavoritRepository(db),
    );
    await keranjang.tambah(
      ItemBelanja(nama: 'Semen', qty: 3, satuan: 'sak', hargaSatuan: 65000),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: temaTerang(),
        home: LayarPratinjau(
          profil: const ProfilToko(namaToko: 'TB. SINAR BANGUNAN'),
          keranjang: keranjang,
          pengirim: _PengirimPalsu(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('kolom-bayar')), '200000');
    await tester.pumpAndSettle();

    expect(find.textContaining('Kembali'), findsWidgets);
  });
}
```

- [ ] **Step 3: Jalankan kedua test untuk memastikan gagal**

Jalankan: `flutter test test/state/pengirim_struk_test.dart test/ui/struk/layar_pratinjau_test.dart`
Diharapkan: GAGAL dengan galat kompilasi — kedua berkas belum ada.

- [ ] **Step 4: Tulis pengirim struk**

Buat `lib/state/pengirim_struk.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../data/pengaturan_keluaran_repository.dart';
import '../domain/transaksi.dart';
import '../output/pdf_renderer.dart';
import '../output/png_renderer.dart';
import '../output/share_service.dart';

/// Mengubah struk yang sedang tampil menjadi berkas, lalu menyerahkannya ke
/// share sheet. Format berkasnya mengikuti setelan pengguna; tidak ada
/// pilihan format di layar, karena percabangan di titik tersibuk justru
/// memperlambat.
abstract interface class PengirimStrukKontrak {
  Future<void> kirim({
    required GlobalKey kunciBoundary,
    required Transaksi nota,
    required int lebarKolom,
  });
}

class PengirimStruk implements PengirimStrukKontrak {
  final PengaturanKeluaranRepository _pengaturan;
  final ShareService _berbagi;

  PengirimStruk(this._pengaturan, this._berbagi);

  @override
  Future<void> kirim({
    required GlobalKey kunciBoundary,
    required Transaksi nota,
    required int lebarKolom,
  }) async {
    final Uint8List png = await ambilPng(kunciBoundary);
    final setelan = await _pengaturan.muat();
    final isi = setelan.formatKiriman == FormatKiriman.pdf
        ? await susunPdf(png: png, lebarKolom: lebarKolom)
        : png;

    await _berbagi.bagikan(
      nama: namaBerkasStruk(nota.nomorNota, setelan.formatKiriman),
      isi: isi,
      teks: 'Struk #${nota.nomorNota}',
    );
  }
}
```

- [ ] **Step 5: Tulis layar pratinjau**

Buat `lib/ui/struk/layar_pratinjau.dart`:

```dart
import 'package:flutter/material.dart';

import '../../domain/profil_toko.dart';
import '../../domain/receipt/receipt_builder.dart';
import '../../domain/transaksi.dart';
import '../../domain/uang.dart';
import '../../output/receipt_widget.dart';
import '../../state/keranjang_controller.dart';
import '../../state/pengirim_struk.dart';
import '../komponen/isian.dart';
import '../tema.dart';

class LayarPratinjau extends StatefulWidget {
  final ProfilToko profil;
  final KeranjangController keranjang;
  final PengirimStrukKontrak pengirim;

  const LayarPratinjau({
    super.key,
    required this.profil,
    required this.keranjang,
    required this.pengirim,
  });

  @override
  State<LayarPratinjau> createState() => _LayarPratinjauState();
}

class _LayarPratinjauState extends State<LayarPratinjau> {
  final _kunciStruk = GlobalKey();
  final _bayar = TextEditingController();
  Transaksi? _tersimpan;
  bool _sibuk = false;

  @override
  void dispose() {
    _bayar.dispose();
    super.dispose();
  }

  Transaksi get _pratinjau =>
      _tersimpan ??
      Transaksi(
        nomorNota: '----',
        waktu: DateTime.now(),
        items: widget.keranjang.items,
        bayar: parseRupiah(_bayar.text),
      );

  /// Menyimpan sekali saja. Transaksi wajib sudah ada di basis data sebelum
  /// berkas dibuat: satu kegagalan berbagi tidak boleh menghapus penjualan.
  Future<Transaksi> _simpanSekali() async {
    final sudah = _tersimpan;
    if (sudah != null) return sudah;

    final nota = await widget.keranjang.simpan(bayar: parseRupiah(_bayar.text));
    setState(() => _tersimpan = nota);
    return nota;
  }

  Future<void> _simpanSaja() async {
    setState(() => _sibuk = true);
    await _simpanSekali();
    if (mounted) setState(() => _sibuk = false);
  }

  Future<void> _kirimWa() async {
    setState(() => _sibuk = true);
    final nota = await _simpanSekali();
    await WidgetsBinding.instance.endOfFrame;
    await widget.pengirim.kirim(
      kunciBoundary: _kunciStruk,
      nota: nota,
      lebarKolom: widget.profil.lebarKolom,
    );
    if (mounted) setState(() => _sibuk = false);
  }

  @override
  Widget build(BuildContext context) {
    final dokumen = bangunStruk(profil: widget.profil, transaksi: _pratinjau);

    return Scaffold(
      appBar: AppBar(title: const Text('Struk')),
      body: ListView(
        padding: const EdgeInsets.all(Ukuran.jarak),
        children: [
          Center(
            child: RepaintBoundary(
              key: _kunciStruk,
              child: ReceiptWidget(dokumen: dokumen, ukuranFont: 13),
            ),
          ),
          const SizedBox(height: 24),
          if (_tersimpan == null)
            KolomIsian(
              key: const Key('kolom-bayar'),
              label: 'Uang dibayar (boleh dikosongkan)',
              controller: _bayar,
              hint: '0',
              angka: true,
              formatters: [FormatterRupiah()],
              onChanged: (_) => setState(() {}),
            ),
          if (_tersimpan != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Tersimpan #${_tersimpan!.nomorNota}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('tombol-kirim-wa'),
            onPressed: _sibuk ? null : _kirimWa,
            child: const Text('KIRIM WA'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('tombol-simpan'),
            onPressed: _sibuk || _tersimpan != null ? null : _simpanSaja,
            style: FilledButton.styleFrom(
              backgroundColor: Warna.isian,
              foregroundColor: Warna.teks,
            ),
            child: const Text('SIMPAN SAJA'),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: Sambungkan tombol kirim lewat titik masuk**

`LayarKasir` sudah menerima `onKirim` sejak Tugas 6, jadi tidak ada satu pun berkas Tugas 6 yang perlu diubah di sini — termasuk testnya.

Ganti **seluruh** isi `lib/main.dart` dengan:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/wadah.dart';
import 'domain/profil_toko.dart';
import 'output/share_service.dart';
import 'state/favorit_controller.dart';
import 'state/keranjang_controller.dart';
import 'state/pengirim_struk.dart';
import 'ui/kasir/layar_kasir.dart';
import 'ui/struk/layar_pratinjau.dart';
import 'ui/tema.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final wadah = await Wadah.buat();
  // Onboarding milik Rencana 5; sampai itu ada, struk memakai nama bawaan.
  final profil =
      await wadah.profil.muat() ?? const ProfilToko(namaToko: 'TOKO BANGUNAN');

  runApp(
    AplikasiStruk(
      wadah: wadah,
      profil: profil,
      pengirim: PengirimStruk(
        wadah.pengaturan,
        ShareService(await berkasSementaraCache()),
      ),
    ),
  );
}

class AplikasiStruk extends StatelessWidget {
  final Wadah wadah;
  final ProfilToko profil;
  final PengirimStrukKontrak pengirim;

  const AplikasiStruk({
    super.key,
    required this.wadah,
    required this.profil,
    required this.pengirim,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StrukBangunan',
      debugShowCheckedModeBanner: false,
      theme: temaTerang(),
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => KeranjangController(
              draf: wadah.draf,
              transaksi: wadah.transaksi,
              favorit: wadah.favorit,
            ),
          ),
          ChangeNotifierProvider(
            create: (_) => FavoritController(wadah.favorit),
          ),
        ],
        child: _Beranda(profil: profil, pengirim: pengirim),
      ),
    );
  }
}

class _Beranda extends StatelessWidget {
  final ProfilToko profil;
  final PengirimStrukKontrak pengirim;

  const _Beranda({required this.profil, required this.pengirim});

  @override
  Widget build(BuildContext context) {
    // `context` di sini sudah berada di bawah MultiProvider, sedangkan
    // context milik rute baru tidak — karena itu controller dibaca di sini,
    // bukan di dalam builder rutenya.
    final keranjang = context.read<KeranjangController>();

    return LayarKasir(
      onKirim: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => LayarPratinjau(
            profil: profil,
            keranjang: keranjang,
            pengirim: pengirim,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 7: Jalankan seluruh test untuk memastikan lulus**

Jalankan: `flutter test`
Diharapkan: PASS untuk seluruh berkas, termasuk 165 test dari rencana sebelumnya.

- [ ] **Step 8: Gerbang mutu dan commit**

```bash
flutter test
flutter analyze
dart format --output=none --set-exit-if-changed .
git add lib/state/pengirim_struk.dart lib/ui/struk/layar_pratinjau.dart lib/main.dart test/state/pengirim_struk_test.dart test/ui/struk/layar_pratinjau_test.dart
git commit -m "feat(ui): pratinjau struk dan kirim ke whatsapp"
git push origin rencana-4-antarmuka
```

---

## Selesai bila

- Aplikasi bisa dijalankan di perangkat Android dan menyelesaikan satu pekerjaan utuh: ketik barang → tambah ke daftar → lihat pratinjau → simpan → kirim ke WhatsApp.
- `flutter test` hijau untuk seluruh berkas, `flutter analyze` bersih, `dart format --set-exit-if-changed` keluar kode 0, dan keluaran test bersih.
- Tidak ada berkas `lib/domain/` yang berubah, dan tidak ada berkas `lib/data/` yang mengimpor `package:flutter/*`.
- Tidak ada warna atau ukuran huruf mentah di dalam widget mana pun.
- Transaksi tersimpan di basis data sebelum berkas apa pun dibuat, dan test yang menjaganya benar-benar gagal bila urutannya dibalik.

## Yang belum terbukti dan tidak bisa dibuktikan di sini

- **Alur lengkap di perangkat nyata belum dijalankan.** Uji asap 18 Sep 2026 membuktikan `FileProvider`, `monospace`, dan share sheet bekerja di RMX3710 — tetapi itu memakai layar demo, bukan layar Kasir dan Pratinjau ini.
- **Tata letak pada skala font sistem terbesar belum diuji.** Ada di checklist rilis spec bagian 8; Rencana 5 yang menutupnya.
- **Belum ada pengguna sungguhan yang mencobanya.** KPI 45 detik dari spec bagian 10 hanya bisa diukur lewat uji lapangan.

## Temuan yang diteruskan ke Rencana 5

- **Onboarding belum ada**, sehingga nama toko memakai nilai bawaan `TOKO BANGUNAN` sampai Rencana 5 masuk.
- **`_rakit` menghitung ulang subtotal** alih-alih membaca kolom `item.subtotal` yang tersimpan. Baru terasa saat Riwayat mencetak ulang nota lama. Menepatinya menuntut `ItemBelanja` menerima subtotal dari luar — perubahan di `lib/domain/`, yang **diizinkan** di Rencana 5.
- **`ProfilRepository` belum punya `hapus()`**, sehingga `impor` belum benar-benar menimpa seluruh data untuk cadangan tanpa profil.
- **Dua kunci prefs `backup_terakhir_ms` dan `backup_ditunda_sampai_ms` belum ada** — milik banner pengingat backup.
- **`file_picker` belum terpasang**, dibutuhkan untuk memilih berkas saat memulihkan.
- **Satuan "lainnya" dari spec bagian 5 belum ada** — chip satuan sekarang hanya tujuh nilai tetap.
- **Menekan favorit agak lama untuk menyembunyikannya belum ada.** `FavoritController.sembunyikan` sudah ada dan teruji, tetapi belum punya pemicu di layar; Pengaturan di Rencana 5 juga membutuhkannya.
- **Subtotal kecil di bawah kolom harga belum ditampilkan** (spec bagian 5: supaya salah ketik nol ketahuan sebelum item masuk daftar).
- **Menekan baris item untuk mengubah jumlah dan harga belum ada;** sekarang baru bisa menghapus lalu menambah ulang.
- **Tombol Cetak belum muncul di layar Pratinjau** karena fitur cetak ditunda. Lapisan printernya sudah ada dan teruji.

## Rencana berikutnya

- **Rencana 5 — Riwayat, Pengaturan, dan Rilis:** onboarding, Riwayat beserta rekap harian dan kirim ulang, Pengaturan (profil, format kiriman, kelola favorit tersembunyi), cadangkan dan pulihkan lewat `file_picker`, banner pengingat backup, ikon dan nama aplikasi, penandatanganan rilis, serta checklist rilis manual.
