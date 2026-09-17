# StrukBangunan — Rencana 1: Fondasi & Mesin Struk

> **Untuk pekerja agentik:** SUB-SKILL WAJIB: pakai `superpowers:subagent-driven-development` (disarankan) atau `superpowers:executing-plans` untuk mengerjakan rencana ini tugas per tugas. Setiap langkah memakai checkbox (`- [ ]`) untuk penanda kemajuan.

**Goal:** Membangun mesin struk murni Dart yang mengubah data transaksi menjadi teks struk terformat, lengkap dengan pengujian, sebelum satu baris UI atau kode printer ditulis.

**Architecture:** Seluruh isi rencana ini berada di `lib/domain/` — Dart murni tanpa impor Flutter, sqflite, maupun plugin. `ReceiptBuilder` adalah satu-satunya komponen yang memutuskan bentuk struk; `kolom.dart` hanya mengurus tata letak teks dan tidak tahu apa pun tentang uang atau barang. Semua ini bisa diuji dengan `flutter test` di komputer, tanpa emulator dan tanpa printer.

**Tech Stack:** Flutter 3.38.5, Dart 3.10.4, `flutter_test`. Tidak ada dependensi pihak ketiga pada rencana ini.

**Spec:** `docs/superpowers/specs/2026-09-17-strukbangunan-app-design.md`

## Global Constraints

Berlaku untuk semua tugas di rencana ini dan rencana berikutnya.

- Flutter 3.38.5, Dart 3.10.4. Batas SDK di `pubspec.yaml`: `sdk: ^3.10.0`.
- Android saja. Folder `ios/`, `web/`, `windows/`, `linux/`, `macos/` tidak dibuat.
- Aplikasi **tidak boleh** mencantumkan izin `INTERNET` di `AndroidManifest.xml`.
- Semua nilai uang adalah `int` rupiah penuh. **Dilarang memakai `double` untuk uang.**
- Kuantitas memakai `double`. Subtotal dibulatkan ke rupiah terdekat tepat satu kali, di konstruktor `ItemBelanja`.
- `lib/domain/` dilarang mengimpor `package:flutter/*` atau plugin apa pun.
- Tidak ada baris keluaran struk yang boleh melebihi lebar kolom (32 untuk 58mm, 48 untuk 80mm).
- Tanda kali pada struk ditulis huruf `x` biasa, bukan simbol `×`.
- Nama berkas, kelas, fungsi, dan variabel memakai istilah Bahasa Indonesia sesuai spec.
- Setiap tugas diakhiri satu commit.

## Struktur berkas yang dihasilkan rencana ini

| Berkas | Tanggung jawab |
|---|---|
| `lib/domain/uang.dart` | Format dan parse rupiah, format kuantitas |
| `lib/domain/item_belanja.dart` | Satu baris belanjaan beserta subtotalnya |
| `lib/domain/transaksi.dart` | Kumpulan item, total, kembalian |
| `lib/domain/profil_toko.dart` | Identitas toko dan lebar kertas |
| `lib/domain/receipt/kolom.dart` | Tata letak teks: rata tengah, rata kanan, dua kolom, bungkus kata, baris item C-adaptif |
| `lib/domain/receipt/receipt_document.dart` | Struk final sebagai daftar baris bergaya |
| `lib/domain/receipt/receipt_builder.dart` | Menyusun `ReceiptDocument` dari `Transaksi` + `ProfilToko` |

Rencana 2 akan memakai `ReceiptDocument` untuk ESC/POS, PDF, dan PNG. Rencana 3 membangun UI.

---

### Task 1: Kerangka proyek Flutter

**Files:**
- Create: `pubspec.yaml`, `analysis_options.yaml`, `lib/main.dart`, `android/` (dihasilkan `flutter create`)
- Create: `test/kerangka_test.dart`
- Delete: `test/widget_test.dart` (bawaan `flutter create`)

**Interfaces:**
- Consumes: —
- Produces: proyek Flutter bernama `struk_bangunan` dengan `flutter test` yang berjalan hijau.

- [ ] **Step 1: Buat proyek Flutter di folder yang sudah ada**

Jalankan dari akar repo (folder ini sudah berisi `.git`, `docs/`, dan PDF PRD — `flutter create` aman dijalankan di sini):

```bash
flutter create --org com.shineemad --project-name struk_bangunan --platforms android .
```

- [ ] **Step 2: Hapus test bawaan dan buat folder domain**

```bash
rm test/widget_test.dart
mkdir -p lib/domain/receipt test/domain/receipt
```

- [ ] **Step 3: Tulis test kerangka**

Buat `test/kerangka_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('harness pengujian berjalan', () {
    expect(2 + 2, 4);
  });
}
```

- [ ] **Step 4: Jalankan test**

Jalankan: `flutter test`
Diharapkan: PASS, 1 test.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "chore: kerangka proyek Flutter struk_bangunan (Android)"
```

---

### Task 2: Format uang & kuantitas

**Files:**
- Create: `lib/domain/uang.dart`
- Test: `test/domain/uang_test.dart`

**Interfaces:**
- Consumes: —
- Produces:
  - `const int maksRupiah = 999999999;`
  - `String formatRupiah(int nilai)`
  - `int? parseRupiah(String teks)`
  - `String formatJumlah(double qty)`

- [ ] **Step 1: Tulis test yang gagal**

Buat `test/domain/uang_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:struk_bangunan/domain/uang.dart';

