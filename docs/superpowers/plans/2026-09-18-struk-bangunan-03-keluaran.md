# StrukBangunan — Rencana 3: Keluaran

> **Untuk pekerja agentik:** SUB-SKILL WAJIB: pakai `superpowers:subagent-driven-development` (disarankan) atau `superpowers:executing-plans` untuk mengerjakan rencana ini tugas per tugas. Setiap langkah memakai checkbox (`- [ ]`) untuk penanda kemajuan.

**Goal:** Mengubah `ReceiptDocument` yang sudah jadi menjadi empat keluaran nyata — perintah ESC/POS untuk printer thermal Bluetooth, gambar PNG, berkas PDF, dan pratinjau di layar — lalu mengantarkannya ke printer atau ke share sheet.

**Architecture:** `lib/output/` berdiri di atas `lib/domain/` dan `lib/data/` yang sudah selesai. Seluruh penyaji **hanya menerjemahkan** `ReceiptDocument`; tidak satu pun boleh mengetahui aturan pembulatan, pemotongan nama, atau lebar kertas — itu milik `ReceiptBuilder` di Rencana 1. Plugin printer Bluetooth berupa API statis yang tidak bisa dipalsukan, jadi ia dibungkus di balik antarmuka `PrinterBluetooth` supaya seluruh logika sambung, batas waktu, dan ingat-printer-terakhir tetap bisa diuji di komputer tanpa perangkat keras.

**Tech Stack:** Flutter 3.38.5, Dart 3.10.4, `esc_pos_utils_plus` ^2.0.4, `print_bluetooth_thermal` ^1.2.1, `pdf` ^3.12.0, `share_plus` ^13.3.0, `path_provider` ^2.1.6.

**Spec:** `docs/superpowers/specs/2026-09-17-strukbangunan-app-design.md` — terutama bagian 3 (kontrak antar modul), 6 (format struk), 7 (penanganan kesalahan), 8 (pengujian), dan 9 (dependensi).

**Rencana sebelumnya:** Rencana 1 (fondasi & mesin struk) dan Rencana 2 (penyimpanan lokal), keduanya selesai dan tergabung ke `main` pada `7584b89`.

## Global Constraints

- Flutter 3.38.5, Dart 3.10.4, SDK `^3.10.0`. Android saja. **Aplikasi tidak boleh punya izin `INTERNET`.**
- **`lib/domain/` tidak boleh diubah oleh rencana ini.** Bila sebuah tugas merasa perlu, itu temuan yang dilaporkan, bukan perubahan yang dikerjakan diam-diam.
- **`lib/domain/` tetap tidak boleh mengimpor Flutter.** `lib/data/` tetap tidak boleh mengimpor `package:flutter/*`. `lib/output/` **boleh** mengimpor Flutter — di sanalah widget pratinjau tinggal.
- Semua nilai uang `int` rupiah penuh. Kuantitas `double`. Subtotal dibulatkan **tepat sekali**, di konstruktor `ItemBelanja`. Tidak ada berkas di `lib/output/` yang boleh menghitung ulang nominal apa pun.
- **Penyaji tidak memformat ulang.** `ReceiptDocument.baris` sudah rata sempurna pada lebarnya. Penyaji menerjemahkan teks dan gaya, titik. Melanggar ini berarti struk kertas dan struk WhatsApp bisa berbeda.
- Lebar struk: 58mm = 32 kolom, 80mm = 48 kolom. Invarian: tidak ada baris keluaran melebihi lebar itu.
- Tanda kali di struk adalah huruf `x` biasa, bukan `×`. Printer thermal murah tidak punya glyph-nya.
- Versi dependensi lewat `flutter pub add`, **jangan dipatok manual**.
- Gerbang mutu tiap tugas: `flutter test` hijau, `flutter analyze` bersih, `dart format --output=none --set-exit-if-changed .` keluar dengan kode 0.
- Setiap tugas diakhiri satu commit, lalu push.

## Fakta API yang sudah diverifikasi di mesin ini

Empat cacat terburuk Rencana 2 lahir dari API yang ditulis dari ingatan, bukan diperiksa. Fakta di bawah **sudah dijalankan** sebelum rencana ini ditulis. Percayai fakta ini; jangan menebak yang lain.

| Fakta                                                                                                                                         | Bukti                                                                                                                  |
| --------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| `PrintBluetoothThermal` seluruhnya **statis** — tidak ada konstruktor, tidak bisa di-mock                                                     | dibaca dari `print_bluetooth_thermal-1.2.1/lib/print_bluetooth_thermal.dart`                                           |
| `BluetoothInfo` punya field `name` dan **`macAdress`** — salah eja bawaan paket, satu huruf `d`                                               | berkas yang sama                                                                                                       |
| `CapabilityProfile.load()` **async** dan membaca aset lewat `rootBundle`                                                                      | `capability_profile.dart` memanggil `rootBundle.loadString('packages/esc_pos_utils_plus/resources/capabilities.json')` |
| `CapabilityProfile.load()` **berhasil** di bawah `flutter test` setelah `TestWidgetsFlutterBinding.ensureInitialized()`                       | probe dijalankan, exit 0                                                                                               |
| `Generator.text()` dengan argumen bawaan **tidak** membungkus atau meratakan ulang teks                                                       | jejak byte probe: `ESC @`, `ESC $ 0 0`, `ESC E 1`, `FS .`, `HALO`, `LF` — baris 32 karakter keluar utuh 32 byte        |
| `PaperSize.mm58`, `PaperSize.mm72`, `PaperSize.mm80`                                                                                          | `esc_pos_utils_plus/lib/src/enums.dart`                                                                                |
| `share_plus` 13: `SharePlus.instance.share(ShareParams(files: [XFile(path)], text: ...))`                                                     | `share_plus.dart` + `share_plus_platform.dart`                                                                         |
| `pdf` 3.12: `PdfPageFormat.roll57` / `roll80` ada; tingginya `double.infinity`                                                                | `page_format.dart`                                                                                                     |
| `PdfPageFormat.copyWith` **tidak punya** `marginAll` — hanya `marginLeft/Top/Right/Bottom`                                                    | probe pertama gagal kompilasi karenanya                                                                                |
| Font base-14 `Font.courier()` **mencetak peringatan** `Courier has no Unicode support` ke keluaran test dan tidak menjamin karakter non-ASCII | probe dijalankan, peringatannya terlihat                                                                               |
| `RepaintBoundary.toImage()` → `toByteData(format: png)` **berhasil** di `testWidgets`, tetapi **wajib** dibungkus `tester.runAsync()`         | probe dijalankan, exit 0, PNG 3354 byte                                                                                |
| `pw.MemoryImage(png)` menyediakan `.width` dan `.height`, dan `pw.Image` di dalam `pw.Page` menghasilkan PDF tanpa peringatan apa pun         | probe dijalankan, `%PDF-1.5`, 4722 byte, keluaran bersih                                                               |
| Byte ajaib PNG = `[137, 80, 78, 71]`; PDF diawali `%PDF-`                                                                                     | probe yang sama                                                                                                        |

## Keputusan yang saya ambil saat menulis rencana ini

Partner manusia tidak tersedia saat rencana ini disusun. Setiap keputusan di bawah beserta biayanya bila salah:

1. **PDF tetap masuk v1.** Spec bagian 5 menyebut setelan `format_kiriman` yang memilih PNG atau PDF, jadi memotongnya berarti Rencana 4 punya setelan dengan satu pilihan. FT-06 menulis "PDF opsional" dalam arti opsional bagi pengguna, bukan opsional dibangun. **Biaya bila salah:** satu tugas yang sebenarnya bisa ditunda.
2. **PDF dibangun dari PNG, bukan disusun ulang dengan font PDF.** Ini berubah di tengah penulisan rencana, setelah probe memperlihatkan dua hal: font base-14 `Courier` mencetak peringatan `has no Unicode support` ke keluaran test, dan ia tidak menjamin karakter non-ASCII yang bisa saja diketik pengguna di nama toko atau catatan. Menyusun ulang tata letak di PDF juga berarti **menduplikasi** aturan tata letak yang sudah ada di widget — dua tempat yang harus dijaga tetap sama, padahal spec bagian 6 menuntut "susunan yang sama persis". Menjadikan PDF sebagai pembungkus PNG membuat kesamaan itu **mustahil dilanggar**, menghapus peringatannya, dan memangkas tugasnya menjadi sangat kecil. **Biaya bila salah:** teks di dalam PDF tidak bisa diseleksi atau dicari — tidak relevan untuk struk yang dikirim lewat WhatsApp.
3. **`permission_handler` tidak dipakai di rencana ini.** Plugin printer sudah menyediakan `isPermissionBluetoothGranted` dan `bluetoothEnabled`, jadi `PrinterService` bisa **melaporkan** keadaan izin tanpa paket tambahan. Tombol "Izinkan" dan "Buka Pengaturan HP" yang spec minta adalah UI, dan UI milik Rencana 4. Yang wajib ada sekarang hanyalah entri manifest Android. **Biaya bila salah:** Rencana 4 menambahkan paketnya sendiri.
4. **Tiga utang Rencana 2 ditutup di Tugas 1 dan 2 rencana ini,** bukan ditunda lagi. Salah satunya — ketiadaan `onUpgrade` — menghapus seluruh data pengguna tanpa peringatan begitu skema naik versi, dan Rencana 3 sendiri yang akan menambah kunci baru ke berkas cadangan. **Biaya bila salah:** Rencana 3 sedikit lebih panjang dari lingkup namanya.
5. **Widget struk memakai `fontFamily: 'monospace'`, tanpa membundel berkas font.** Android menyediakan monospace sungguhan lewat fontconfig, dan font uji bawaan `flutter test` sendiri berlebar tetap sehingga golden test tetap stabil dan perataan kolom tetap teruji. **Biaya bila salah:** ada perangkat yang `monospace`-nya ternyata tidak berlebar tetap dan kolomnya meleset — karena itu ia masuk checklist rilis yang memang sudah mewajibkan uji pada perangkat nyata.
6. **`esc_pos_utils_plus` dipakai apa adanya, tetapi hanya `reset`, `text`, `feed`, dan `cut`.** Fitur kolom dan perataannya sengaja tidak disentuh: memakainya berarti meratakan ulang baris yang `ReceiptBuilder` sudah ratakan, dan itu melanggar kontrak antar modul di spec bagian 3. **Biaya bila salah:** kita memasang paket yang hanya sebagian kecilnya terpakai.

## Struktur berkas yang dihasilkan rencana ini