void main() {
  group('formatRupiah', () {
    test('menyisipkan titik setiap tiga digit', () {
      expect(formatRupiah(0), '0');
      expect(formatRupiah(500), '500');
      expect(formatRupiah(65000), '65.000');
      expect(formatRupiah(195000), '195.000');
      expect(formatRupiah(1825000), '1.825.000');
      expect(formatRupiah(999999999), '999.999.999');
    });

    test('nilai negatif memakai awalan minus', () {
      expect(formatRupiah(-25000), '-25.000');
    });
  });

  group('parseRupiah', () {
    test('mengabaikan titik, spasi, dan awalan Rp', () {
      expect(parseRupiah('65.000'), 65000);
      expect(parseRupiah('65000'), 65000);
      expect(parseRupiah('Rp 65.000'), 65000);
    });

    test('mengembalikan null bila tidak ada digit', () {
      expect(parseRupiah(''), isNull);
      expect(parseRupiah('abc'), isNull);
    });

    test('mengembalikan null bila melebihi batas', () {
      expect(parseRupiah('1.000.000.000'), isNull);
    });
  });

  group('formatJumlah', () {
    test('bilangan bulat tanpa desimal', () {
      expect(formatJumlah(1), '1');
      expect(formatJumlah(3), '3');
      expect(formatJumlah(12), '12');
    });

    test('pecahan memakai koma dan membuang nol di belakang', () {
      expect(formatJumlah(1.5), '1,5');
      expect(formatJumlah(0.5), '0,5');
      expect(formatJumlah(2.25), '2,25');
    });
  });
}
```

- [ ] **Step 2: Jalankan test untuk memastikan gagal**

Jalankan: `flutter test test/domain/uang_test.dart`
Diharapkan: GAGAL dengan error kompilasi — `uang.dart` belum ada.

- [ ] **Step 3: Tulis implementasi minimal**

Buat `lib/domain/uang.dart`:

```dart
/// Batas atas nilai uang yang boleh dimasukkan pengguna.
const int maksRupiah = 999999999;

/// 65000 -> "65.000".
String formatRupiah(int nilai) {
  final digit = nilai.abs().toString();
  final hasil = StringBuffer();
  for (var i = 0; i < digit.length; i++) {
    if (i > 0 && (digit.length - i) % 3 == 0) hasil.write('.');
    hasil.write(digit[i]);
  }
  return nilai < 0 ? '-$hasil' : hasil.toString();
}

/// "Rp 65.000" -> 65000. Null bila tidak ada digit atau melebihi [maksRupiah].
int? parseRupiah(String teks) {
  final digit = teks.replaceAll(RegExp(r'[^0-9]'), '');
  if (digit.isEmpty) return null;
  final nilai = int.tryParse(digit);
  if (nilai == null || nilai > maksRupiah) return null;
  return nilai;
}

/// 3.0 -> "3", 1.5 -> "1,5". Maksimal dua angka di belakang koma.
String formatJumlah(double qty) {
  if (qty == qty.roundToDouble()) return qty.round().toString();
  final teks = qty
      .toStringAsFixed(2)
      .replaceAll(RegExp(r'0+$'), '')
      .replaceAll(RegExp(r'\.$'), '');
  return teks.replaceAll('.', ',');
}
```

- [ ] **Step 4: Jalankan test untuk memastikan lulus**

Jalankan: `flutter test test/domain/uang_test.dart`
Diharapkan: PASS, semua grup hijau.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/uang.dart test/domain/uang_test.dart
git commit -m "feat(domain): format dan parse rupiah serta kuantitas"
```

---

### Task 3: Model item belanja

**Files:**
- Create: `lib/domain/item_belanja.dart`
- Test: `test/domain/item_belanja_test.dart`

**Interfaces:**
- Consumes: `maksRupiah` dari `lib/domain/uang.dart`
- Produces: kelas `ItemBelanja` dengan properti `String nama`, `double qty`, `String satuan`, `int hargaSatuan`, `int subtotal`, dibuat lewat konstruktor factory bernama parameter.

- [ ] **Step 1: Tulis test yang gagal**

Buat `test/domain/item_belanja_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:struk_bangunan/domain/item_belanja.dart';

void main() {
  test('subtotal adalah qty dikali harga satuan', () {
    final item = ItemBelanja(
      nama: 'Semen Tiga Roda',
      qty: 3,
      satuan: 'sak',
      hargaSatuan: 65000,
    );
    expect(item.subtotal, 195000);
  });

  test('qty pecahan dibulatkan ke rupiah terdekat', () {
    final item = ItemBelanja(
      nama: 'Pasir',
      qty: 1.5,
      satuan: 'rit',
      hargaSatuan: 850000,
    );
    expect(item.subtotal, 1275000);

    final ganjil = ItemBelanja(
      nama: 'Cat',
      qty: 0.333,
      satuan: 'kaleng',
      hargaSatuan: 1000,
    );
    expect(ganjil.subtotal, 333);
  });

  test('harga nol diizinkan untuk barang bonus', () {
    final item = ItemBelanja(
      nama: 'Kawat Ikat',
      qty: 1,
      satuan: 'kg',
      hargaSatuan: 0,
    );
    expect(item.subtotal, 0);
  });

  test('nama dirapikan dari spasi berlebih', () {
    final item = ItemBelanja(
      nama: '  Paku 7cm  ',
      qty: 2,
      satuan: ' kg ',
      hargaSatuan: 20000,
    );
    expect(item.nama, 'Paku 7cm');
    expect(item.satuan, 'kg');
  });

  test('menolak nama kosong', () {
    expect(
      () => ItemBelanja(nama: '   ', qty: 1, satuan: 'pcs', hargaSatuan: 1000),
      throwsArgumentError,
    );
  });

  test('menolak qty nol atau negatif', () {
    expect(
      () => ItemBelanja(nama: 'Semen', qty: 0, satuan: 'sak', hargaSatuan: 1000),
      throwsArgumentError,
    );
    expect(
      () => ItemBelanja(nama: 'Semen', qty: -1, satuan: 'sak', hargaSatuan: 1000),
      throwsArgumentError,
    );
  });

  test('menolak harga negatif atau di atas batas', () {
    expect(
      () => ItemBelanja(nama: 'Semen', qty: 1, satuan: 'sak', hargaSatuan: -1),
      throwsArgumentError,
    );
    expect(
      () => ItemBelanja(
        nama: 'Semen',
        qty: 1,
        satuan: 'sak',
        hargaSatuan: 1000000000,
      ),
      throwsArgumentError,
    );
  });
}
```

- [ ] **Step 2: Jalankan test untuk memastikan gagal**

Jalankan: `flutter test test/domain/item_belanja_test.dart`
Diharapkan: GAGAL dengan error kompilasi — `item_belanja.dart` belum ada.

- [ ] **Step 3: Tulis implementasi minimal**

Buat `lib/domain/item_belanja.dart`:

```dart
import 'uang.dart';

/// Satu baris belanjaan. Subtotal dihitung dan dibekukan saat item dibuat,
/// sehingga nota lama yang dicetak ulang tidak pernah berubah nilainya.
class ItemBelanja {
  final String nama;
  final double qty;
  final String satuan;
  final int hargaSatuan;
  final int subtotal;

  const ItemBelanja._({
    required this.nama,
    required this.qty,
    required this.satuan,
    required this.hargaSatuan,
    required this.subtotal,
  });

  factory ItemBelanja({
    required String nama,
    required double qty,
    required String satuan,
    required int hargaSatuan,
  }) {
    final namaRapi = nama.trim();
    if (namaRapi.isEmpty) {
      throw ArgumentError.value(nama, 'nama', 'Nama bahan tidak boleh kosong');
    }
    if (qty <= 0) {
      throw ArgumentError.value(qty, 'qty', 'Jumlah harus lebih besar dari nol');
    }
    if (hargaSatuan < 0) {
      throw ArgumentError.value(
        hargaSatuan,
        'hargaSatuan',
        'Harga tidak boleh negatif',
      );
    }
    if (hargaSatuan > maksRupiah) {
      throw ArgumentError.value(
        hargaSatuan,
        'hargaSatuan',
        'Harga melebihi batas yang diizinkan',
      );
    }
    return ItemBelanja._(
      nama: namaRapi,
      qty: qty,
      satuan: satuan.trim(),
      hargaSatuan: hargaSatuan,
      subtotal: (qty * hargaSatuan).round(),
    );
  }
}
```

- [ ] **Step 4: Jalankan test untuk memastikan lulus**

Jalankan: `flutter test test/domain/item_belanja_test.dart`
Diharapkan: PASS, 7 test.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/item_belanja.dart test/domain/item_belanja_test.dart
git commit -m "feat(domain): model ItemBelanja dengan subtotal beku"
```

---

### Task 4: Model transaksi

**Files:**
- Create: `lib/domain/transaksi.dart`
- Test: `test/domain/transaksi_test.dart`

**Interfaces:**
- Consumes: `ItemBelanja` dari `lib/domain/item_belanja.dart`
- Produces: kelas `Transaksi` dengan `String nomorNota`, `DateTime waktu`, `List<ItemBelanja> items`, `int? bayar`, serta getter `int get total` dan `int? get kembali`.

- [ ] **Step 1: Tulis test yang gagal**

Buat `test/domain/transaksi_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:struk_bangunan/domain/item_belanja.dart';
import 'package:struk_bangunan/domain/transaksi.dart';

ItemBelanja _item(String nama, double qty, int harga) => ItemBelanja(
      nama: nama,
      qty: qty,
      satuan: 'pcs',
      hargaSatuan: harga,
    );

void main() {
  test('total adalah jumlah seluruh subtotal', () {
    final transaksi = Transaksi(
      nomorNota: '0142',
      waktu: DateTime(2026, 9, 17, 14, 30),
      items: [_item('Semen', 3, 65000), _item('Paku', 2, 20000)],
    );
    expect(transaksi.total, 235000);
  });

  test('total nol bila tidak ada item', () {
    final transaksi = Transaksi(
      nomorNota: '0001',
      waktu: DateTime(2026, 9, 17),
      items: const [],
    );
    expect(transaksi.total, 0);
  });

  test('kembali null bila kasir tidak mengisi uang bayar', () {
    final transaksi = Transaksi(
      nomorNota: '0142',
      waktu: DateTime(2026, 9, 17),
      items: [_item('Semen', 1, 65000)],
    );
    expect(transaksi.kembali, isNull);
  });

  test('kembali adalah bayar dikurangi total', () {
    final transaksi = Transaksi(
      nomorNota: '0142',
      waktu: DateTime(2026, 9, 17),
      items: [_item('Semen', 1, 65000)],
      bayar: 100000,
    );
    expect(transaksi.kembali, 35000);
  });

  test('kembali negatif bila uang bayar kurang', () {
    final transaksi = Transaksi(
      nomorNota: '0142',
      waktu: DateTime(2026, 9, 17),
      items: [_item('Semen', 1, 65000)],
      bayar: 50000,
    );
    expect(transaksi.kembali, -15000);
  });

  test('daftar item tidak bisa diubah dari luar', () {
    final transaksi = Transaksi(
      nomorNota: '0142',
      waktu: DateTime(2026, 9, 17),
      items: [_item('Semen', 1, 65000)],
    );
    expect(
      () => transaksi.items.add(_item('Paku', 1, 20000)),
      throwsUnsupportedError,
    );
  });
}
```

- [ ] **Step 2: Jalankan test untuk memastikan gagal**

Jalankan: `flutter test test/domain/transaksi_test.dart`
Diharapkan: GAGAL dengan error kompilasi — `transaksi.dart` belum ada.

- [ ] **Step 3: Tulis implementasi minimal**

Buat `lib/domain/transaksi.dart`:

```dart
import 'item_belanja.dart';

/// Satu nota belanja. Kembalian boleh negatif; pemanggil yang memutuskan
/// apakah keadaan itu ditampilkan sebagai kekurangan bayar.
class Transaksi {
  final String nomorNota;
  final DateTime waktu;
  final List<ItemBelanja> items;
  final int? bayar;

  Transaksi({
    required this.nomorNota,
    required this.waktu,
    required List<ItemBelanja> items,
    this.bayar,
  }) : items = List.unmodifiable(items);