| Berkas                                         | Tanggung jawab                                                   |
| ---------------------------------------------- | ---------------------------------------------------------------- |
| `lib/data/pengaturan_keluaran_repository.dart` | Format kiriman dan printer terakhir di `shared_preferences`      |
| `lib/output/esc_pos_renderer.dart`             | `ReceiptDocument` → `List<int>` perintah ESC/POS                 |
| `lib/output/receipt_widget.dart`               | `ReceiptDocument` → widget, untuk pratinjau sekaligus sumber PNG |
| `lib/output/png_renderer.dart`                 | `RepaintBoundary` → byte PNG                                     |
| `lib/output/pdf_renderer.dart`                 | byte PNG → byte PDF satu halaman                                 |
| `lib/output/printer_bluetooth.dart`            | Antarmuka perangkat + pembungkus API statis plugin               |
| `lib/output/printer_service.dart`              | Pindai, sambung, kirim, batas waktu, ingat printer terakhir      |
| `lib/output/berkas_sementara.dart`             | Tulis berkas cache dan buang yang sudah basi                     |
| `lib/output/share_service.dart`                | Nama berkas dan share sheet                                      |

Berkas yang **diubah**: `lib/data/basisdata.dart`, `lib/data/transaksi_repository.dart`, `lib/data/backup_service.dart`, `android/app/src/main/AndroidManifest.xml`, `pubspec.yaml`.

Rencana 4 memakai seluruh lapisan ini untuk membangun `state/` dan `ui/`.

---

### Task 1: Migrasi skema dan nota tanpa item

Dua utang yang diwariskan Rencana 2, keduanya soal kehilangan data. Dikerjakan lebih dulu karena Tugas 2 akan menyentuh berkas cadangan dan tidak boleh menumpuk di atas fondasi yang bocor.

**Files:**

- Modify: `lib/data/basisdata.dart`
- Modify: `lib/data/transaksi_repository.dart`
- Test: `test/data/basisdata_test.dart`
- Test: `test/data/transaksi_repository_test.dart`

**Interfaces:**

- Consumes: `siapkanSkema`, `versiSkema` dari `basisdata.dart`
- Produces:
  - `OpenDatabaseOptions opsiBasisdata({int versi = versiSkema})` — opsi pembukaan yang dipakai aplikasi, dipisah agar uji migrasi bisa membukanya di berkas sementara
  - `TransaksiRepository.simpan` melempar `ArgumentError` bila `items` kosong

- [ ] **Step 1: Tulis test migrasi yang gagal**

Tambahkan ke bagian akhir `test/data/basisdata_test.dart`, di dalam `main()`:

```dart
  test('basis data versi lama tetap terbuka dan datanya utuh', () async {
    sqfliteFfiInit();
    final folder = await Directory.systemTemp.createTemp('strukbangunan_uji');
    addTearDown(() => folder.delete(recursive: true));
    final jalur = p.join(folder.path, 'coba.db');

    final lama = await databaseFactoryFfi.openDatabase(
      jalur,
      options: opsiBasisdata(versi: 1),
    );
    await lama.insert('transaksi', {
      'nomor_nota': '0001',
      'waktu_ms': 1000,
      'total': 5000,
    });
    await lama.close();

    // Tanpa onUpgrade, membuka berkas yang sama dengan versi lebih tinggi
    // melempar dan pengguna kehilangan seluruh datanya.
    final baru = await databaseFactoryFfi.openDatabase(
      jalur,
      options: opsiBasisdata(versi: versiSkema + 1),
    );
    addTearDown(baru.close);

    expect(await baru.query('transaksi'), hasLength(1));
  });
```

Tambahkan impor yang dibutuhkan di puncak berkas itu. `basisdata_test.dart` belum mengimpor satu pun dari ketiganya:

```dart
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
```

- [ ] **Step 2: Tulis test nota tanpa item yang gagal**

Tambahkan ke bagian akhir `test/data/transaksi_repository_test.dart`, di dalam `main()`:

```dart
  test('nota tanpa item ditolak dan tidak memakai nomor nota', () async {
    final (db, repo) = await _siap();
    addTearDown(db.close);

    await expectLater(
      repo.simpan(items: [], waktu: DateTime(2026, 9, 17)),
      throwsArgumentError,
    );

    final baris = await db.query(
      'meta',
      where: 'kunci = ?',
      whereArgs: ['nomor_nota_berikutnya'],
    );
    expect(baris.first['nilai'], '1');
  });
```

- [ ] **Step 3: Jalankan kedua test untuk memastikan gagal**

Jalankan: `flutter test test/data/basisdata_test.dart test/data/transaksi_repository_test.dart`
Diharapkan: GAGAL — `opsiBasisdata` belum ada (galat kompilasi), dan `simpan` dengan daftar kosong justru lulus tanpa melempar.

- [ ] **Step 4: Pisahkan opsi pembukaan dan tambahkan onUpgrade**

Di `lib/data/basisdata.dart`, ganti `bukaBasisdata()` yang sekarang dengan:

```dart
/// Membuka basis data aplikasi. Pengujian tidak memakai fungsi ini; ia
/// menyuntikkan basis data dalam memori lalu memanggil [siapkanSkema].
Future<Database> bukaBasisdata() async {
  final folder = await getDatabasesPath();
  return databaseFactory.openDatabase(
    p.join(folder, _namaBerkas),
    options: opsiBasisdata(),
  );
}

/// Opsi pembukaan milik aplikasi, dipisah agar uji migrasi bisa membukanya
/// di berkas sementara tanpa plugin jalur.
///
/// [onUpgrade] memanggil [siapkanSkema] karena seluruh pernyataannya memakai
/// `IF NOT EXISTS`: migrasi yang hanya menambah tabel atau indeks selesai
/// sendiri. Migrasi yang mengubah atau membuang kolom **tidak** tertangani di
/// sini dan wajib menulis langkahnya sendiri sebelum `versiSkema` dinaikkan.
OpenDatabaseOptions opsiBasisdata({int versi = versiSkema}) =>
    OpenDatabaseOptions(
      version: versi,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, _) => siapkanSkema(db),
      onUpgrade: (db, _, _) => siapkanSkema(db),
    );
```

Bentuk `options:` hanya tersedia pada `databaseFactory.openDatabase`, bukan pada fungsi tingkat atas `openDatabase` — keduanya sudah disediakan impor `package:sqflite/sqflite.dart` yang ada, jadi tidak ada impor baru.

Penjaga `items.isEmpty` pada Step 5 melempar sebelum satu pun `await`, jadi `simpan` **wajib** ditandai `async`. Tanpa itu `ArgumentError` naik secara sinkron ke pemanggil alih-alih menolak `Future` yang dikembalikan, dan `expectLater(..., throwsArgumentError)` pada Step 2 tidak akan menangkapnya.

- [ ] **Step 5: Tolak nota tanpa item**

Di `lib/data/transaksi_repository.dart`, tambahkan penjaga sebagai pernyataan pertama di dalam `simpan`, sebelum `_db.transaction` dibuka:

```dart
    if (items.isEmpty) {
      throw ArgumentError.value(
        items,
        'items',
        'Nota harus punya sekurangnya satu item',
      );
    }
```

Karena penjaga ini berada sebelum transaksi dibuka, pencacah nomor nota tidak tersentuh — itulah yang dituntut test pada Step 2.

- [ ] **Step 6: Jalankan test untuk memastikan lulus**

Jalankan: `flutter test test/data/basisdata_test.dart test/data/transaksi_repository_test.dart`
Diharapkan: PASS.

- [ ] **Step 7: Gerbang mutu dan commit**

```bash
flutter test
flutter analyze
dart format --output=none --set-exit-if-changed .
git add lib/data/basisdata.dart lib/data/transaksi_repository.dart test/data/basisdata_test.dart test/data/transaksi_repository_test.dart
git commit -m "fix(data): migrasi skema dan tolak nota tanpa item"
git push origin rencana-3-keluaran
```

---

### Task 2: Pengaturan keluaran dan cadangan versi 2

**Files:**

- Create: `lib/data/pengaturan_keluaran_repository.dart`
- Modify: `lib/data/backup_service.dart`
- Test: `test/data/pengaturan_keluaran_repository_test.dart`
- Test: `test/data/backup_service_test.dart`

**Interfaces:**

- Consumes: `SharedPreferences`; `BackupRusak` dan `versiBackup` dari `backup_service.dart`
- Produces:
  - `enum FormatKiriman { png, pdf }`
  - `class PengaturanKeluaran` dengan `FormatKiriman formatKiriman`, `String printerMac`, `String printerNama`
  - `class PengaturanKeluaranRepository(SharedPreferences)` dengan `muat()`, `simpan(PengaturanKeluaran)`, `ingatPrinter(String mac, String nama)`
  - `const int versiBackup = 2;` — berkas cadangan kini membawa bagian `pengaturan`
  - `BackupService(Database, ProfilRepository, PengaturanKeluaranRepository)` — konstruktor bertambah satu parameter

- [ ] **Step 1: Tulis test pengaturan yang gagal**

Buat `test/data/pengaturan_keluaran_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:struk_bangunan/data/pengaturan_keluaran_repository.dart';

Future<PengaturanKeluaranRepository> _siap() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  return PengaturanKeluaranRepository(await SharedPreferences.getInstance());
}

void main() {
  test('bawaan memakai PNG dan belum punya printer', () async {
    final repo = await _siap();
    final hasil = await repo.muat();

    expect(hasil.formatKiriman, FormatKiriman.png);
    expect(hasil.printerMac, '');
    expect(hasil.printerNama, '');
  });

  test('menyimpan lalu memuat kembali seluruh kolom', () async {
    final repo = await _siap();
    await repo.simpan(
      const PengaturanKeluaran(
        formatKiriman: FormatKiriman.pdf,
        printerMac: '66:22:11:AA:BB:CC',
        printerNama: 'RPP02N',
      ),
    );

    final hasil = await repo.muat();
    expect(hasil.formatKiriman, FormatKiriman.pdf);
    expect(hasil.printerMac, '66:22:11:AA:BB:CC');
    expect(hasil.printerNama, 'RPP02N');
  });

  test('ingatPrinter tidak mengubah format kiriman', () async {
    final repo = await _siap();
    await repo.simpan(
      const PengaturanKeluaran(formatKiriman: FormatKiriman.pdf),
    );
    await repo.ingatPrinter('66:22:11:AA:BB:CC', 'RPP02N');

    final hasil = await repo.muat();
    expect(hasil.formatKiriman, FormatKiriman.pdf);
    expect(hasil.printerMac, '66:22:11:AA:BB:CC');
  });

  test('nilai format yang tidak dikenal jatuh ke PNG', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({'format_kiriman': 'faks'});
    final repo = PengaturanKeluaranRepository(
      await SharedPreferences.getInstance(),
    );

    expect((await repo.muat()).formatKiriman, FormatKiriman.png);
  });
}
```

- [ ] **Step 2: Jalankan test untuk memastikan gagal**

Jalankan: `flutter test test/data/pengaturan_keluaran_repository_test.dart`
Diharapkan: GAGAL dengan galat kompilasi — berkasnya belum ada.

- [ ] **Step 3: Tulis repository pengaturan**

Buat `lib/data/pengaturan_keluaran_repository.dart`:

```dart
import 'package:shared_preferences/shared_preferences.dart';

/// Berkas apa yang dikirim ke WhatsApp. Gambar menang sebagai bawaan karena
/// setiap HP bisa menampilkannya tanpa membuka aplikasi lain.
enum FormatKiriman { png, pdf }

class PengaturanKeluaran {
  final FormatKiriman formatKiriman;
  final String printerMac;
  final String printerNama;

  const PengaturanKeluaran({
    this.formatKiriman = FormatKiriman.png,
    this.printerMac = '',
    this.printerNama = '',
  });

  bool get punyaPrinter => printerMac.isNotEmpty;
}

class PengaturanKeluaranRepository {
  final SharedPreferences _prefs;

  PengaturanKeluaranRepository(this._prefs);

  static const kunciFormat = 'format_kiriman';
  static const kunciPrinterMac = 'printer_terakhir_mac';
  static const kunciPrinterNama = 'printer_terakhir_nama';

  Future<PengaturanKeluaran> muat() async {
    return PengaturanKeluaran(
      formatKiriman: formatDariNama(_prefs.getString(kunciFormat)),
      printerMac: _prefs.getString(kunciPrinterMac) ?? '',
      printerNama: _prefs.getString(kunciPrinterNama) ?? '',
    );
  }

  Future<void> simpan(PengaturanKeluaran pengaturan) async {
    await _prefs.setString(kunciFormat, pengaturan.formatKiriman.name);
    await _prefs.setString(kunciPrinterMac, pengaturan.printerMac);
    await _prefs.setString(kunciPrinterNama, pengaturan.printerNama);
  }

  /// Dipanggil setiap kali kasir memilih printer, sehingga tombol Cetak
  /// berikutnya tidak menanyakan apa pun.
  Future<void> ingatPrinter(String mac, String nama) async {
    await _prefs.setString(kunciPrinterMac, mac);
    await _prefs.setString(kunciPrinterNama, nama);
  }

  /// Nilai asing diperlakukan sebagai bawaan, bukan galat: berkas cadangan
  /// bisa datang dari versi aplikasi yang lebih baru. Publik karena
  /// [BackupService] memakainya saat memulihkan.
  static FormatKiriman formatDariNama(String? nilai) {
    for (final f in FormatKiriman.values) {
      if (f.name == nilai) return f;
    }
    return FormatKiriman.png;
  }
}
```

- [ ] **Step 4: Jalankan test untuk memastikan lulus**

Jalankan: `flutter test test/data/pengaturan_keluaran_repository_test.dart`
Diharapkan: PASS, 4 test.

- [ ] **Step 5: Tulis test cadangan versi 2 yang gagal**

Di `test/data/backup_service_test.dart`, `_siap()` sekarang harus menyerahkan repository pengaturan juga. Ganti helper `_siap()` yang ada dengan:

```dart
Future<(Database, BackupService, ProfilRepository, PengaturanKeluaranRepository)>
_siap() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  final db = await bukaBasisdataUji();
  await siapkanSkema(db);
  final prefs = await SharedPreferences.getInstance();
  final profil = ProfilRepository(prefs);
  final pengaturan = PengaturanKeluaranRepository(prefs);
  return (db, BackupService(db, profil, pengaturan), profil, pengaturan);
}
```

Setiap test yang memakai `final (db, backup, profil) = await _siap();` berubah menjadi `final (db, backup, profil, _) = await _siap();`, dan yang memakai `final (db, backup, _) = await _siap();` menjadi `final (db, backup, _, _) = await _siap();`. **Jangan mengubah apa pun selain pola destrukturisasinya** pada test yang sudah ada.

Tambahkan impor:

```dart
import 'package:struk_bangunan/data/pengaturan_keluaran_repository.dart';
```

Lalu tambahkan tiga test baru di akhir `main()`:

```dart
  test('ekspor membawa pengaturan keluaran', () async {
    final (db, backup, profil, pengaturan) = await _siap();
    addTearDown(db.close);
    await _isiContoh(db, profil);
    await pengaturan.simpan(
      const PengaturanKeluaran(
        formatKiriman: FormatKiriman.pdf,
        printerMac: '66:22:11:AA:BB:CC',
        printerNama: 'RPP02N',
      ),
    );

    final data = jsonDecode(await backup.ekspor()) as Map<String, Object?>;
    expect(data['versi'], 2);
    final keluaran = data['pengaturan']! as Map<String, Object?>;
    expect(keluaran['format_kiriman'], 'pdf');
    expect(keluaran['printer_terakhir_mac'], '66:22:11:AA:BB:CC');
    expect(keluaran['printer_terakhir_nama'], 'RPP02N');
  });

  test('impor memulihkan pengaturan keluaran', () async {
    final (db, backup, profil, pengaturan) = await _siap();
    addTearDown(db.close);
    await _isiContoh(db, profil);
    await pengaturan.simpan(
      const PengaturanKeluaran(
        formatKiriman: FormatKiriman.pdf,
        printerMac: '66:22:11:AA:BB:CC',
        printerNama: 'RPP02N',
      ),
    );
    final berkas = await backup.ekspor();

    await pengaturan.simpan(const PengaturanKeluaran());
    await backup.impor(berkas);

    final hasil = await pengaturan.muat();
    expect(hasil.formatKiriman, FormatKiriman.pdf);
    expect(hasil.printerNama, 'RPP02N');
  });

  test('cadangan versi 1 tetap bisa dipulihkan', () async {
    final (db, backup, profil, pengaturan) = await _siap();
    addTearDown(db.close);
    await _isiContoh(db, profil);
    await pengaturan.simpan(
      const PengaturanKeluaran(formatKiriman: FormatKiriman.pdf),
    );

    // Berkas versi 1 tidak punya bagian `pengaturan` sama sekali. Ia harus
    // diterima, dan pengaturan yang sedang dipakai tidak boleh ikut terhapus.
    final lama = jsonDecode(await backup.ekspor()) as Map<String, Object?>;
    lama['versi'] = 1;
    lama.remove('pengaturan');

    await backup.impor(jsonEncode(lama));

    expect(await TransaksiRepository(db).ambil('0001'), isNotNull);
    expect((await pengaturan.muat()).formatKiriman, FormatKiriman.pdf);
  });
```

- [ ] **Step 6: Jalankan test untuk memastikan gagal**

Jalankan: `flutter test test/data/backup_service_test.dart`
Diharapkan: GAGAL — `BackupService` masih menerima dua argumen, `versiBackup` masih 1, dan bagian `pengaturan` belum ada.

- [ ] **Step 7: Naikkan versi cadangan menjadi 2**

Di `lib/data/backup_service.dart`:

Ubah konstanta versi:

```dart
const int versiBackup = 2;
```

Tambahkan impor:

```dart
import 'pengaturan_keluaran_repository.dart';
```

Tambahkan field dan parameter konstruktor:

```dart
class BackupService {
  final Database _db;
  final ProfilRepository _profil;
  final PengaturanKeluaranRepository _pengaturan;

  BackupService(this._db, this._profil, this._pengaturan);
```

Di dalam `ekspor()`, sisipkan bagian `pengaturan` ke dalam peta yang di-`jsonEncode`, tepat setelah `'profil'`:

```dart
      'pengaturan': _pengaturanKePeta(await _pengaturan.muat()),
```

Di dalam `impor(...)`, rakit pengaturan **sebelum** transaksi dibuka, berdampingan dengan `_bacaProfil`:

```dart
    final keluaran = _bacaPengaturan(data['pengaturan']);
```

dan terapkan setelah transaksi berhasil, tepat di bawah penerapan profil:

```dart
    if (keluaran != null) {
      await _pengaturan.simpan(keluaran);
    }
```

Terakhir tambahkan dua pembantu di akhir kelas, bersebelahan dengan `_bacaProfil`:

```dart
  Map<String, Object?> _pengaturanKePeta(PengaturanKeluaran p) => {
    PengaturanKeluaranRepository.kunciFormat: p.formatKiriman.name,
    PengaturanKeluaranRepository.kunciPrinterMac: p.printerMac,
    PengaturanKeluaranRepository.kunciPrinterNama: p.printerNama,
  };

  /// Null berarti berkas cadangan tidak memuat bagian pengaturan — benar untuk
  /// setiap berkas versi 1. Pengaturan yang sedang dipakai dibiarkan utuh.
  PengaturanKeluaran? _bacaPengaturan(Object? data) {
    if (data == null) return null;
    if (data is! Map<Object?, Object?>) {
      throw const BackupRusak('Bagian "pengaturan" pada berkas cadangan rusak.');
    }
    String teks(String kunci) {
      final nilai = data[kunci];
      if (nilai == null) return '';
      if (nilai is! String) {
        throw BackupRusak('Kolom "$kunci" pada pengaturan cadangan tidak sesuai.');
      }
      return nilai;
    }

    return PengaturanKeluaran(
      formatKiriman: PengaturanKeluaranRepository.formatDariNama(
        teks(PengaturanKeluaranRepository.kunciFormat),
      ),
      printerMac: teks(PengaturanKeluaranRepository.kunciPrinterMac),
      printerNama: teks(PengaturanKeluaranRepository.kunciPrinterNama),
    );
  }
```

Agar pembantu di atas bisa memakainya, `formatDariNama` pada `pengaturan_keluaran_repository.dart` sudah ditulis publik sejak Step 3 — tidak ada yang perlu diubah lagi di sana.

- [ ] **Step 8: Jalankan test untuk memastikan lulus**

Jalankan: `flutter test test/data/backup_service_test.dart test/data/pengaturan_keluaran_repository_test.dart`
Diharapkan: PASS, 21 test.