  int get total => items.fold(0, (jumlah, item) => jumlah + item.subtotal);

  int? get kembali => bayar == null ? null : bayar! - total;
}
```

- [ ] **Step 4: Jalankan test untuk memastikan lulus**

Jalankan: `flutter test test/domain/transaksi_test.dart`
Diharapkan: PASS, 6 test.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/transaksi.dart test/domain/transaksi_test.dart
git commit -m "feat(domain): model Transaksi dengan total dan kembalian"
```

---

### Task 5: Profil toko

**Files:**
- Create: `lib/domain/profil_toko.dart`
- Test: `test/domain/profil_toko_test.dart`

**Interfaces:**
- Consumes: —
- Produces: kelas `ProfilToko` dengan `String namaToko`, `String alamat`, `String noHp`, `String catatan`, `String namaKasir`, `int lebarKertas`, serta getter `int get lebarKolom`.

- [ ] **Step 1: Tulis test yang gagal**

Buat `test/domain/profil_toko_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:struk_bangunan/domain/profil_toko.dart';

void main() {
  test('kertas 58mm memberi 32 kolom', () {
    const profil = ProfilToko(namaToko: 'TB. SINAR BANGUNAN');
    expect(profil.lebarKertas, 58);
    expect(profil.lebarKolom, 32);
  });

  test('kertas 80mm memberi 48 kolom', () {
    const profil = ProfilToko(
      namaToko: 'TB. SINAR BANGUNAN',
      lebarKertas: 80,
    );
    expect(profil.lebarKolom, 48);
  });

  test('kolom opsional bernilai kosong secara bawaan', () {
    const profil = ProfilToko(namaToko: 'TB. SINAR BANGUNAN');
    expect(profil.alamat, '');
    expect(profil.noHp, '');
    expect(profil.catatan, '');
    expect(profil.namaKasir, '');
  });
}
```

- [ ] **Step 2: Jalankan test untuk memastikan gagal**

Jalankan: `flutter test test/domain/profil_toko_test.dart`
Diharapkan: GAGAL dengan error kompilasi — `profil_toko.dart` belum ada.

- [ ] **Step 3: Tulis implementasi minimal**

Buat `lib/domain/profil_toko.dart`:

```dart
/// Identitas toko yang dicetak di kepala struk.
class ProfilToko {
  final String namaToko;
  final String alamat;
  final String noHp;
  final String catatan;
  final String namaKasir;

  /// Lebar kertas dalam milimeter: 58 atau 80.
  final int lebarKertas;

  const ProfilToko({
    required this.namaToko,
    this.alamat = '',
    this.noHp = '',
    this.catatan = '',
    this.namaKasir = '',
    this.lebarKertas = 58,
  });

  /// Jumlah karakter per baris pada font printer standar (Font A).
  int get lebarKolom => lebarKertas == 80 ? 48 : 32;
}
```

- [ ] **Step 4: Jalankan test untuk memastikan lulus**

Jalankan: `flutter test test/domain/profil_toko_test.dart`
Diharapkan: PASS, 3 test.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/profil_toko.dart test/domain/profil_toko_test.dart
git commit -m "feat(domain): model ProfilToko dan lebar kolom kertas"
```

---

### Task 6: Tata letak kolom (aturan C-adaptif)

Ini inti rencana. Seluruh aturan perataan struk hidup di sini, dalam bentuk fungsi murni yang hanya menerima dan mengembalikan `String`.

**Files:**
- Create: `lib/domain/receipt/kolom.dart`
- Test: `test/domain/receipt/kolom_test.dart`

**Interfaces:**
- Consumes: —
- Produces:
  - `String garisPemisah(int lebar)`
  - `String rataTengah(String teks, int lebar)`
  - `String rataKanan(String teks, int lebar)`
  - `String duaKolom(String kiri, String kanan, int lebar)`
  - `List<String> bungkusKata(String teks, int lebar)`
  - `List<String> susunBarisItem({required String nama, required String rincian, required String nominal, required int lebar})`

- [ ] **Step 1: Tulis test yang gagal**

Buat `test/domain/receipt/kolom_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:struk_bangunan/domain/receipt/kolom.dart';