**Catatan untuk pengulas:** penjaga versi yang sudah ada menolak `versi > versiBackup` dan menerima yang lebih kecil, sehingga menaikkan `versiBackup` ke 2 secara otomatis membuat berkas versi 1 tetap diterima. Test `cadangan versi 1 tetap bisa dipulihkan` adalah penjaganya; tanpa itu, perilaku ini hanya kebetulan yang tidak terkunci.

- [ ] **Step 9: Gerbang mutu dan commit**

```bash
flutter test
flutter analyze
dart format --output=none --set-exit-if-changed .
git add lib/data/pengaturan_keluaran_repository.dart lib/data/backup_service.dart test/data/pengaturan_keluaran_repository_test.dart test/data/backup_service_test.dart
git commit -m "feat(data): pengaturan keluaran dan cadangan versi 2"
git push origin rencana-3-keluaran
```

---

### Task 3: Penyaji ESC/POS

**Files:**

- Create: `lib/output/esc_pos_renderer.dart`
- Test: `test/output/esc_pos_renderer_test.dart`

**Interfaces:**

- Consumes: `ReceiptDocument`, `BarisStruk`, `GayaBaris` dari `lib/domain/receipt/receipt_document.dart`
- Produces:
  - `List<int> susunEscPos({required ReceiptDocument dokumen, required CapabilityProfile profil, int barisKosongAkhir = 4, bool potongKertas = true})`

`CapabilityProfile` berasal dari `esc_pos_utils_plus` dan **disuntikkan dari luar**, tidak dimuat di dalam fungsi. Alasannya: `CapabilityProfile.load()` bersifat async dan membaca aset lewat `rootBundle`, sehingga memuatnya di dalam akan menyeret binding Flutter ke jantung penyaji. Pemanggil memuatnya sekali di tepi aplikasi.

- [ ] **Step 1: Tulis test yang gagal**

Buat `test/output/esc_pos_renderer_test.dart`:

```dart
import 'dart:convert';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:struk_bangunan/domain/receipt/receipt_document.dart';
import 'package:struk_bangunan/output/esc_pos_renderer.dart';

/// Posisi kemunculan pertama [pola] di dalam [sumber], atau -1.
int _cariUrutan(List<int> sumber, List<int> pola, [int mulai = 0]) {
  for (var i = mulai; i + pola.length <= sumber.length; i++) {
    var cocok = true;
    for (var j = 0; j < pola.length; j++) {
      if (sumber[i + j] != pola[j]) {
        cocok = false;
        break;
      }
    }
    if (cocok) return i;
  }
  return -1;
}

/// Parameter perintah ESC E (tebal) terakhir sebelum [batas]: 1 tebal, 0
/// biasa, -1 bila tidak ada sama sekali.
int _tebalSebelum(List<int> bytes, int batas) {
  for (var i = batas - 3; i >= 0; i--) {
    if (bytes[i] == 0x1B && bytes[i + 1] == 0x45) return bytes[i + 2];
  }
  return -1;
}

ReceiptDocument _contoh({int lebar = 32}) => ReceiptDocument(
  lebar: lebar,
  baris: [
    BarisStruk(
      'TB. SINAR BANGUNAN'.padLeft(25).padRight(lebar),
      gaya: GayaBaris.tebal,
    ),
    BarisStruk('-' * lebar, gaya: GayaBaris.pemisah),
    BarisStruk('Semen Tiga Roda'.padRight(lebar)),
    BarisStruk(
      'TOTAL'.padRight(lebar - 13) + 'Rp 1.825.000'.padLeft(13),
      gaya: GayaBaris.tebal,
    ),
  ],
);

void main() {
  late CapabilityProfile profil;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    profil = await CapabilityProfile.load();
  });

  test('diawali perintah reset', () {
    final bytes = susunEscPos(dokumen: _contoh(), profil: profil);
    expect(bytes.take(2).toList(), [0x1B, 0x40]);
  });

  test('setiap baris muncul utuh dan berurutan', () {
    final dokumen = _contoh();
    final bytes = susunEscPos(dokumen: dokumen, profil: profil);

    var dari = 0;
    for (final baris in dokumen.baris) {
      final posisi = _cariUrutan(bytes, latin1.encode(baris.teks), dari);
      expect(posisi, greaterThanOrEqualTo(0), reason: 'hilang: ${baris.teks}');
      dari = posisi + baris.teks.length;
    }
  });

  test('baris tebal ditandai tebal, baris lain tidak', () {
    final dokumen = _contoh();
    final bytes = susunEscPos(dokumen: dokumen, profil: profil);

    var dari = 0;
    for (final baris in dokumen.baris) {
      final posisi = _cariUrutan(bytes, latin1.encode(baris.teks), dari);
      expect(
        _tebalSebelum(bytes, posisi),
        baris.gaya == GayaBaris.tebal ? 1 : 0,
        reason: 'gaya salah pada: ${baris.teks}',
      );
      dari = posisi + baris.teks.length;
    }
  });

  test('memotong kertas bila diminta', () {
    final bytes = susunEscPos(dokumen: _contoh(), profil: profil);
    expect(_cariUrutan(bytes, [0x1D, 0x56]), greaterThanOrEqualTo(0));
  });

  test('tidak memotong kertas bila tidak diminta', () {
    final bytes = susunEscPos(
      dokumen: _contoh(),
      profil: profil,
      potongKertas: false,
    );
    expect(_cariUrutan(bytes, [0x1D, 0x56]), -1);
  });

  test('struk 48 kolom keluar utuh tanpa terpotong', () {
    final dokumen = _contoh(lebar: 48);
    final bytes = susunEscPos(dokumen: dokumen, profil: profil);

    for (final baris in dokumen.baris) {
      expect(baris.teks.length, 48);
      expect(_cariUrutan(bytes, latin1.encode(baris.teks)), isNonNegative);
    }
  });

  test('struk tanpa baris tetap menghasilkan reset dan potong', () {
    final bytes = susunEscPos(
      dokumen: ReceiptDocument(lebar: 32, baris: const []),
      profil: profil,
    );
    expect(bytes.take(2).toList(), [0x1B, 0x40]);
    expect(_cariUrutan(bytes, [0x1D, 0x56]), greaterThanOrEqualTo(0));
  });
}
```

- [ ] **Step 2: Jalankan test untuk memastikan gagal**

Jalankan: `flutter test test/output/esc_pos_renderer_test.dart`
Diharapkan: GAGAL dengan galat kompilasi — `esc_pos_renderer.dart` belum ada.

- [ ] **Step 3: Tulis implementasi minimal**

Buat `lib/output/esc_pos_renderer.dart`:

```dart
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

import '../domain/receipt/receipt_document.dart';

/// Menerjemahkan struk yang sudah jadi menjadi perintah ESC/POS.
///
/// Tidak ada satu pun aturan bentuk struk di sini. [ReceiptDocument] sudah
/// rata sempurna pada lebarnya, jadi fitur kolom dan perataan milik
/// [Generator] sengaja tidak dipakai: memakainya berarti meratakan ulang apa
/// yang sudah rata, dan struk kertas bisa berbeda dari struk di layar.
List<int> susunEscPos({
  required ReceiptDocument dokumen,
  required CapabilityProfile profil,
  int barisKosongAkhir = 4,
  bool potongKertas = true,
}) {
  final generator = Generator(
    dokumen.lebar >= 48 ? PaperSize.mm80 : PaperSize.mm58,
    profil,
  );

  final bytes = <int>[...generator.reset()];
  for (final baris in dokumen.baris) {
    bytes.addAll(
      generator.text(
        baris.teks,
        styles: PosStyles(bold: baris.gaya == GayaBaris.tebal),
      ),
    );
  }

  // Kertas perlu maju agar baris terakhir lolos dari kepala cetak sebelum
  // dipotong atau disobek tangan.
  bytes.addAll(generator.feed(barisKosongAkhir));
  if (potongKertas) bytes.addAll(generator.cut());
  return bytes;
}
```

- [ ] **Step 4: Jalankan test untuk memastikan lulus**

Jalankan: `flutter test test/output/esc_pos_renderer_test.dart`
Diharapkan: PASS, 7 test.

- [ ] **Step 5: Gerbang mutu dan commit**

```bash
flutter test
flutter analyze
dart format --output=none --set-exit-if-changed .
git add lib/output/esc_pos_renderer.dart test/output/esc_pos_renderer_test.dart
git commit -m "feat(output): penyaji perintah ESC/POS"
git push origin rencana-3-keluaran
```

---

### Task 4: Widget struk dan PNG

Widget ini dipakai dua kali: sebagai pratinjau di layar dan sebagai sumber gambar PNG. Satu widget untuk dua tujuan adalah alasan struk di HP pembeli tidak mungkin berbeda dari yang dilihat kasir.

**Files:**

- Create: `lib/output/receipt_widget.dart`
- Create: `lib/output/png_renderer.dart`
- Test: `test/output/receipt_widget_test.dart`
- Test: `test/output/png_renderer_test.dart`

**Interfaces:**

- Consumes: `ReceiptDocument`, `BarisStruk`, `GayaBaris` dari domain
- Produces:
  - `class ReceiptWidget extends StatelessWidget` dengan `ReceiptDocument dokumen` dan `double ukuranFont`
  - `Future<Uint8List> ambilPng(GlobalKey kunciBoundary, {double pixelRatio = 3})`

- [ ] **Step 1: Tulis test widget yang gagal**