void main() {
  group('garisPemisah', () {
    test('panjangnya persis selebar kertas', () {
      expect(garisPemisah(32).length, 32);
      expect(garisPemisah(32), '-' * 32);
      expect(garisPemisah(48).length, 48);
    });
  });

  group('rataTengah', () {
    test('menempatkan teks di tengah dengan pembulatan ke bawah', () {
      expect(rataTengah('TB. SINAR BANGUNAN', 32), '       TB. SINAR BANGUNAN');
      expect(rataTengah('*** TERIMA KASIH ***', 32), '      *** TERIMA KASIH ***');
      expect(rataTengah('tidak dapat dikembalikan.', 32),
          '   tidak dapat dikembalikan.');
    });

    test('memotong teks yang lebih panjang dari lebar', () {
      expect(rataTengah('A' * 40, 32).length, 32);
    });
  });

  group('rataKanan', () {
    test('mengisi spasi di kiri hingga penuh', () {
      expect(rataKanan('195.000', 32).length, 32);
      expect(rataKanan('195.000', 32).endsWith('195.000'), isTrue);
      expect(rataKanan('175.000', 9), '  175.000');
    });

    test('mempertahankan digit paling kanan bila terlalu panjang', () {
      expect(rataKanan('1.234.567', 5), '4.567');
    });
  });

  group('duaKolom', () {
    test('kiri menempel kiri, kanan menempel kanan, total selebar kertas', () {
      final baris = duaKolom('TOTAL', 'Rp 1.825.000', 32);
      expect(baris, 'TOTAL               Rp 1.825.000');
      expect(baris.length, 32);
    });

    test('memotong sisi kiri bila ruangnya tidak cukup', () {
      final baris = duaKolom('A' * 40, 'Rp 1.000', 32);
      expect(baris.length, 32);
      expect(baris.endsWith('Rp 1.000'), isTrue);
    });
  });

  group('bungkusKata', () {
    test('membungkus secara rakus pada batas lebar', () {
      expect(
        bungkusKata('Keramik Granit Roman 60x60 Putih Doff', 32),
        ['Keramik Granit Roman 60x60 Putih', 'Doff'],
      );
    });

    test('teks yang muat tetap satu baris', () {
      expect(bungkusKata('Semen Tiga Roda', 32), ['Semen Tiga Roda']);
    });

    test('kata tunggal lebih panjang dari lebar dipotong paksa', () {
      final hasil = bungkusKata('A' * 40, 32);
      expect(hasil, ['A' * 32, 'A' * 8]);
    });

    test('teks kosong menghasilkan satu baris kosong', () {
      expect(bungkusKata('', 32), ['']);
    });
  });

  group('susunBarisItem', () {
    test('nama pendek dengan jumlah lebih dari satu muat satu baris', () {
      expect(
        susunBarisItem(
          nama: 'Paku 7cm',
          rincian: '2x20.000',
          nominal: '40.000',
          lebar: 32,
        ),
        ['Paku 7cm        2x20.000  40.000'],
      );
    });

    test('jumlah satu menghilangkan rincian sehingga muat satu baris', () {
      expect(
        susunBarisItem(
          nama: 'Pasir (1 rit)',
          rincian: '',
          nominal: '850.000',
          lebar: 32,
        ),
        ['Pasir (1 rit)            850.000'],
      );
    });

    test('nama yang tidak muat jatuh ke dua baris tanpa dipotong', () {
      expect(
        susunBarisItem(
          nama: 'Semen Tiga Roda',
          rincian: '3x65.000',
          nominal: '195.000',
          lebar: 32,
        ),
        ['Semen Tiga Roda', '               3x65.000  195.000'],
      );
    });

    test('nama sangat panjang dibungkus lalu angka rata kanan', () {
      expect(
        susunBarisItem(
          nama: 'Keramik Granit Roman 60x60 Putih Doff',
          rincian: '4x185.000',
          nominal: '740.000',
          lebar: 32,
        ),
        [
          'Keramik Granit Roman 60x60 Putih',
          'Doff',
          '              4x185.000  740.000',
        ],
      );
    });

    test('nominal besar dengan jumlah dua digit tidak menjebol lebar', () {
      final baris = susunBarisItem(
        nama: 'Besi Beton 12mm',
        rincian: '12x1.250.000',
        nominal: '15.000.000',
        lebar: 32,
      );
      for (final b in baris) {
        expect(b.length, lessThanOrEqualTo(32));
      }
      expect(baris.last.endsWith('15.000.000'), isTrue);
    });

    test('kertas 80mm memakai 48 kolom', () {
      final baris = susunBarisItem(
        nama: 'Semen Tiga Roda',
        rincian: '3x65.000',
        nominal: '195.000',
        lebar: 48,
      );
      expect(baris.length, 1);
      expect(baris.single.length, 48);
    });
  });

  group('invarian lebar', () {
    test('tidak ada baris yang melebihi lebar kertas', () {
      const namaUji = [
        'Semen',
        'Semen Tiga Roda',
        'Keramik Granit Roman 60x60 Putih Doff',
        'Cat Tembok Avitex 25kg Warna Putih Tulang Sangat Panjang Sekali',
        'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
      ];
      const rincianUji = ['', '3x65.000', '12x1.250.000', '100x999.999.999'];
      const nominalUji = ['0', '40.000', '15.000.000', '999.999.999'];

      for (final lebar in [32, 48]) {
        for (final nama in namaUji) {
          for (final rincian in rincianUji) {
            for (final nominal in nominalUji) {
              final baris = susunBarisItem(
                nama: nama,
                rincian: rincian,
                nominal: nominal,
                lebar: lebar,
              );
              for (final b in baris) {
                expect(
                  b.length,
                  lessThanOrEqualTo(lebar),
                  reason: 'nama=$nama rincian=$rincian nominal=$nominal '
                      'lebar=$lebar baris="$b"',
                );
              }
            }
          }
        }
      }
    });
  });
}
```

- [ ] **Step 2: Jalankan test untuk memastikan gagal**

Jalankan: `flutter test test/domain/receipt/kolom_test.dart`
Diharapkan: GAGAL dengan error kompilasi — `kolom.dart` belum ada.

- [ ] **Step 3: Tulis implementasi minimal**

Buat `lib/domain/receipt/kolom.dart`:

```dart
/// Aturan tata letak teks struk. Murni string: berkas ini tidak tahu apa pun
/// tentang uang, barang, maupun printer.

String garisPemisah(int lebar) => '-' * lebar;

String rataTengah(String teks, int lebar) {
  if (teks.length >= lebar) return teks.substring(0, lebar);
  return ' ' * ((lebar - teks.length) ~/ 2) + teks;
}

/// Bila teks lebih panjang dari lebar, sisi kiri yang dibuang agar digit
/// paling kanan (yang paling menentukan nilai) tetap terbaca.
String rataKanan(String teks, int lebar) {
  if (teks.length >= lebar) return teks.substring(teks.length - lebar);
  return ' ' * (lebar - teks.length) + teks;
}

String duaKolom(String kiri, String kanan, int lebar) {
  if (kanan.length >= lebar) return rataKanan(kanan, lebar);
  final ruangKiri = lebar - kanan.length - 1;
  final kiriPotong = kiri.length > ruangKiri ? kiri.substring(0, ruangKiri) : kiri;
  return kiriPotong + ' ' * (lebar - kiriPotong.length - kanan.length) + kanan;
}