Buat `test/output/receipt_widget_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:struk_bangunan/domain/receipt/receipt_document.dart';
import 'package:struk_bangunan/output/receipt_widget.dart';

ReceiptDocument _contoh() => ReceiptDocument(
  lebar: 32,
  baris: [
    const BarisStruk('       TB. SINAR BANGUNAN       ', gaya: GayaBaris.tebal),
    const BarisStruk('--------------------------------', gaya: GayaBaris.pemisah),
    const BarisStruk('Semen Tiga Roda'),
    const BarisStruk('               3x65.000  195.000'),
    const BarisStruk('TOTAL               Rp 1.825.000', gaya: GayaBaris.tebal),
  ],
);

Future<void> _pasang(WidgetTester tester, ReceiptDocument dokumen) {
  return tester.pumpWidget(
    MaterialApp(home: Scaffold(body: ReceiptWidget(dokumen: dokumen))),
  );
}

void main() {
  testWidgets('menampilkan setiap baris apa adanya', (tester) async {
    final dokumen = _contoh();
    await _pasang(tester, dokumen);

    for (final baris in dokumen.baris) {
      expect(find.text(baris.teks), findsOneWidget);
    }
  });

  testWidgets('baris tebal dicetak tebal, baris lain tidak', (tester) async {
    final dokumen = _contoh();
    await _pasang(tester, dokumen);

    for (final baris in dokumen.baris) {
      final widget = tester.widget<Text>(find.text(baris.teks));
      expect(
        widget.style!.fontWeight,
        baris.gaya == GayaBaris.tebal ? FontWeight.bold : FontWeight.normal,
        reason: 'gaya salah pada: ${baris.teks}',
      );
    }
  });

  testWidgets('memakai huruf berlebar tetap', (tester) async {
    final dokumen = _contoh();
    await _pasang(tester, dokumen);

    final widget = tester.widget<Text>(find.text(dokumen.baris.first.teks));
    expect(widget.style!.fontFamily, 'monospace');
  });

  testWidgets('baris tidak pernah dibungkus ke baris berikutnya', (
    tester,
  ) async {
    // Pembungkusan akan merusak perataan kolom yang sudah dihitung
    // ReceiptBuilder, dan merusaknya diam-diam.
    final dokumen = _contoh();
    await _pasang(tester, dokumen);

    for (final baris in dokumen.baris) {
      final widget = tester.widget<Text>(find.text(baris.teks));
      expect(widget.softWrap, isFalse);
      expect(widget.maxLines, 1);
    }
  });

  testWidgets('struk kosong tidak melempar', (tester) async {
    await _pasang(tester, ReceiptDocument(lebar: 32, baris: const []));
    expect(find.byType(ReceiptWidget), findsOneWidget);
  });
}
```

- [ ] **Step 2: Tulis test PNG yang gagal**

Buat `test/output/png_renderer_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:struk_bangunan/domain/receipt/receipt_document.dart';
import 'package:struk_bangunan/output/png_renderer.dart';
import 'package:struk_bangunan/output/receipt_widget.dart';

void main() {
  testWidgets('menghasilkan PNG yang sah dari struk yang tampil', (
    tester,
  ) async {
    final kunci = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: RepaintBoundary(
            key: kunci,
            child: ReceiptWidget(
              dokumen: ReceiptDocument(
                lebar: 32,
                baris: const [
                  BarisStruk('TOTAL               Rp 1.825.000'),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // toImage dan toByteData menuntut gelang kejadian sungguhan; tanpa
    // runAsync keduanya menggantung di dalam uji widget.
    late Uint8List png;
    await tester.runAsync(() async {
      png = await ambilPng(kunci);
    });

    expect(png.take(4).toList(), [0x89, 0x50, 0x4E, 0x47]);
    expect(png.length, greaterThan(100));
  });

  testWidgets('kunci yang tidak menunjuk RepaintBoundary ditolak', (
    tester,
  ) async {
    final kunci = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(home: SizedBox(key: kunci, width: 10, height: 10)),
    );

    await tester.runAsync(() async {
      await expectLater(ambilPng(kunci), throwsStateError);
    });
  });
}
```

- [ ] **Step 3: Jalankan kedua test untuk memastikan gagal**

Jalankan: `flutter test test/output/receipt_widget_test.dart test/output/png_renderer_test.dart`
Diharapkan: GAGAL dengan galat kompilasi — kedua berkas belum ada.

- [ ] **Step 4: Tulis widget struk**

Buat `lib/output/receipt_widget.dart`:

```dart
import 'package:flutter/material.dart';

import '../domain/receipt/receipt_document.dart';

/// Menampilkan struk yang sudah jadi, apa adanya.
///
/// Widget yang sama dipakai untuk pratinjau di layar dan sebagai sumber
/// gambar PNG, sehingga struk di HP pembeli tidak mungkin berbeda dari yang
/// dilihat kasir. Ia tidak memformat apa pun: seluruh perataan sudah selesai
/// dihitung [ReceiptBuilder].
class ReceiptWidget extends StatelessWidget {
  final ReceiptDocument dokumen;
  final double ukuranFont;

  const ReceiptWidget({
    super.key,
    required this.dokumen,
    this.ukuranFont = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.all(ukuranFont),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final baris in dokumen.baris)
            Text(
              baris.teks,
              softWrap: false,
              maxLines: 1,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: ukuranFont,
                height: 1.3,
                color: Colors.black,
                fontWeight: baris.gaya == GayaBaris.tebal
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Tulis penyaji PNG**

Buat `lib/output/png_renderer.dart`:

```dart
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Mengubah apa pun yang berada di bawah [RepaintBoundary] bertanda
/// [kunciBoundary] menjadi byte PNG.
///
/// [pixelRatio] 3 menghasilkan gambar yang masih tajam saat pembeli
/// memperbesarnya di WhatsApp, tanpa membuat berkasnya besar.
///
/// Di dalam uji widget, pemanggilan ini **wajib** dibungkus
/// `tester.runAsync()`; tanpa itu ia menggantung.
Future<Uint8List> ambilPng(
  GlobalKey kunciBoundary, {
  double pixelRatio = 3,
}) async {
  final objek = kunciBoundary.currentContext?.findRenderObject();
  if (objek is! RenderRepaintBoundary) {
    throw StateError(
      'Kunci tidak menunjuk RepaintBoundary yang sedang tampil.',
    );
  }

  final gambar = await objek.toImage(pixelRatio: pixelRatio);
  try {
    final data = await gambar.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      throw StateError('Gambar struk gagal diubah menjadi PNG.');
    }
    return data.buffer.asUint8List();
  } finally {
    gambar.dispose();
  }
}
```

- [ ] **Step 6: Jalankan kedua test untuk memastikan lulus**

Jalankan: `flutter test test/output/receipt_widget_test.dart test/output/png_renderer_test.dart`
Diharapkan: PASS, 7 test.

- [ ] **Step 7: Kunci tampilannya dengan golden test**

Tambahkan ke akhir `test/output/receipt_widget_test.dart`:

```dart
  testWidgets('tampilan struk 58mm terkunci', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: RepaintBoundary(child: ReceiptWidget(dokumen: _contoh())),
        ),
      ),
    );

    await expectLater(
      find.byType(ReceiptWidget),
      matchesGoldenFile('goldens/struk_58mm.png'),
    );
  });
```

Bangkitkan berkas emasnya sekali:

```bash
flutter test --update-goldens test/output/receipt_widget_test.dart
```

Lalu **buka `test/output/goldens/struk_58mm.png` dan lihat dengan mata sendiri.** Golden yang dibangkitkan tanpa diperiksa hanya mengunci apa pun yang kebetulan dihasilkan kode, termasuk bila kode itu salah. Yang harus terlihat: kolom nominal rata kanan, garis pemisah selebar baris terpanjang, dan baris tebal benar-benar lebih tebal. Bila ada yang meleset, perbaiki widget-nya, jangan berkasnya.

- [ ] **Step 8: Gerbang mutu dan commit**

```bash
flutter test
flutter analyze
dart format --output=none --set-exit-if-changed .
git add lib/output/receipt_widget.dart lib/output/png_renderer.dart test/output/receipt_widget_test.dart test/output/png_renderer_test.dart test/output/goldens/struk_58mm.png
git commit -m "feat(output): widget struk dan penyaji PNG"
git push origin rencana-3-keluaran
```

---

### Task 5: PDF dari PNG

**Files:**

- Create: `lib/output/pdf_renderer.dart`
- Test: `test/output/pdf_renderer_test.dart`

**Interfaces:**

- Consumes: byte PNG dari `ambilPng`
- Produces:
  - `Future<Uint8List> susunPdf({required Uint8List png, required int lebarKolom})`

**Mengapa PDF dibungkus dari PNG, bukan disusun ulang.** Spec bagian 6 menuntut pratinjau, PNG, dan PDF memakai susunan yang sama persis. Menyusun ulang tata letak dengan font PDF berarti menduplikasi aturan tata letak ke tempat kedua yang harus dijaga tetap sama selamanya — dan font base-14 `Courier` juga mencetak peringatan `has no Unicode support` serta tidak menjamin karakter non-ASCII yang bisa diketik pengguna di nama toko atau catatan. Membungkus PNG membuat kesamaan itu mustahil dilanggar.

- [ ] **Step 1: Tulis test yang gagal**

Buat `test/output/pdf_renderer_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:struk_bangunan/domain/receipt/receipt_document.dart';
import 'package:struk_bangunan/output/pdf_renderer.dart';
import 'package:struk_bangunan/output/png_renderer.dart';
import 'package:struk_bangunan/output/receipt_widget.dart';