/// Membungkus per kata secara rakus. Kata tunggal yang lebih panjang dari
/// [lebar] dipotong paksa; itu satu-satunya keadaan yang memenggal teks.
List<String> bungkusKata(String teks, int lebar) {
  final hasil = <String>[];
  var baris = '';

  for (final kata in teks.split(RegExp(r'\s+')).where((k) => k.isNotEmpty)) {
    var sisa = kata;
    while (sisa.length > lebar) {
      if (baris.isNotEmpty) {
        hasil.add(baris);
        baris = '';
      }
      hasil.add(sisa.substring(0, lebar));
      sisa = sisa.substring(lebar);
    }
    if (sisa.isEmpty) continue;

    if (baris.isEmpty) {
      baris = sisa;
    } else if (baris.length + 1 + sisa.length <= lebar) {
      baris = '$baris $sisa';
    } else {
      hasil.add(baris);
      baris = sisa;
    }
  }

  if (baris.isNotEmpty) hasil.add(baris);
  if (hasil.isEmpty) hasil.add('');
  return hasil;
}

/// Aturan C-adaptif: satu baris bila nama muat di sisa ruang, dua baris bila
/// tidak. Nama tidak pernah dipotong kecuali satu katanya melebihi [lebar].
List<String> susunBarisItem({
  required String nama,
  required String rincian,
  required String nominal,
  required int lebar,
}) {
  final kanan = rincian.isEmpty ? nominal : '$rincian  $nominal';
  final ruangNama = lebar - kanan.length - 1;

  if (ruangNama > 0 && nama.length <= ruangNama) {
    return [duaKolom(nama, kanan, lebar)];
  }
  return [...bungkusKata(nama, lebar), rataKanan(kanan, lebar)];
}
```

- [ ] **Step 4: Jalankan test untuk memastikan lulus**

Jalankan: `flutter test test/domain/receipt/kolom_test.dart`
Diharapkan: PASS, seluruh grup hijau termasuk grup "invarian lebar".

- [ ] **Step 5: Commit**

```bash
git add lib/domain/receipt/kolom.dart test/domain/receipt/kolom_test.dart
git commit -m "feat(domain): aturan tata letak kolom C-adaptif"
```

---

### Task 7: Dokumen struk

**Files:**
- Create: `lib/domain/receipt/receipt_document.dart`
- Test: `test/domain/receipt/receipt_document_test.dart`

**Interfaces:**
- Consumes: —
- Produces:
  - `enum GayaBaris { biasa, tebal, pemisah }`
  - `class BarisStruk` dengan `String teks` dan `GayaBaris gaya`, konstruktor `const BarisStruk(String teks, {GayaBaris gaya = GayaBaris.biasa})`
  - `class ReceiptDocument` dengan `int lebar`, `List<BarisStruk> baris`, dan getter `String get teksPolos`

- [ ] **Step 1: Tulis test yang gagal**

Buat `test/domain/receipt/receipt_document_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:struk_bangunan/domain/receipt/receipt_document.dart';

void main() {
  test('gaya bawaan adalah biasa', () {
    const baris = BarisStruk('Semen Tiga Roda');
    expect(baris.gaya, GayaBaris.biasa);
  });

  test('teksPolos menggabungkan baris dengan newline', () {
    final dokumen = ReceiptDocument(
      lebar: 32,
      baris: const [
        BarisStruk('TB. SINAR BANGUNAN', gaya: GayaBaris.tebal),
        BarisStruk('--------', gaya: GayaBaris.pemisah),
        BarisStruk('Semen'),
      ],
    );
    expect(dokumen.teksPolos, 'TB. SINAR BANGUNAN\n--------\nSemen');
  });

  test('daftar baris tidak bisa diubah dari luar', () {
    final dokumen = ReceiptDocument(
      lebar: 32,
      baris: const [BarisStruk('Semen')],
    );
    expect(
      () => dokumen.baris.add(const BarisStruk('Paku')),
      throwsUnsupportedError,
    );
  });
}
```

- [ ] **Step 2: Jalankan test untuk memastikan gagal**

Jalankan: `flutter test test/domain/receipt/receipt_document_test.dart`
Diharapkan: GAGAL dengan error kompilasi — `receipt_document.dart` belum ada.

- [ ] **Step 3: Tulis implementasi minimal**

Buat `lib/domain/receipt/receipt_document.dart`:

```dart
/// Penanda gaya cetak. ESC/POS memakainya untuk menebalkan huruf; widget
/// pratinjau dan PDF memakainya agar tampilannya sama.
enum GayaBaris { biasa, tebal, pemisah }

class BarisStruk {
  final String teks;
  final GayaBaris gaya;

  const BarisStruk(this.teks, {this.gaya = GayaBaris.biasa});
}

/// Struk yang sudah final: seluruh perataan sudah selesai dihitung. Penyaji
/// (ESC/POS, PDF, widget) hanya menerjemahkan, tidak boleh memformat ulang.
class ReceiptDocument {
  final int lebar;
  final List<BarisStruk> baris;

  ReceiptDocument({required this.lebar, required List<BarisStruk> baris})
      : baris = List.unmodifiable(baris);

  String get teksPolos => baris.map((b) => b.teks).join('\n');
}
```

- [ ] **Step 4: Jalankan test untuk memastikan lulus**

Jalankan: `flutter test test/domain/receipt/receipt_document_test.dart`
Diharapkan: PASS, 3 test.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/receipt/receipt_document.dart test/domain/receipt/receipt_document_test.dart
git commit -m "feat(domain): ReceiptDocument sebagai struk final"
```

---

### Task 8: Penyusun struk

**Files:**
- Create: `lib/domain/receipt/receipt_builder.dart`
- Test: `test/domain/receipt/receipt_builder_test.dart`

**Interfaces:**
- Consumes: `ProfilToko`, `Transaksi`, `ItemBelanja`, `formatRupiah`, `formatJumlah`, seluruh fungsi `kolom.dart`, `ReceiptDocument`, `BarisStruk`, `GayaBaris`
- Produces: `ReceiptDocument bangunStruk({required ProfilToko profil, required Transaksi transaksi})`

- [ ] **Step 1: Tulis test yang gagal**

Buat `test/domain/receipt/receipt_builder_test.dart`. Test pertama membandingkan seluruh struk dengan contoh di spec, huruf demi huruf:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:struk_bangunan/domain/item_belanja.dart';
import 'package:struk_bangunan/domain/profil_toko.dart';
import 'package:struk_bangunan/domain/receipt/receipt_builder.dart';
import 'package:struk_bangunan/domain/receipt/receipt_document.dart';
import 'package:struk_bangunan/domain/transaksi.dart';

const _profil = ProfilToko(
  namaToko: 'TB. SINAR BANGUNAN',
  alamat: 'Jl. Raya Merdeka No. 45',
  noHp: '0812-3456-7890',
  namaKasir: 'Admin',
  catatan: 'Barang yang sudah dibeli\ntidak dapat dikembalikan.',
);

Transaksi _transaksiContoh() => Transaksi(
      nomorNota: '0142',
      waktu: DateTime(2026, 9, 17, 14, 30),
      bayar: 2000000,
      items: [
        ItemBelanja(
          nama: 'Semen Tiga Roda',
          qty: 3,
          satuan: 'sak',
          hargaSatuan: 65000,
        ),
        ItemBelanja(
          nama: 'Pasir',
          qty: 1,
          satuan: 'rit',
          hargaSatuan: 850000,
        ),
        ItemBelanja(
          nama: 'Paku 7cm',
          qty: 2,
          satuan: 'kg',
          hargaSatuan: 20000,
        ),
        ItemBelanja(
          nama: 'Keramik Granit Roman 60x60 Putih Doff',
          qty: 4,
          satuan: 'dus',
          hargaSatuan: 185000,
        ),
      ],
    );

void main() {
  test('menghasilkan struk yang sama persis dengan contoh di spec', () {
    final dokumen = bangunStruk(
      profil: _profil,
      transaksi: _transaksiContoh(),
    );

    const diharapkan = '''
       TB. SINAR BANGUNAN
    Jl. Raya Merdeka No. 45
    Telp/WA: 0812-3456-7890
--------------------------------
No. Nota : #0142
Tanggal  : 17/09/2026 14:30
Kasir    : Admin
--------------------------------
Semen Tiga Roda
               3x65.000  195.000
Pasir (1 rit)            850.000
Paku 7cm        2x20.000  40.000
Keramik Granit Roman 60x60 Putih
Doff
              4x185.000  740.000
--------------------------------
TOTAL               Rp 1.825.000
Bayar               Rp 2.000.000
Kembali             Rp   175.000
--------------------------------
      *** TERIMA KASIH ***
    Barang yang sudah dibeli
   tidak dapat dikembalikan.''';

    expect(dokumen.teksPolos, diharapkan);
  });

  test('tidak ada baris yang melebihi lebar kertas', () {
    final dokumen = bangunStruk(
      profil: _profil,
      transaksi: _transaksiContoh(),
    );
    for (final baris in dokumen.baris) {
      expect(baris.teks.length, lessThanOrEqualTo(dokumen.lebar));
    }
  });

  test('baris Bayar dan Kembali tidak dicetak bila kasir tidak mengisinya', () {
    final dokumen = bangunStruk(
      profil: _profil,
      transaksi: Transaksi(
        nomorNota: '0143',
        waktu: DateTime(2026, 9, 17, 15, 0),
        items: [
          ItemBelanja(
            nama: 'Semen Tiga Roda',
            qty: 1,
            satuan: 'sak',
            hargaSatuan: 65000,
          ),
        ],
      ),
    );
    expect(dokumen.teksPolos, contains('TOTAL'));
    expect(dokumen.teksPolos, isNot(contains('Bayar')));
    expect(dokumen.teksPolos, isNot(contains('Kembali')));
  });

  test('kolom profil yang kosong tidak menyisakan baris kosong', () {
    final dokumen = bangunStruk(
      profil: const ProfilToko(namaToko: 'TB. MAJU JAYA'),
      transaksi: Transaksi(
        nomorNota: '0001',
        waktu: DateTime(2026, 9, 17, 8, 5),
        items: [
          ItemBelanja(nama: 'Semen', qty: 1, satuan: 'sak', hargaSatuan: 65000),
        ],
      ),
    );
    expect(dokumen.teksPolos, isNot(contains('Telp/WA')));
    expect(dokumen.teksPolos, isNot(contains('Kasir')));
    expect(dokumen.teksPolos, contains('*** TERIMA KASIH ***'));
    for (final baris in dokumen.baris) {
      expect(baris.teks.trim(), isNotEmpty);
    }
  });

  test('baris TOTAL dan nama toko ditandai tebal', () {
    final dokumen = bangunStruk(
      profil: _profil,
      transaksi: _transaksiContoh(),
    );
    final tebal = dokumen.baris
        .where((b) => b.gaya == GayaBaris.tebal)
        .map((b) => b.teks.trim())
        .toList();
    expect(tebal, contains('TB. SINAR BANGUNAN'));
    expect(tebal.any((t) => t.startsWith('TOTAL')), isTrue);
  });

  test('kertas 80mm menghasilkan baris selebar 48 kolom', () {
    final dokumen = bangunStruk(
      profil: const ProfilToko(
        namaToko: 'TB. SINAR BANGUNAN',
        lebarKertas: 80,
      ),
      transaksi: _transaksiContoh(),
    );
    expect(dokumen.lebar, 48);
    expect(
      dokumen.baris
          .firstWhere((b) => b.gaya == GayaBaris.pemisah)
          .teks
          .length,
      48,
    );
  });
}
```

- [ ] **Step 2: Jalankan test untuk memastikan gagal**

Jalankan: `flutter test test/domain/receipt/receipt_builder_test.dart`
Diharapkan: GAGAL dengan error kompilasi — `receipt_builder.dart` belum ada.

- [ ] **Step 3: Tulis implementasi minimal**

Buat `lib/domain/receipt/receipt_builder.dart`:

```dart
import '../item_belanja.dart';
import '../profil_toko.dart';
import '../transaksi.dart';
import '../uang.dart';
import 'kolom.dart';
import 'receipt_document.dart';