Future<Uint8List> _pngContoh(WidgetTester tester) async {
  final kunci = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: RepaintBoundary(
          key: kunci,
          child: ReceiptWidget(
            dokumen: ReceiptDocument(
              lebar: 32,
              baris: const [
                BarisStruk('TOTAL               Rp 1.825.000'),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  late Uint8List png;
  await tester.runAsync(() async {
    png = await ambilPng(kunci);
  });
  return png;
}

void main() {
  testWidgets('menghasilkan PDF satu halaman yang sah', (tester) async {
    final png = await _pngContoh(tester);

    late Uint8List pdf;
    await tester.runAsync(() async {
      pdf = await susunPdf(png: png, lebarKolom: 32);
    });

    expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
    expect(pdf.length, greaterThan(png.length));
  });

  testWidgets('kertas 80mm menghasilkan halaman lebih lebar', (tester) async {
    final png = await _pngContoh(tester);

    late Uint8List sempit;
    late Uint8List lebar;
    await tester.runAsync(() async {
      sempit = await susunPdf(png: png, lebarKolom: 32);
      lebar = await susunPdf(png: png, lebarKolom: 48);
    });

    expect(lebarHalamanPdf(32), lessThan(lebarHalamanPdf(48)));
    expect(sempit, isNotEmpty);
    expect(lebar, isNotEmpty);
  });

  testWidgets('byte yang bukan gambar ditolak', (tester) async {
    await tester.runAsync(() async {
      await expectLater(
        susunPdf(png: Uint8List.fromList([1, 2, 3]), lebarKolom: 32),
        throwsA(isA<Exception>()),
      );
    });
  });
}
```

- [ ] **Step 2: Jalankan test untuk memastikan gagal**

Jalankan: `flutter test test/output/pdf_renderer_test.dart`
Diharapkan: GAGAL dengan galat kompilasi — `pdf_renderer.dart` belum ada.

- [ ] **Step 3: Tulis implementasi minimal**

Buat `lib/output/pdf_renderer.dart`:

```dart
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Lebar halaman PDF untuk struk selebar [lebarKolom] karakter, dalam poin.
double lebarHalamanPdf(int lebarKolom) =>
    lebarKolom >= 48 ? PdfPageFormat.roll80.width : PdfPageFormat.roll57.width;

/// Membungkus gambar struk menjadi PDF satu halaman setinggi gambarnya.
///
/// Tata letaknya tidak disusun ulang di sini: PDF memuat gambar yang sama
/// dengan yang dikirim ke WhatsApp, sehingga keduanya tidak mungkin berbeda.
/// Itu juga sebabnya tidak ada font apa pun di berkas ini.
Future<Uint8List> susunPdf({
  required Uint8List png,
  required int lebarKolom,
}) async {
  final gambar = pw.MemoryImage(png);
  final lebar = lebarHalamanPdf(lebarKolom);
  final tinggi = lebar * gambar.height! / gambar.width!;

  final dokumen = pw.Document();
  dokumen.addPage(
    pw.Page(
      pageFormat: PdfPageFormat(lebar, tinggi),
      build: (_) => pw.Image(gambar, fit: pw.BoxFit.fitWidth),
    ),
  );
  return dokumen.save();
}
```

- [ ] **Step 4: Jalankan test untuk memastikan lulus**

Jalankan: `flutter test test/output/pdf_renderer_test.dart`
Diharapkan: PASS, 3 test.

Bila test ketiga gagal karena `pw.MemoryImage` melempar sesuatu yang bukan `Exception` (misalnya `Error`), **laporkan tipe sebenarnya** dan sesuaikan matcher-nya ke tipe itu — jangan melonggarkannya menjadi `throwsA(anything)`, yang akan lulus terhadap apa pun termasuk berhasil.

- [ ] **Step 5: Gerbang mutu dan commit**

```bash
flutter test
flutter analyze
dart format --output=none --set-exit-if-changed .
git add lib/output/pdf_renderer.dart test/output/pdf_renderer_test.dart
git commit -m "feat(output): PDF struk dari gambar yang sama dengan WhatsApp"
git push origin rencana-3-keluaran
```

---

### Task 6: Layanan printer Bluetooth

Tugas paling berisiko di rencana ini, karena satu-satunya bagian yang tidak bisa dibuktikan tanpa perangkat keras. Karena itu seluruh **keputusannya** dipisahkan dari seluruh **perangkat kerasnya**: `PrinterService` hanya bicara ke antarmuka, dan semua logikanya diuji dengan printer palsu.

**Files:**

- Create: `lib/output/printer_bluetooth.dart`
- Create: `lib/output/printer_service.dart`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Test: `test/output/printer_service_test.dart`
- Test: `test/android_manifest_test.dart`

**Interfaces:**

- Consumes: `PengaturanKeluaranRepository` dari Tugas 2
- Produces:
  - `class PrinterTerdeteksi` dengan `String nama`, `String mac`
  - `abstract interface class PrinterBluetooth`
  - `class PrinterBluetoothAsli implements PrinterBluetooth` — pembungkus plugin
  - `enum HasilCetak { berhasil, izinBelumDiberikan, bluetoothMati, printerBelumDipilih, tidakMenyahut, gagalKirim }`
  - `class PrinterService(PrinterBluetooth, PengaturanKeluaranRepository, {Duration batasWaktu})` dengan `daftarPrinter()`, `pilihPrinter(PrinterTerdeteksi)`, `cetak(List<int>)`

- [ ] **Step 1: Tulis test yang gagal**

Buat `test/output/printer_service_test.dart`:

```dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:struk_bangunan/data/pengaturan_keluaran_repository.dart';
import 'package:struk_bangunan/output/printer_bluetooth.dart';
import 'package:struk_bangunan/output/printer_service.dart';

/// Printer palsu yang bisa disuruh gagal dengan cara apa pun yang nyata.
class _PrinterPalsu implements PrinterBluetooth {
  bool izin = true;
  bool menyala = true;
  bool tersambung = false;
  bool bisaSambung = true;
  bool bisaKirim = true;
  bool diamSelamanya = false;
  List<PrinterTerdeteksi> terpasang = const [];

  int jumlahSambung = 0;
  List<int>? terkirim;

  Future<T> _jawab<T>(T nilai) =>
      diamSelamanya ? Completer<T>().future : Future.value(nilai);

  @override
  Future<bool> izinDiberikan() async => izin;

  @override
  Future<bool> bluetoothMenyala() async => menyala;

  @override
  Future<List<PrinterTerdeteksi>> daftarTerpasang() async => terpasang;

  @override
  Future<bool> sudahTersambung() => _jawab(tersambung);

  @override
  Future<bool> sambung(String mac) {
    jumlahSambung++;
    return _jawab(bisaSambung);
  }

  @override
  Future<bool> kirim(List<int> bytes) {
    terkirim = bytes;
    return _jawab(bisaKirim);
  }

  @override
  Future<void> putus() async {}
}

Future<(_PrinterPalsu, PengaturanKeluaranRepository, PrinterService)> _siap({
  String mac = '66:22:11:AA:BB:CC',
}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  final pengaturan = PengaturanKeluaranRepository(
    await SharedPreferences.getInstance(),
  );
  if (mac.isNotEmpty) await pengaturan.ingatPrinter(mac, 'RPP02N');
  final perangkat = _PrinterPalsu();
  return (
    perangkat,
    pengaturan,
    PrinterService(
      perangkat,
      pengaturan,
      batasWaktu: const Duration(milliseconds: 50),
    ),
  );
}

void main() {
  test('mencetak dan mengirimkan byte yang sama persis', () async {
    final (perangkat, _, layanan) = await _siap();

    expect(await layanan.cetak([1, 2, 3]), HasilCetak.berhasil);
    expect(perangkat.terkirim, [1, 2, 3]);
  });

  test('izin belum diberikan dilaporkan tanpa mencoba mengirim', () async {
    final (perangkat, _, layanan) = await _siap();
    perangkat.izin = false;

    expect(await layanan.cetak([1]), HasilCetak.izinBelumDiberikan);
    expect(perangkat.terkirim, isNull);
  });

  test('bluetooth mati dilaporkan tanpa mencoba mengirim', () async {
    final (perangkat, _, layanan) = await _siap();
    perangkat.menyala = false;

    expect(await layanan.cetak([1]), HasilCetak.bluetoothMati);
    expect(perangkat.terkirim, isNull);
  });

  test('printer belum pernah dipilih dilaporkan tersendiri', () async {
    final (perangkat, _, layanan) = await _siap(mac: '');

    expect(await layanan.cetak([1]), HasilCetak.printerBelumDipilih);
    expect(perangkat.jumlahSambung, 0);
  });

  test('printer yang sudah tersambung tidak disambungkan ulang', () async {
    final (perangkat, _, layanan) = await _siap();
    perangkat.tersambung = true;

    expect(await layanan.cetak([1]), HasilCetak.berhasil);
    expect(perangkat.jumlahSambung, 0);
  });

  test('printer yang menolak sambungan dilaporkan tidak menyahut', () async {
    final (perangkat, _, layanan) = await _siap();
    perangkat.bisaSambung = false;

    expect(await layanan.cetak([1]), HasilCetak.tidakMenyahut);
  });

  test('printer yang diam melebihi batas waktu dilaporkan tidak menyahut', () async {
    final (perangkat, _, layanan) = await _siap();
    perangkat.diamSelamanya = true;

    expect(await layanan.cetak([1]), HasilCetak.tidakMenyahut);
  });

  test('pengiriman yang ditolak printer dilaporkan gagal kirim', () async {
    final (perangkat, _, layanan) = await _siap();
    perangkat.bisaKirim = false;

    expect(await layanan.cetak([1]), HasilCetak.gagalKirim);
  });

  test('memilih printer mengingatnya untuk cetak berikutnya', () async {
    final (_, pengaturan, layanan) = await _siap(mac: '');
    await layanan.pilihPrinter(
      const PrinterTerdeteksi(nama: 'RPP02N', mac: '11:22:33:44:55:66'),
    );

    final hasil = await pengaturan.muat();
    expect(hasil.printerMac, '11:22:33:44:55:66');
    expect(hasil.printerNama, 'RPP02N');
  });

  test('daftar printer diteruskan apa adanya dari perangkat', () async {
    final (perangkat, _, layanan) = await _siap();
    perangkat.terpasang = const [
      PrinterTerdeteksi(nama: 'RPP02N', mac: '11:22:33:44:55:66'),
    ];

    expect((await layanan.daftarPrinter()).single.nama, 'RPP02N');
  });
}
```

- [ ] **Step 2: Tulis test manifest yang gagal**

Buat `test/android_manifest_test.dart`:

```dart
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
```

Manifest `debug` dan `profile` memang memuat `INTERNET` — itu bawaan Flutter untuk hot reload dan tidak ikut ke build rilis. Test ini sengaja hanya memeriksa manifest `main`.

- [ ] **Step 3: Jalankan kedua test untuk memastikan gagal**

Jalankan: `flutter test test/output/printer_service_test.dart test/android_manifest_test.dart`
Diharapkan: GAGAL — berkas printer belum ada, dan manifest belum punya izin Bluetooth.

- [ ] **Step 4: Tulis antarmuka perangkat dan pembungkus plugin**

Buat `lib/output/printer_bluetooth.dart`:

```dart
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

/// Printer yang sudah dipasangkan lewat pengaturan Bluetooth HP.
class PrinterTerdeteksi {
  final String nama;
  final String mac;

  const PrinterTerdeteksi({required this.nama, required this.mac});
}

/// Permukaan perangkat keras yang dipakai [PrinterService].
///
/// Antarmuka ini ada karena `PrintBluetoothThermal` seluruhnya statis dan
/// tidak bisa dipalsukan. Tanpa ia, tidak satu pun keputusan cetak bisa diuji
/// tanpa printer sungguhan.
abstract interface class PrinterBluetooth {
  Future<bool> izinDiberikan();
  Future<bool> bluetoothMenyala();
  Future<List<PrinterTerdeteksi>> daftarTerpasang();
  Future<bool> sudahTersambung();
  Future<bool> sambung(String mac);
  Future<bool> kirim(List<int> bytes);
  Future<void> putus();
}

/// Satu-satunya berkas yang boleh menyentuh plugin printer.
class PrinterBluetoothAsli implements PrinterBluetooth {
  const PrinterBluetoothAsli();

  @override
  Future<bool> izinDiberikan() =>
      PrintBluetoothThermal.isPermissionBluetoothGranted;

  @override
  Future<bool> bluetoothMenyala() => PrintBluetoothThermal.bluetoothEnabled;

  @override
  Future<List<PrinterTerdeteksi>> daftarTerpasang() async {
    final daftar = await PrintBluetoothThermal.pairedBluetooths;
    // `macAdress` memang salah eja di dalam paketnya. Salah eja itu berhenti
    // di baris ini dan tidak pernah masuk ke kode kita.
    return [
      for (final p in daftar) PrinterTerdeteksi(nama: p.name, mac: p.macAdress),
    ];
  }

  @override
  Future<bool> sudahTersambung() => PrintBluetoothThermal.connectionStatus;

  @override
  Future<bool> sambung(String mac) =>
      PrintBluetoothThermal.connect(macPrinterAddress: mac);

  @override
  Future<bool> kirim(List<int> bytes) => PrintBluetoothThermal.writeBytes(bytes);

  @override
  Future<void> putus() => PrintBluetoothThermal.disconnect;
}
```

- [ ] **Step 5: Tulis layanan printer**

Buat `lib/output/printer_service.dart`:

```dart
import 'dart:async';

import '../data/pengaturan_keluaran_repository.dart';
import 'printer_bluetooth.dart';

/// Setiap cara pencetakan bisa gagal, masing-masing punya jalan keluar
/// sendiri di layar. Satu pesan galat untuk semua keadaan akan membuat kasir
/// menebak-nebak.
enum HasilCetak {
  berhasil,
  izinBelumDiberikan,
  bluetoothMati,
  printerBelumDipilih,
  tidakMenyahut,
  gagalKirim,
}

class PrinterService {
  final PrinterBluetooth _perangkat;
  final PengaturanKeluaranRepository _pengaturan;

  /// Delapan detik diambil dari spec bagian 7. Lebih lama dari itu, kasir
  /// sudah menyerah lebih dulu daripada aplikasinya.
  final Duration batasWaktu;

  PrinterService(
    this._perangkat,
    this._pengaturan, {
    this.batasWaktu = const Duration(seconds: 8),
  });

  Future<List<PrinterTerdeteksi>> daftarPrinter() =>
      _perangkat.daftarTerpasang();

  Future<void> pilihPrinter(PrinterTerdeteksi printer) =>
      _pengaturan.ingatPrinter(printer.mac, printer.nama);

  /// Mengirim [bytes] ke printer yang terakhir dipilih.
  ///
  /// Tidak pernah melempar. Transaksi sudah tersimpan sebelum fungsi ini
  /// dipanggil, jadi kegagalan cetak tidak boleh sampai menjatuhkan apa pun.
  Future<HasilCetak> cetak(List<int> bytes) async {
    if (!await _perangkat.izinDiberikan()) {
      return HasilCetak.izinBelumDiberikan;
    }
    if (!await _perangkat.bluetoothMenyala()) {
      return HasilCetak.bluetoothMati;
    }

    final pengaturan = await _pengaturan.muat();
    if (!pengaturan.punyaPrinter) {
      return HasilCetak.printerBelumDipilih;
    }

    try {
      final tersambung = await _perangkat.sudahTersambung().timeout(batasWaktu);
      if (!tersambung) {
        final berhasil = await _perangkat
            .sambung(pengaturan.printerMac)
            .timeout(batasWaktu);
        if (!berhasil) return HasilCetak.tidakMenyahut;
      }

      final terkirim = await _perangkat.kirim(bytes).timeout(batasWaktu);
      return terkirim ? HasilCetak.berhasil : HasilCetak.gagalKirim;
    } on TimeoutException {
      return HasilCetak.tidakMenyahut;
    }
  }
}
```

- [ ] **Step 6: Tambahkan izin Bluetooth ke manifest**

Di `android/app/src/main/AndroidManifest.xml`, sisipkan tepat di bawah baris `<manifest ...>` dan di atas `<application ...>`:

```xml
    <!-- Android 11 ke bawah. Izin lokasi dituntut sistem untuk memindai
         Bluetooth, bukan untuk mengetahui posisi pengguna. -->
    <uses-permission android:name="android.permission.BLUETOOTH"
        android:maxSdkVersion="30" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN"
        android:maxSdkVersion="30" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"
        android:maxSdkVersion="30" />

    <!-- Android 12 ke atas. neverForLocation menyatakan tegas bahwa hasil
         pindai tidak dipakai untuk menentukan lokasi. -->
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN"
        android:usesPermissionFlags="neverForLocation" />
```

**Jangan menambahkan `android.permission.INTERNET`.** Seluruh janji "berjalan tanpa internet" pada spec bagian 10 bersandar pada ketiadaannya, dan test pada Step 2 menjaganya.

- [ ] **Step 7: Jalankan kedua test untuk memastikan lulus**

Jalankan: `flutter test test/output/printer_service_test.dart test/android_manifest_test.dart`
Diharapkan: PASS, 11 test.

- [ ] **Step 8: Gerbang mutu dan commit**

```bash
flutter test
flutter analyze
dart format --output=none --set-exit-if-changed .
git add lib/output/printer_bluetooth.dart lib/output/printer_service.dart android/app/src/main/AndroidManifest.xml test/output/printer_service_test.dart test/android_manifest_test.dart
git commit -m "feat(output): layanan printer bluetooth dan izin android"
git push origin rencana-3-keluaran
```

**Catatan untuk pengulas:** `PrinterBluetoothAsli` **tidak punya test** dan tidak bisa punya — ia murni penerusan ke API statis. Itu disengaja: seluruh isinya adalah satu baris per metode, dan setiap keputusan sudah pindah ke `PrinterService` yang diuji penuh. Yang harus diperiksa pengulas adalah bahwa tidak ada satu pun cabang `if` atau perhitungan yang menyelinap ke dalam pembungkus itu.

---

### Task 7: Berkas sementara dan berbagi

**Files:**

- Create: `lib/output/berkas_sementara.dart`
- Create: `lib/output/share_service.dart`
- Test: `test/output/berkas_sementara_test.dart`
- Test: `test/output/share_service_test.dart`

**Interfaces:**

- Consumes: `FormatKiriman` dari `pengaturan_keluaran_repository.dart`
- Produces:
  - `class BerkasSementara(Directory folder)` dengan `tulis(String, List<int>)` dan `bersihkanLebihTuaDari(Duration, {DateTime? sekarang})`
  - `String namaBerkasStruk(String nomorNota, FormatKiriman format)`
  - `String namaBerkasCadangan(DateTime waktu)`
  - `typedef PengirimBerkas = Future<void> Function(String jalur, String? teks)`
  - `class ShareService(BerkasSementara, {PengirimBerkas? kirim})` dengan `bagikan({required String nama, required List<int> isi, String? teks})`
  - `Future<BerkasSementara> berkasSementaraCache()`

- [ ] **Step 1: Tulis test berkas sementara yang gagal**

Buat `test/output/berkas_sementara_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:struk_bangunan/output/berkas_sementara.dart';

Future<BerkasSementara> _siap() async {
  final folder = await Directory.systemTemp.createTemp('struk_sementara');
  addTearDown(() async {
    if (await folder.exists()) await folder.delete(recursive: true);
  });
  return BerkasSementara(Directory(p.join(folder.path, 'struk')));
}

void main() {
  test('menulis berkas beserta isinya', () async {
    final berkas = await _siap();
    final hasil = await berkas.tulis('struk-0001.png', [1, 2, 3]);

    expect(await hasil.exists(), isTrue);
    expect(await hasil.readAsBytes(), [1, 2, 3]);
  });

  test('membuang berkas yang sudah basi dan menyisakan yang baru', () async {
    final berkas = await _siap();
    final lama = await berkas.tulis('lama.png', [1]);
    await berkas.tulis('baru.png', [2]);
    await lama.setLastModified(
      DateTime.now().subtract(const Duration(hours: 5)),
    );

    final dibuang = await berkas.bersihkanLebihTuaDari(
      const Duration(hours: 1),
    );

    expect(dibuang, 1);
    expect(await lama.exists(), isFalse);
    expect(await File(p.join(berkas.folder.path, 'baru.png')).exists(), isTrue);
  });

  test('membersihkan folder yang belum ada tidak melempar', () async {
    final berkas = await _siap();
    expect(await berkas.bersihkanLebihTuaDari(const Duration(hours: 1)), 0);
  });

  test('menulis dua kali dengan nama sama menimpa isinya', () async {
    final berkas = await _siap();
    await berkas.tulis('struk-0001.png', [1, 2, 3]);
    final hasil = await berkas.tulis('struk-0001.png', [9]);

    expect(await hasil.readAsBytes(), [9]);
  });
}
```

- [ ] **Step 2: Tulis test berbagi yang gagal**

Buat `test/output/share_service_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:struk_bangunan/data/pengaturan_keluaran_repository.dart';
import 'package:struk_bangunan/output/berkas_sementara.dart';
import 'package:struk_bangunan/output/share_service.dart';

Future<BerkasSementara> _folderUji() async {
  final folder = await Directory.systemTemp.createTemp('struk_berbagi');
  addTearDown(() async {
    if (await folder.exists()) await folder.delete(recursive: true);
  });
  return BerkasSementara(Directory(p.join(folder.path, 'struk')));
}

void main() {
  test('nama berkas struk mengikuti format kiriman', () {
    expect(namaBerkasStruk('0142', FormatKiriman.png), 'struk-0142.png');
    expect(namaBerkasStruk('0142', FormatKiriman.pdf), 'struk-0142.pdf');
  });

  test('nama berkas cadangan memakai tanggal berdigit dua', () {
    expect(
      namaBerkasCadangan(DateTime(2026, 9, 5)),
      'strukbangunan-backup-20260905.json',
    );
    expect(
      namaBerkasCadangan(DateTime(2026, 12, 31)),
      'strukbangunan-backup-20261231.json',
    );
  });

  test('membagikan menulis berkas lalu menyerahkan jalurnya', () async {
    final berkas = await _folderUji();
    String? jalurTerkirim;
    String? teksTerkirim;
    final layanan = ShareService(
      berkas,
      kirim: (jalur, teks) async {
        jalurTerkirim = jalur;
        teksTerkirim = teks;
      },
    );

    await layanan.bagikan(
      nama: 'struk-0142.png',
      isi: [1, 2, 3],
      teks: 'Struk #0142',
    );

    expect(p.basename(jalurTerkirim!), 'struk-0142.png');
    expect(teksTerkirim, 'Struk #0142');
    expect(await File(jalurTerkirim!).readAsBytes(), [1, 2, 3]);
  });

  test('membagikan membuang berkas basi lebih dulu', () async {
    final berkas = await _folderUji();
    final basi = await berkas.tulis('basi.png', [7]);
    await basi.setLastModified(
      DateTime.now().subtract(const Duration(days: 2)),
    );

    final layanan = ShareService(berkas, kirim: (_, _) async {});
    await layanan.bagikan(nama: 'struk-0142.png', isi: [1]);

    expect(await basi.exists(), isFalse);
  });
}
```

- [ ] **Step 3: Jalankan kedua test untuk memastikan gagal**

Jalankan: `flutter test test/output/berkas_sementara_test.dart test/output/share_service_test.dart`
Diharapkan: GAGAL dengan galat kompilasi — kedua berkas belum ada.

- [ ] **Step 4: Tulis berkas sementara**

Buat `lib/output/berkas_sementara.dart`:

```dart
import 'dart:io';

import 'package:path/path.dart' as p;

/// Berkas yang hanya perlu hidup sampai selesai dibagikan.
///
/// Struk sengaja tidak disimpan ke galeri: galeri pemilik toko tidak boleh
/// dipenuhi ratusan gambar struk.
class BerkasSementara {
  final Directory folder;

  BerkasSementara(this.folder);

  Future<File> tulis(String nama, List<int> isi) async {
    await folder.create(recursive: true);
    final berkas = File(p.join(folder.path, nama));
    await berkas.writeAsBytes(isi, flush: true);
    return berkas;
  }

  /// Membuang berkas yang lebih tua dari [umur] dan mengembalikan jumlahnya.
  ///
  /// Dipanggil sebelum menulis berkas baru, karena tidak ada saat lain yang
  /// dijamin terjadi: share sheet bisa ditutup kapan saja, dan aplikasi bisa
  /// dimatikan sebelum sempat membereskan.
  Future<int> bersihkanLebihTuaDari(Duration umur, {DateTime? sekarang}) async {
    if (!await folder.exists()) return 0;

    final batas = (sekarang ?? DateTime.now()).subtract(umur);
    var dibuang = 0;
    await for (final entri in folder.list()) {
      if (entri is! File) continue;
      if ((await entri.lastModified()).isBefore(batas)) {
        await entri.delete();
        dibuang++;
      }
    }
    return dibuang;
  }
}
```

- [ ] **Step 5: Tulis layanan berbagi**

Buat `lib/output/share_service.dart`:

```dart
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'dart:io';

import '../data/pengaturan_keluaran_repository.dart';
import 'berkas_sementara.dart';

/// Cara berkas keluar dari aplikasi. Disuntikkan supaya seluruh logika
/// penulisan dan pembersihan bisa diuji tanpa share sheet sungguhan.
typedef PengirimBerkas = Future<void> Function(String jalur, String? teks);

String namaBerkasStruk(String nomorNota, FormatKiriman format) =>
    'struk-$nomorNota.${format == FormatKiriman.pdf ? 'pdf' : 'png'}';

/// Nama yang diminta spec bagian 4, supaya pengguna mengenali berkasnya
/// sendiri di antara ratusan berkas WhatsApp.
String namaBerkasCadangan(DateTime waktu) {
  final bulan = waktu.month.toString().padLeft(2, '0');
  final hari = waktu.day.toString().padLeft(2, '0');
  return 'strukbangunan-backup-${waktu.year}$bulan$hari.json';
}

class ShareService {
  final BerkasSementara _berkas;
  final PengirimBerkas _kirim;

  ShareService(this._berkas, {PengirimBerkas? kirim})
    : _kirim = kirim ?? _lewatShareSheet;

  Future<void> bagikan({
    required String nama,
    required List<int> isi,
    String? teks,
  }) async {
    await _berkas.bersihkanLebihTuaDari(const Duration(hours: 1));
    final berkas = await _berkas.tulis(nama, isi);
    await _kirim(berkas.path, teks);
  }

  static Future<void> _lewatShareSheet(String jalur, String? teks) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(jalur)], text: teks),
    );
  }
}