/// Satu-satunya tempat yang memutuskan bentuk struk. Penyaji ESC/POS, PDF,
/// dan widget hanya menerjemahkan hasilnya.
ReceiptDocument bangunStruk({
  required ProfilToko profil,
  required Transaksi transaksi,
}) {
  final lebar = profil.lebarKolom;
  final baris = <BarisStruk>[];

  void tulis(String teks, {GayaBaris gaya = GayaBaris.biasa}) {
    baris.add(BarisStruk(teks, gaya: gaya));
  }

  // Pergantian baris yang diketik pengguna dihormati, lalu tiap barisnya
  // dibungkus bila masih melebihi lebar kertas.
  List<String> pecah(String teks) => [
        for (final satuBaris in teks.split('\n')) ...bungkusKata(satuBaris, lebar),
      ];

  // Kepala
  for (final b in pecah(profil.namaToko)) {
    tulis(rataTengah(b, lebar), gaya: GayaBaris.tebal);
  }
  if (profil.alamat.isNotEmpty) {
    for (final b in pecah(profil.alamat)) {
      tulis(rataTengah(b, lebar));
    }
  }
  if (profil.noHp.isNotEmpty) {
    for (final b in pecah('Telp/WA: ${profil.noHp}')) {
      tulis(rataTengah(b, lebar));
    }
  }
  tulis(garisPemisah(lebar), gaya: GayaBaris.pemisah);

  // Keterangan nota
  tulis('${'No. Nota'.padRight(9)}: #${transaksi.nomorNota}');
  tulis('${'Tanggal'.padRight(9)}: ${_tanggalJam(transaksi.waktu)}');
  if (profil.namaKasir.isNotEmpty) {
    tulis('${'Kasir'.padRight(9)}: ${profil.namaKasir}');
  }
  tulis(garisPemisah(lebar), gaya: GayaBaris.pemisah);

  // Daftar barang
  for (final item in transaksi.items) {
    for (final b in susunBarisItem(
      nama: _namaTampil(item),
      rincian: _rincian(item),
      nominal: formatRupiah(item.subtotal),
      lebar: lebar,
    )) {
      tulis(b);
    }
  }
  tulis(garisPemisah(lebar), gaya: GayaBaris.pemisah);

  // Blok nominal. Semua angka dirata-kanankan pada lebar yang sama agar
  // titik ribuannya sejajar.
  final nilai = <int>[
    transaksi.total,
    if (transaksi.bayar != null) transaksi.bayar!,
    if (transaksi.kembali != null) transaksi.kembali!,
  ];
  final lebarAngka = nilai
      .map((n) => formatRupiah(n).length)
      .reduce((a, b) => a > b ? a : b);
  String rupiah(int n) => 'Rp ${rataKanan(formatRupiah(n), lebarAngka)}';

  tulis(
    duaKolom('TOTAL', rupiah(transaksi.total), lebar),
    gaya: GayaBaris.tebal,
  );
  if (transaksi.bayar != null) {
    tulis(duaKolom('Bayar', rupiah(transaksi.bayar!), lebar));
    tulis(duaKolom('Kembali', rupiah(transaksi.kembali!), lebar));
  }
  tulis(garisPemisah(lebar), gaya: GayaBaris.pemisah);

  // Kaki
  tulis(rataTengah('*** TERIMA KASIH ***', lebar));
  if (profil.catatan.isNotEmpty) {
    for (final b in pecah(profil.catatan)) {
      tulis(rataTengah(b, lebar));
    }
  }

  return ReceiptDocument(lebar: lebar, baris: baris);
}

String _namaTampil(ItemBelanja item) {
  if (item.qty == 1 && item.satuan.isNotEmpty) {
    return '${item.nama} (1 ${item.satuan})';
  }
  return item.nama;
}

/// Kosong bila jumlahnya satu; satuannya sudah menempel di nama.
String _rincian(ItemBelanja item) {
  if (item.qty == 1) return '';
  return '${formatJumlah(item.qty)}x${formatRupiah(item.hargaSatuan)}';
}

String _duaDigit(int n) => n.toString().padLeft(2, '0');

String _tanggalJam(DateTime waktu) =>
    '${_duaDigit(waktu.day)}/${_duaDigit(waktu.month)}/${waktu.year} '
    '${_duaDigit(waktu.hour)}:${_duaDigit(waktu.minute)}';
```

- [ ] **Step 4: Jalankan test untuk memastikan lulus**

Jalankan: `flutter test test/domain/receipt/receipt_builder_test.dart`
Diharapkan: PASS, 6 test.

- [ ] **Step 5: Jalankan seluruh test dan analisis**

Jalankan: `flutter test`
Diharapkan: PASS, seluruh berkas test hijau.

Jalankan: `flutter analyze`
Diharapkan: "No issues found!"

- [ ] **Step 6: Commit**

```bash
git add lib/domain/receipt/receipt_builder.dart test/domain/receipt/receipt_builder_test.dart
git commit -m "feat(domain): penyusun struk dari transaksi dan profil toko"
```

---

## Selesai bila

- `flutter test` hijau untuk seluruh berkas di `test/domain/`.
- `flutter analyze` tidak melaporkan masalah.
- Tidak ada berkas di `lib/domain/` yang mengimpor `package:flutter/*` selain lewat test.
- Struk contoh di spec dapat dihasilkan ulang huruf demi huruf oleh `bangunStruk`.

## Rencana berikutnya

- **Rencana 2 — Penyimpanan & Keluaran:** `data/` (sqflite, shared_preferences, backup) dan `output/` (ESC/POS, PDF, PNG, printer service).
- **Rencana 3 — Antarmuka & Rilis:** `state/`, seluruh layar `ui/`, konfigurasi Android, dan checklist rilis.