/// Folder cache tempat berkas struk dan cadangan ditulis sebelum dibagikan.
Future<BerkasSementara> berkasSementaraCache() async {
  final cache = await getTemporaryDirectory();
  return BerkasSementara(Directory(p.join(cache.path, 'struk')));
}
```

- [ ] **Step 6: Jalankan kedua test untuk memastikan lulus**

Jalankan: `flutter test test/output/berkas_sementara_test.dart test/output/share_service_test.dart`
Diharapkan: PASS, 8 test.

- [ ] **Step 7: Gerbang mutu dan commit**

```bash
flutter test
flutter analyze
dart format --output=none --set-exit-if-changed .
git add lib/output/berkas_sementara.dart lib/output/share_service.dart test/output/berkas_sementara_test.dart test/output/share_service_test.dart
git commit -m "feat(output): berkas sementara dan berbagi lewat share sheet"
git push origin rencana-3-keluaran
```

---

## Selesai bila

- `flutter test` hijau untuk seluruh berkas di `test/output/`, dan seluruh test Rencana 1 dan 2 tetap hijau.
- `flutter analyze` tidak melaporkan masalah dan `dart format --set-exit-if-changed` keluar dengan kode 0.
- **Keluaran test bersih** — tidak ada peringatan paket yang menumpang di dalamnya.
- Tidak ada berkas di `lib/domain/` yang berubah, dan tidak ada berkas di `lib/data/` yang mengimpor `package:flutter/*`.
- Manifest `main` memuat izin Bluetooth dan **tidak** memuat `INTERNET`.
- Hanya `printer_bluetooth.dart` yang menyentuh `print_bluetooth_thermal`, dan hanya `share_service.dart` yang menyentuh `share_plus`.
- Golden `struk_58mm.png` sudah dilihat dengan mata manusia, bukan sekadar dibangkitkan.

## Yang belum terbukti dan tidak bisa dibuktikan di sini

Ditulis terus terang supaya tidak ada yang mengira lapisan ini sudah selesai diverifikasi:

- **Tidak ada satu byte pun yang pernah sampai ke printer sungguhan.** Seluruh Tugas 6 diuji dengan printer palsu. Yang terbukti adalah keputusannya benar; yang belum adalah apakah printer nyata menerima urutan byte ini, apakah code page bawaannya menampilkan `x` dan `-` seperti yang kita harap, dan apakah 4 baris maju cukup sebelum sobekan. **Checklist rilis spec bagian 8 sudah mewajibkan cetak sungguhan ke printer 58mm — itu belum tertutup.**
- **`fontFamily: 'monospace'` belum pernah diuji di perangkat Android nyata.** Bila ada perangkat yang memetakannya ke font berlebar tidak tetap, seluruh perataan kolom di PNG dan PDF meleset, sementara struk kertas tetap benar.
- **Share sheet belum pernah dibuka.** `ShareService._lewatShareSheet` dan `berkasSementaraCache()` keduanya murni penerusan ke plugin dan tidak punya test.
- **Alur izin Bluetooth belum pernah dijalankan.** Entri manifest ada, tetapi permintaan izin dan penolakan permanen adalah UI milik Rencana 4.

## Rencana berikutnya

- **Rencana 4 — Antarmuka & Rilis:** `state/`, seluruh layar `ui/`, pembatasan kuantitas dua desimal di titik masukan, alur izin Bluetooth, konfigurasi penandatanganan Android, dan checklist rilis.

## Temuan yang diwariskan ke Rencana 4

Diteruskan dari Rencana 2 dan dari review akhirnya, ditambah yang lahir di sini:

- **Dua kunci `shared_preferences` dari spec sengaja belum dibuat:** `backup_terakhir_ms` dan `backup_ditunda_sampai_ms`, keduanya milik FT-12 (banner pengingat backup) yang sepenuhnya UI. Keduanya juga **tidak boleh** ikut ke berkas cadangan: keduanya menceritakan riwayat perangkat ini, bukan data toko, dan memulihkannya dari cadangan lama justru akan menyembunyikan banner yang seharusnya muncul. Karena itu `versiBackup = 2` tidak perlu naik lagi saat Rencana 4 menambahkannya.
- **`_rakit` menghitung ulang subtotal** alih-alih membaca kolom `item.subtotal` yang tersimpan, sedangkan spec bagian 4 menuntut nota lama yang dicetak ulang keluar persis seperti aslinya. Menepatinya menuntut `ItemBelanja` menerima subtotal dari luar, yaitu mengubah `lib/domain/`. Putuskan sebelum ada aturan pembulatan yang berubah.
- **`FavoritRepository.catatPemakaian` tidak punya varian `...Dalam(DatabaseExecutor)`.** Memanggilnya dari dalam transaksi `TransaksiRepository.simpan` akan **menggantung selamanya**, bukan gagal. Rencana 4 menjalankan keduanya setelah tiap penjualan; jalankan berurutan, atau tambahkan variannya lebih dulu.
- **`ProfilRepository` belum punya `hapus()`,** sehingga `impor` belum benar-benar "menimpa seluruh data" untuk cadangan yang tidak memuat profil. Layar Pengaturan adalah tempatnya.
- **Batas ukuran berkas cadangan 16 MiB** ditegakkan di `impor`, tetapi pemilihan berkas belum ada. Rencana 4 memakai `file_picker`, yang belum terpasang.
- **`isiBawaanBilaKosong` belum pernah dipanggil siapa pun.** Rencana 4 harus memanggilnya saat onboarding. Bila Rencana 4 kelak menambahkan penghapusan favorit sungguhan, 50 bawaan akan kembali sendiri karena "kosong" dinilai dari `COUNT(*)`.
- **`RekapHarian.rekap` memakai batas hari waktu lokal** sementara penyimpanan memakai epoch. Selalu kirim `DateTime` lokal.
- **Konvensi penanganan galat lapisan ini belum tertulis.** `DrafRepository` melewati diam-diam, `BackupService` melempar `BackupRusak`, `PrinterService` mengembalikan enum, dan `TransaksiRepository` membiarkan `DatabaseException` naik. Masing-masing bisa dibela; ketiadaan pernyataannya tidak.
- **Gradle wrapper ter-gitignore**, sehingga build tidak bisa direproduksi dari klon bersih. Milik checklist rilis.
- **Build rilis masih ditandatangani kunci debug**, dan `pubspec.yaml` `description`, `README.md`, serta `lib/main.dart` masih bawaan `flutter create`.
- **`cupertino_icons` adalah dependensi mati** — buang saat tugas UI.
