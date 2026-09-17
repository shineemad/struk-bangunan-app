# StrukBangunan — Rencana 2: Penyimpanan Lokal

> **Untuk pekerja agentik:** SUB-SKILL WAJIB: pakai `superpowers:subagent-driven-development` (disarankan) atau `superpowers:executing-plans` untuk mengerjakan rencana ini tugas per tugas. Setiap langkah memakai checkbox (`- [ ]`) untuk penanda kemajuan.

**Goal:** Membangun seluruh lapisan penyimpanan lokal — basis data transaksi, profil toko, draf keranjang, daftar bahan favorit yang belajar sendiri, serta cadangkan/pulihkan — dengan pengujian yang berjalan di komputer tanpa emulator.

**Architecture:** `lib/data/` berdiri di atas `lib/domain/` yang sudah selesai di Rencana 1 dan tidak boleh mengubahnya. Repository mengembalikan objek domain, bukan `Map` mentah. Basis data memakai `sqflite`; profil dan draf memakai `shared_preferences`. Seluruh repository menerima objek `Database` dari luar, sehingga pengujian dapat menyuntikkan basis data dalam memori lewat `sqflite_common_ffi`.

**Tech Stack:** Flutter 3.38.5, Dart 3.10.4, `sqflite`, `path`, `shared_preferences`, `sqflite_common_ffi` (dev).

**Spec:** `docs/superpowers/specs/2026-09-17-strukbangunan-app-design.md` — terutama bagian 4 (Model data & penyimpanan).

**Rencana sebelumnya:** `docs/superpowers/plans/2026-09-17-struk-bangunan-01-fondasi-mesin-struk.md` (selesai, digabung ke `main` pada `932abf8`).

## Global Constraints

- Flutter 3.38.5, Dart 3.10.4, SDK `^3.10.0`. Android saja. Tidak ada izin `INTERNET`.
- **`lib/domain/` tidak boleh diubah oleh rencana ini.** Bila sebuah tugas merasa perlu mengubahnya, itu temuan yang dilaporkan, bukan perubahan yang dikerjakan diam-diam.
- **`lib/data/` tidak boleh mengimpor `package:flutter/*`.** Ia boleh mengimpor `sqflite`, `path`, dan `shared_preferences`, tetapi tidak boleh menyentuh widget.
- Semua nilai uang `int` rupiah. Kuantitas `double`, dibatasi dua angka desimal di titik masukan (ditegakkan di Rencana 4, bukan di sini).
- Versi dependensi **tidak dipatok manual**. Pakai `flutter pub add` agar pub memilih versi terbaru yang kompatibel — memaku versi adalah kesalahan yang sudah dilakukan PRD asli.
- Gerbang mutu tiap tugas: `flutter test` hijau, `flutter analyze` bersih, `dart format --output=none --set-exit-if-changed .` keluar dengan kode 0.
- Setiap tugas diakhiri satu commit. Push setelah tiap tugas.

## Struktur berkas yang dihasilkan rencana ini

| Berkas                               | Tanggung jawab                                                |
| ------------------------------------ | ------------------------------------------------------------- |
| `lib/data/basisdata.dart`            | Membuka basis data, skema, migrasi, dan nomor nota berikutnya |
| `lib/data/favorit_bawaan.dart`       | Daftar bahan bangunan bawaan beserta satuan lazimnya          |
| `lib/data/profil_repository.dart`    | Baca/tulis profil toko di `shared_preferences`                |
| `lib/data/draf_repository.dart`      | Simpan/pulihkan keranjang yang sedang berjalan                |
| `lib/data/transaksi_repository.dart` | Simpan nota, ambil riwayat, rekap harian                      |
| `lib/data/favorit_repository.dart`   | Daftar favorit, pembelajaran frekuensi, sembunyikan           |
| `lib/data/backup_service.dart`       | Ekspor seluruh data ke JSON dan pulihkan dengan validasi      |
| `test/bantuan_basisdata.dart`        | Penyiapan basis data dalam memori untuk pengujian             |

Rencana 3 akan memakai lapisan ini untuk penyaji keluaran (ESC/POS, PDF, PNG, printer, berbagi). Rencana 4 membangun antarmuka.

---

### Task 1: Dependensi dan harness uji basis data

**Files:**

- Modify: `pubspec.yaml`
- Create: `test/bantuan_basisdata.dart`
- Create: `test/data/bantuan_basisdata_test.dart`

**Interfaces:**

- Consumes: —
- Produces: `Future<Database> bukaBasisdataUji()` yang mengembalikan basis data sqflite dalam memori, dan `sqfliteFfiInit()` sudah terpanggil.

- [ ] **Step 1: Tambah dependensi**

```bash
flutter pub add sqflite path shared_preferences
flutter pub add dev:sqflite_common_ffi
```

Jangan menyunting versi di `pubspec.yaml` secara manual setelahnya.

- [ ] **Step 2: Tulis test yang gagal**

Buat `test/data/bantuan_basisdata_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import '../bantuan_basisdata.dart';

void main() {
  test('basis data dalam memori bisa dibuka dan ditulis', () async {
    final db = await bukaBasisdataUji();
    addTearDown(db.close);

    await db.execute('CREATE TABLE coba (nilai TEXT)');
    await db.insert('coba', {'nilai': 'halo'});
    final baris = await db.query('coba');

    expect(baris, hasLength(1));
    expect(baris.first['nilai'], 'halo');
  });

  test('tiap pemanggilan memberi basis data yang terpisah', () async {
    final a = await bukaBasisdataUji();
    final b = await bukaBasisdataUji();
    addTearDown(a.close);
    addTearDown(b.close);

    await a.execute('CREATE TABLE coba (nilai TEXT)');
    await a.insert('coba', {'nilai': 'hanya di a'});

    expect(
      () => b.query('coba'),
      throwsA(isA<Exception>()),
    );
  });
}
```

- [ ] **Step 3: Jalankan test untuk memastikan gagal**

Jalankan: `flutter test test/data/bantuan_basisdata_test.dart`
Diharapkan: GAGAL dengan error kompilasi — `bantuan_basisdata.dart` belum ada.

- [ ] **Step 4: Tulis implementasi minimal**

Buat `test/bantuan_basisdata.dart`:

```dart
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

bool _ffiSiap = false;

/// Basis data sqflite dalam memori untuk pengujian. Memakai FFI sehingga
/// berjalan di komputer tanpa emulator Android.
Future<Database> bukaBasisdataUji() async {
  if (!_ffiSiap) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    _ffiSiap = true;
  }
  // Tanpa singleInstance: false, semua pemanggilan berbagi satu basis data
  // `:memory:` yang sama sehingga data antar test saling bocor.
  return databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(singleInstance: false),
  );
}
```

**Dua hal yang tidak boleh diubah oleh tugas berikutnya.** Pustaka publik paket ini bernama `sqflite_ffi.dart`, bukan `sqflite_common_ffi.dart` — impor yang keliru gagal kompilasi. Dan karena `singleInstance: false`, setiap pemanggil memegang koneksinya sendiri dan **wajib menutupnya sendiri** dengan `addTearDown(db.close)`.

- [ ] **Step 5: Jalankan test untuk memastikan lulus**

Jalankan: `flutter test test/data/bantuan_basisdata_test.dart`
Diharapkan: PASS, 2 test.

**Bila gagal dengan `Failed to load dynamic library 'sqlite3.dll'`:** itu bukan kesalahan kode. `sqflite_common_ffi` memerlukan pustaka SQLite asli saat berjalan di Windows, dan berkas itu tidak selalu tersedia. Urutan penanganannya: (1) jalankan `flutter pub add dev:sqlite3_flutter_libs` lalu ulangi; (2) bila masih gagal, unduh `sqlite3.dll` 64-bit dari sqlite.org dan letakkan di akar repo — berkas itu **wajib** ditambahkan ke `.gitignore`, jangan di-commit. Laporkan jalur mana yang dipakai, karena Rencana 3 dan 4 bergantung pada harness yang sama.

- [ ] **Step 6: Gerbang mutu dan commit**

```bash
flutter test
flutter analyze
dart format --output=none --set-exit-if-changed .
git add pubspec.yaml pubspec.lock test/bantuan_basisdata.dart test/data/bantuan_basisdata_test.dart
git commit -m "chore: dependensi penyimpanan dan harness uji basis data"
```

---

### Task 2: Skema basis data

**Files:**

- Create: `lib/data/basisdata.dart`
- Test: `test/data/basisdata_test.dart`

**Interfaces:**

- Consumes: `bukaBasisdataUji()` dari `test/bantuan_basisdata.dart`
- Produces:
  - `const int versiSkema = 1;`
  - `Future<void> siapkanSkema(Database db)`
  - `Future<Database> bukaBasisdata()` — untuk aplikasi sungguhan, berkas `strukbangunan.db`
  - `Future<String> ambilNomorNotaBerikutnya(Database db)` — mengembalikan `'0001'`, `'0002'`, … dan menaikkan pencacah

- [ ] **Step 1: Tulis test yang gagal**

Buat `test/data/basisdata_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:struk_bangunan/data/basisdata.dart';

import '../bantuan_basisdata.dart';

void main() {
  test('skema membuat keempat tabel', () async {
    final db = await bukaBasisdataUji();
    addTearDown(db.close);
    await siapkanSkema(db);

    final tabel = (await db.query(
      'sqlite_master',
      columns: ['name'],
      where: 'type = ?',
      whereArgs: ['table'],
    )).map((b) => b['name'] as String).toSet();

    expect(tabel, containsAll(['meta', 'transaksi', 'item', 'favorit']));
  });

  test('versi skema tercatat di meta', () async {
    final db = await bukaBasisdataUji();
    addTearDown(db.close);
    await siapkanSkema(db);

    final baris = await db.query(
      'meta',
      where: 'kunci = ?',
      whereArgs: ['versi_skema'],
    );
    expect(baris.first['nilai'], versiSkema.toString());
  });

  test('nomor nota mulai dari 0001 dan naik satu per satu', () async {
    final db = await bukaBasisdataUji();
    addTearDown(db.close);
    await siapkanSkema(db);

    expect(await ambilNomorNotaBerikutnya(db), '0001');
    expect(await ambilNomorNotaBerikutnya(db), '0002');
    expect(await ambilNomorNotaBerikutnya(db), '0003');
  });

  test('nomor nota melewati empat digit tetap utuh', () async {
    final db = await bukaBasisdataUji();
    addTearDown(db.close);
    await siapkanSkema(db);
    await db.update(
      'meta',
      {'nilai': '9999'},
      where: 'kunci = ?',
      whereArgs: ['nomor_nota_berikutnya'],
    );

    expect(await ambilNomorNotaBerikutnya(db), '9999');
    expect(await ambilNomorNotaBerikutnya(db), '10000');
  });

  test('nomor nota tidak pernah terpakai dua kali meski dipanggil serentak',
      () async {
    final db = await bukaBasisdataUji();
    addTearDown(db.close);
    await siapkanSkema(db);

    // Semua pemanggilan dimulai sebelum satu pun ditunggu, sehingga baca dan
    // tulis pencacah benar-benar berebut. Versi berurutan (await di dalam
    // loop) tetap lulus meski transaksinya dibuang, jadi ia tidak menguji apa
    // pun yang namanya sebut.
    final hasil = await Future.wait([
      for (var i = 0; i < 50; i++) ambilNomorNotaBerikutnya(db),
    ]);

    expect(hasil.toSet(), hasLength(50));
  });

  test('menjalankan skema dua kali tidak melempar', () async {
    final db = await bukaBasisdataUji();
    addTearDown(db.close);
    await siapkanSkema(db);
    await siapkanSkema(db);

    final baris = await db.query(
      'meta',
      where: 'kunci = ?',
      whereArgs: ['nomor_nota_berikutnya'],
    );
    expect(baris, hasLength(1));
  });

  test('menghapus transaksi ikut menghapus itemnya', () async {
    final db = await bukaBasisdataUji();
    addTearDown(db.close);
    await siapkanSkema(db);
    await db.execute('PRAGMA foreign_keys = ON');

    final id = await db.insert('transaksi', {
      'nomor_nota': '0001',
      'waktu_ms': 1000,
      'total': 5000,
    });
    await db.insert('item', {
      'transaksi_id': id,
      'nama': 'Semen',
      'qty': 1.0,
      'satuan': 'sak',
      'harga_satuan': 5000,
      'subtotal': 5000,
      'urutan': 0,
    });

    await db.delete('transaksi', where: 'id = ?', whereArgs: [id]);
    expect(await db.query('item'), isEmpty);
  });
}
```

- [ ] **Step 2: Jalankan test untuk memastikan gagal**

Jalankan: `flutter test test/data/basisdata_test.dart`
Diharapkan: GAGAL dengan error kompilasi — `basisdata.dart` belum ada.

- [ ] **Step 3: Tulis implementasi minimal**

Buat `lib/data/basisdata.dart`:

```dart
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

const int versiSkema = 1;

const String _namaBerkas = 'strukbangunan.db';

/// Membuka basis data aplikasi. Pengujian tidak memakai fungsi ini; ia
/// menyuntikkan basis data dalam memori lalu memanggil [siapkanSkema].
Future<Database> bukaBasisdata() async {
  final folder = await getDatabasesPath();
  return openDatabase(
    p.join(folder, _namaBerkas),
    version: versiSkema,
    onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
    onCreate: (db, _) => siapkanSkema(db),
  );
}

/// Membuat tabel bila belum ada. Aman dijalankan berulang kali.
Future<void> siapkanSkema(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS meta (
      kunci TEXT PRIMARY KEY,
      nilai TEXT NOT NULL
    )
  ''');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS transaksi (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      nomor_nota TEXT NOT NULL UNIQUE,
      waktu_ms INTEGER NOT NULL,
      total INTEGER NOT NULL,
      bayar INTEGER,
      kembali INTEGER
    )
  ''');
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_transaksi_waktu ON transaksi(waktu_ms)',
  );

  await db.execute('''
    CREATE TABLE IF NOT EXISTS item (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      transaksi_id INTEGER NOT NULL
        REFERENCES transaksi(id) ON DELETE CASCADE,
      nama TEXT NOT NULL,
      qty REAL NOT NULL,
      satuan TEXT NOT NULL,
      harga_satuan INTEGER NOT NULL,
      subtotal INTEGER NOT NULL,
      urutan INTEGER NOT NULL
    )
  ''');
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_item_transaksi ON item(transaksi_id)',
  );

  await db.execute('''
    CREATE TABLE IF NOT EXISTS favorit (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      nama TEXT NOT NULL UNIQUE COLLATE NOCASE,
      satuan_terakhir TEXT NOT NULL DEFAULT '',
      jumlah_pakai INTEGER NOT NULL DEFAULT 0,
      terakhir_dipakai_ms INTEGER NOT NULL DEFAULT 0,
      bawaan INTEGER NOT NULL DEFAULT 0,
      disembunyikan INTEGER NOT NULL DEFAULT 0
    )
  ''');

  await db.insert('meta', {
    'kunci': 'versi_skema',
    'nilai': versiSkema.toString(),
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  await db.insert('meta', {
    'kunci': 'nomor_nota_berikutnya',
    'nilai': '1',
  }, conflictAlgorithm: ConflictAlgorithm.ignore);
}

/// Mengambil nomor nota berikutnya dan menaikkan pencacahnya dalam satu
/// transaksi, sehingga satu nomor tidak pernah terpakai dua kali.
Future<String> ambilNomorNotaBerikutnya(Database db) async {
  return db.transaction((txn) async {
    final baris = await txn.query(
      'meta',
      where: 'kunci = ?',
      whereArgs: ['nomor_nota_berikutnya'],
    );
    final sekarang = int.parse(baris.first['nilai'] as String);
    await txn.update(
      'meta',
      {'nilai': (sekarang + 1).toString()},
      where: 'kunci = ?',
      whereArgs: ['nomor_nota_berikutnya'],
    );
    return sekarang.toString().padLeft(4, '0');
  });
}
```

- [ ] **Step 4: Jalankan test untuk memastikan lulus**

Jalankan: `flutter test test/data/basisdata_test.dart`
Diharapkan: PASS, 7 test.

**Jebakan untuk Tugas 4, 5, dan 6:** `PRAGMA foreign_keys` berlaku per koneksi, dan `siapkanSkema` sengaja tidak menyalakannya. Aplikasi sungguhan menyalakannya di `onConfigure` milik `bukaBasisdata()`, tetapi basis data uji **tidak**. Artinya `ON DELETE CASCADE` mati di dalam test kecuali test itu menyalakannya sendiri. Jangan mengandalkan cascade di test tanpa menjalankan `PRAGMA foreign_keys = ON` lebih dulu.

- [ ] **Step 5: Gerbang mutu dan commit**

```bash
flutter test
flutter analyze
dart format --output=none --set-exit-if-changed .
git add lib/data/basisdata.dart test/data/basisdata_test.dart
git commit -m "feat(data): skema basis data dan nomor nota berurutan"
```

---

### Task 3: Profil toko dan draf keranjang

**Files:**

- Create: `lib/data/profil_repository.dart`
- Create: `lib/data/draf_repository.dart`
- Test: `test/data/profil_repository_test.dart`
- Test: `test/data/draf_repository_test.dart`

**Interfaces:**

- Consumes: `ProfilToko` dan `ItemBelanja` dari `lib/domain/`
- Produces:
  - `class ProfilRepository` dengan `Future<ProfilToko?> muat()` dan `Future<void> simpan(ProfilToko profil)`
  - `class DrafRepository` dengan `Future<List<ItemBelanja>> muat()`, `Future<void> simpan(List<ItemBelanja> items)`, `Future<void> hapus()`

Keduanya menerima `SharedPreferences` lewat konstruktor agar dapat diuji.

- [ ] **Step 1: Tulis test yang gagal**

Buat `test/data/profil_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:struk_bangunan/data/profil_repository.dart';
import 'package:struk_bangunan/domain/profil_toko.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  test('mengembalikan null bila toko belum pernah diatur', () async {
    final repo = ProfilRepository(await SharedPreferences.getInstance());
    expect(await repo.muat(), isNull);
  });

  test('menyimpan lalu memuat kembali seluruh kolom', () async {
    final repo = ProfilRepository(await SharedPreferences.getInstance());
    const asli = ProfilToko(
      namaToko: 'TB. SINAR BANGUNAN',
      alamat: 'Jl. Raya Merdeka No. 45',
      noHp: '0812-3456-7890',
      catatan: 'Barang yang sudah dibeli\ntidak dapat dikembalikan.',
      namaKasir: 'Admin',
      lebarKertas: 80,
    );

    await repo.simpan(asli);
    final hasil = (await repo.muat())!;

    expect(hasil.namaToko, asli.namaToko);
    expect(hasil.alamat, asli.alamat);
    expect(hasil.noHp, asli.noHp);
    expect(hasil.catatan, asli.catatan);
    expect(hasil.namaKasir, asli.namaKasir);
    expect(hasil.lebarKertas, 80);
  });

  test('kolom opsional yang kosong tetap kosong setelah dimuat', () async {
    final repo = ProfilRepository(await SharedPreferences.getInstance());
    await repo.simpan(const ProfilToko(namaToko: 'TB. MAJU JAYA'));
    final hasil = (await repo.muat())!;

    expect(hasil.namaToko, 'TB. MAJU JAYA');
    expect(hasil.alamat, '');
    expect(hasil.lebarKertas, 58);
  });
}
```

Buat `test/data/draf_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:struk_bangunan/data/draf_repository.dart';
import 'package:struk_bangunan/domain/item_belanja.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  test('draf kosong bila belum pernah disimpan', () async {
    final repo = DrafRepository(await SharedPreferences.getInstance());
    expect(await repo.muat(), isEmpty);
  });

  test('menyimpan lalu memulihkan keranjang beserta subtotalnya', () async {
    final repo = DrafRepository(await SharedPreferences.getInstance());
    final items = [
      ItemBelanja(
        nama: 'Semen Tiga Roda',
        qty: 3,
        satuan: 'sak',
        hargaSatuan: 65000,
      ),
      ItemBelanja(nama: 'Pasir', qty: 1.5, satuan: 'rit', hargaSatuan: 850000),
    ];

    await repo.simpan(items);
    final hasil = await repo.muat();

    expect(hasil, hasLength(2));
    expect(hasil[0].nama, 'Semen Tiga Roda');
    expect(hasil[0].qty, 3);
    expect(hasil[0].subtotal, 195000);
    expect(hasil[1].qty, 1.5);
    expect(hasil[1].subtotal, 1275000);
  });

  test('hapus mengosongkan draf', () async {
    final repo = DrafRepository(await SharedPreferences.getInstance());
    await repo.simpan([
      ItemBelanja(nama: 'Semen', qty: 1, satuan: 'sak', hargaSatuan: 65000),
    ]);
    await repo.hapus();

    expect(await repo.muat(), isEmpty);
  });

  test('draf yang rusak diperlakukan sebagai kosong, bukan melempar', () async {
    SharedPreferences.setMockInitialValues({'draf_keranjang': 'bukan json'});
    final repo = DrafRepository(await SharedPreferences.getInstance());

    expect(await repo.muat(), isEmpty);
  });
}
```

- [ ] **Step 2: Jalankan test untuk memastikan gagal**

Jalankan: `flutter test test/data/profil_repository_test.dart test/data/draf_repository_test.dart`
Diharapkan: GAGAL dengan error kompilasi — kedua berkas repository belum ada.

- [ ] **Step 3: Tulis implementasi minimal**

Buat `lib/data/profil_repository.dart`:

```dart
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/profil_toko.dart';

class ProfilRepository {
  final SharedPreferences _prefs;

  ProfilRepository(this._prefs);

  static const _kunciNama = 'nama_toko';
  static const _kunciAlamat = 'alamat_toko';
  static const _kunciNoHp = 'nohp_toko';
  static const _kunciCatatan = 'catatan_toko';
  static const _kunciKasir = 'nama_kasir';
  static const _kunciLebar = 'lebar_kertas';

  /// Null berarti toko belum pernah diatur, yang memicu layar onboarding.
  Future<ProfilToko?> muat() async {
    final nama = _prefs.getString(_kunciNama);
    if (nama == null || nama.isEmpty) return null;
    return ProfilToko(
      namaToko: nama,
      alamat: _prefs.getString(_kunciAlamat) ?? '',
      noHp: _prefs.getString(_kunciNoHp) ?? '',
      catatan: _prefs.getString(_kunciCatatan) ?? '',
      namaKasir: _prefs.getString(_kunciKasir) ?? '',
      lebarKertas: _prefs.getInt(_kunciLebar) ?? 58,
    );
  }

  Future<void> simpan(ProfilToko profil) async {
    await _prefs.setString(_kunciNama, profil.namaToko);
    await _prefs.setString(_kunciAlamat, profil.alamat);
    await _prefs.setString(_kunciNoHp, profil.noHp);
    await _prefs.setString(_kunciCatatan, profil.catatan);
    await _prefs.setString(_kunciKasir, profil.namaKasir);
    await _prefs.setInt(_kunciLebar, profil.lebarKertas);
  }
}
```

Buat `lib/data/draf_repository.dart`:

```dart
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/item_belanja.dart';

/// Keranjang yang sedang berjalan. Toko bangunan sering terinterupsi, jadi
/// keranjang setengah jadi tidak boleh hilang saat aplikasi tertutup.
class DrafRepository {
  final SharedPreferences _prefs;

  DrafRepository(this._prefs);

  static const _kunci = 'draf_keranjang';

  Future<List<ItemBelanja>> muat() async {
    final teks = _prefs.getString(_kunci);
    if (teks == null || teks.isEmpty) return [];
    try {
      final data = jsonDecode(teks);
      if (data is! List) return [];
      return data.map(_dariPeta).whereType<ItemBelanja>().toList();
    } on FormatException {
      return [];
    }
  }

  Future<void> simpan(List<ItemBelanja> items) async {
    final data = items
        .map(
          (i) => {
            'nama': i.nama,
            'qty': i.qty,
            'satuan': i.satuan,
            'harga_satuan': i.hargaSatuan,
          },
        )
        .toList();
    await _prefs.setString(_kunci, jsonEncode(data));
  }

  Future<void> hapus() => _prefs.remove(_kunci);

  /// Baris yang cacat dilewati, bukan menggagalkan seluruh draf.
  static ItemBelanja? _dariPeta(Object? data) {
    if (data is! Map) return null;
    final nama = data['nama'];
    final qty = data['qty'];
    final satuan = data['satuan'];
    final harga = data['harga_satuan'];
    if (nama is! String || qty is! num || satuan is! String || harga is! int) {
      return null;
    }
    try {
      return ItemBelanja(
        nama: nama,
        qty: qty.toDouble(),
        satuan: satuan,
        hargaSatuan: harga,
      );
    } on ArgumentError {
      return null;
    }
  }
}
```

- [ ] **Step 4: Jalankan test untuk memastikan lulus**

Jalankan: `flutter test test/data/profil_repository_test.dart test/data/draf_repository_test.dart`
Diharapkan: PASS, 7 test.

- [ ] **Step 5: Gerbang mutu dan commit**

```bash
flutter test
flutter analyze
dart format --output=none --set-exit-if-changed .
git add lib/data/profil_repository.dart lib/data/draf_repository.dart test/data/profil_repository_test.dart test/data/draf_repository_test.dart
git commit -m "feat(data): penyimpanan profil toko dan draf keranjang"
```

---

### Task 4: Riwayat transaksi

**Files:**

- Create: `lib/data/transaksi_repository.dart`
- Test: `test/data/transaksi_repository_test.dart`

**Interfaces:**

- Consumes: `siapkanSkema`, `ambilNomorNotaBerikutnyaDalam` dari `basisdata.dart`; `Transaksi` dan `ItemBelanja` dari domain
- Produces:
  - `class RekapHarian` dengan `int jumlahNota` dan `int totalRupiah`
  - `class TransaksiRepository(Database db)` dengan:
    - `Future<Transaksi> simpan({required List<ItemBelanja> items, required DateTime waktu, int? bayar})` — memberi nomor nota sendiri
    - `Future<List<Transaksi>> terbaru({int batas = 50})`
    - `Future<Transaksi?> ambil(String nomorNota)`
    - `Future<RekapHarian> rekap(DateTime hari)`

- [ ] **Step 1: Tulis test yang gagal**

Buat `test/data/transaksi_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:struk_bangunan/data/basisdata.dart';
import 'package:struk_bangunan/data/transaksi_repository.dart';
import 'package:struk_bangunan/domain/item_belanja.dart';

import '../bantuan_basisdata.dart';

ItemBelanja _item(String nama, double qty, int harga) =>
    ItemBelanja(nama: nama, qty: qty, satuan: 'sak', hargaSatuan: harga);

Future<(Database, TransaksiRepository)> _siap() async {
  final db = await bukaBasisdataUji();
  await siapkanSkema(db);
  return (db, TransaksiRepository(db));
}

void main() {
  test('menyimpan nota beserta itemnya dan memberi nomor nota', () async {
    final (db, repo) = await _siap();
    addTearDown(db.close);

    final nota = await repo.simpan(
      items: [_item('Semen', 3, 65000), _item('Paku', 2, 20000)],
      waktu: DateTime(2026, 9, 17, 14, 30),
      bayar: 300000,
    );

    expect(nota.nomorNota, '0001');
    expect(nota.total, 235000);
    expect(nota.kembali, 65000);
    expect(nota.items, hasLength(2));
  });

  test('nomor nota tidak pernah terpakai dua kali', () async {
    final (db, repo) = await _siap();
    addTearDown(db.close);

    final nomor = <String>[];
    for (var i = 0; i < 10; i++) {
      final nota = await repo.simpan(
        items: [_item('Semen', 1, 65000)],
        waktu: DateTime(2026, 9, 17, 9, i),
      );
      nomor.add(nota.nomorNota);
    }

    expect(nomor.toSet(), hasLength(10));
    expect(nomor.first, '0001');
    expect(nomor.last, '0010');
  });

  test('nota yang diambil kembali identik dengan yang disimpan', () async {
    final (db, repo) = await _siap();
    addTearDown(db.close);

    final asli = await repo.simpan(
      items: [
        _item('Semen Tiga Roda', 3, 65000),
        ItemBelanja(nama: 'Pasir', qty: 1.5, satuan: 'rit', hargaSatuan: 850000),
      ],
      waktu: DateTime(2026, 9, 17, 14, 30),
      bayar: 2000000,
    );

    final hasil = (await repo.ambil(asli.nomorNota))!;

    expect(hasil.nomorNota, asli.nomorNota);
    expect(hasil.waktu, asli.waktu);
    expect(hasil.bayar, 2000000);
    expect(hasil.total, asli.total);
    expect(hasil.items.map((i) => i.nama), ['Semen Tiga Roda', 'Pasir']);
    expect(hasil.items[1].qty, 1.5);
    expect(hasil.items[1].subtotal, asli.items[1].subtotal);
  });

  test('urutan item dipertahankan saat dimuat ulang', () async {
    final (db, repo) = await _siap();
    addTearDown(db.close);

    final asli = await repo.simpan(
      items: [
        _item('Pertama', 1, 1000),
        _item('Kedua', 1, 2000),
        _item('Ketiga', 1, 3000),
      ],
      waktu: DateTime(2026, 9, 17),
    );

    final hasil = (await repo.ambil(asli.nomorNota))!;
    expect(hasil.items.map((i) => i.nama), ['Pertama', 'Kedua', 'Ketiga']);
  });

  test('nomor nota yang tidak ada mengembalikan null', () async {
    final (db, repo) = await _siap();
    addTearDown(db.close);

    expect(await repo.ambil('9999'), isNull);
  });

  test('terbaru mengurutkan dari yang paling akhir', () async {
    final (db, repo) = await _siap();
    addTearDown(db.close);

    await repo.simpan(items: [_item('A', 1, 1000)], waktu: DateTime(2026, 9, 17, 8));
    await repo.simpan(items: [_item('B', 1, 1000)], waktu: DateTime(2026, 9, 17, 10));
    await repo.simpan(items: [_item('C', 1, 1000)], waktu: DateTime(2026, 9, 17, 9));

    final hasil = await repo.terbaru();
    expect(hasil.map((n) => n.items.first.nama), ['B', 'C', 'A']);
  });

  test('terbaru menghormati batas jumlah', () async {
    final (db, repo) = await _siap();
    addTearDown(db.close);

    for (var i = 0; i < 5; i++) {
      await repo.simpan(
        items: [_item('Semen', 1, 1000)],
        waktu: DateTime(2026, 9, 17, 8, i),
      );
    }

    expect(await repo.terbaru(batas: 2), hasLength(2));
  });

  test('rekap harian hanya menghitung nota pada hari itu', () async {
    final (db, repo) = await _siap();
    addTearDown(db.close);

    await repo.simpan(
      items: [_item('Semen', 1, 100000)],
      waktu: DateTime(2026, 9, 16, 23, 59),
    );
    await repo.simpan(
      items: [_item('Semen', 1, 200000)],
      waktu: DateTime(2026, 9, 17, 0, 0),
    );
    await repo.simpan(
      items: [_item('Semen', 1, 300000)],
      waktu: DateTime(2026, 9, 17, 23, 59),
    );
    await repo.simpan(
      items: [_item('Semen', 1, 400000)],
      waktu: DateTime(2026, 9, 18, 0, 0),
    );

    final rekap = await repo.rekap(DateTime(2026, 9, 17, 13));
    expect(rekap.jumlahNota, 2);
    expect(rekap.totalRupiah, 500000);
  });

  test('rekap hari tanpa transaksi bernilai nol, bukan null', () async {
    final (db, repo) = await _siap();
    addTearDown(db.close);

    final rekap = await repo.rekap(DateTime(2026, 9, 17));
    expect(rekap.jumlahNota, 0);
    expect(rekap.totalRupiah, 0);
  });

  test('nota tanpa uang bayar menyimpan bayar dan kembali sebagai null',
      () async {
    final (db, repo) = await _siap();
    addTearDown(db.close);

    final nota = await repo.simpan(
      items: [_item('Semen', 1, 65000)],
      waktu: DateTime(2026, 9, 17),
    );

    final hasil = (await repo.ambil(nota.nomorNota))!;
    expect(hasil.bayar, isNull);
    expect(hasil.kembali, isNull);
  });

  test('nota yang gagal tersimpan tidak membakar nomor nota', () async {
    final (db, repo) = await _siap();
    addTearDown(db.close);

    // Baris ini menyerobot '0001', sehingga penyisipan di dalam simpan()
    // melanggar UNIQUE dan seluruh transaksinya dibatalkan.
    await db.insert('transaksi', {
      'nomor_nota': '0001',
      'waktu_ms': 1000,
      'total': 1000,
    });

    await expectLater(
      repo.simpan(items: [_item('Semen', 1, 65000)], waktu: DateTime(2026, 9, 17)),
      throwsA(isA<DatabaseException>()),
    );

    final baris = await db.query(
      'meta',
      where: 'kunci = ?',
      whereArgs: ['nomor_nota_berikutnya'],
    );
    expect(baris.first['nilai'], '1');
  });
}
```

**Nomor nota dipesan di dalam transaksi, bukan sebelumnya.** Test terakhir itulah penjaganya. Bila `simpan` memanggil `ambilNomorNotaBerikutnya(_db)` lebih dulu — yang membuka transaksinya sendiri dan langsung commit — pencacah sudah naik sebelum barisnya disisipkan, sehingga nota yang gagal meninggalkan lubang permanen di penomoran. Karena itu `simpan` memakai `ambilNomorNotaBerikutnyaDalam(txn)` di dalam transaksi yang sama dengan penyisipannya. Memanggil `ambilNomorNotaBerikutnya(Database)` dari dalam transaksi akan **menggantung selamanya**, bukan gagal.

- [ ] **Step 2: Jalankan test untuk memastikan gagal**

Jalankan: `flutter test test/data/transaksi_repository_test.dart`
Diharapkan: GAGAL dengan error kompilasi — `transaksi_repository.dart` belum ada.

- [ ] **Step 3: Tulis implementasi minimal**

Buat `lib/data/transaksi_repository.dart`:

```dart
import 'package:sqflite/sqflite.dart';

import '../domain/item_belanja.dart';
import '../domain/transaksi.dart';
import 'basisdata.dart';

class RekapHarian {
  final int jumlahNota;
  final int totalRupiah;

  const RekapHarian({required this.jumlahNota, required this.totalRupiah});
}

class TransaksiRepository {
  final Database _db;

  TransaksiRepository(this._db);

  /// Menyimpan nota dan mengembalikannya lengkap dengan nomor nota yang baru
  /// dipesan. Nota yang sudah tersimpan tidak pernah diubah lagi.
  ///
  /// Nomor dipesan di dalam transaksi yang sama dengan penyisipan barisnya,
  /// sehingga nota yang gagal tersimpan tidak meninggalkan lubang di
  /// penomoran.
  Future<Transaksi> simpan({
    required List<ItemBelanja> items,
    required DateTime waktu,
    int? bayar,
  }) {
    return _db.transaction((txn) async {
      final nota = Transaksi(
        nomorNota: await ambilNomorNotaBerikutnyaDalam(txn),
        waktu: waktu,
        items: items,
        bayar: bayar,
      );

      final id = await txn.insert('transaksi', {
        'nomor_nota': nota.nomorNota,
        'waktu_ms': nota.waktu.millisecondsSinceEpoch,
        'total': nota.total,
        'bayar': nota.bayar,
        'kembali': nota.kembali,
      });

      for (var i = 0; i < nota.items.length; i++) {
        final item = nota.items[i];
        await txn.insert('item', {
          'transaksi_id': id,
          'nama': item.nama,
          'qty': item.qty,
          'satuan': item.satuan,
          'harga_satuan': item.hargaSatuan,
          'subtotal': item.subtotal,
          'urutan': i,
        });
      }

      return nota;
    });
  }

  Future<List<Transaksi>> terbaru({int batas = 50}) async {
    final baris = await _db.query(
      'transaksi',
      orderBy: 'waktu_ms DESC, id DESC',
      limit: batas,
    );
    return [for (final b in baris) await _rakit(b)];
  }

  Future<Transaksi?> ambil(String nomorNota) async {
    final baris = await _db.query(
      'transaksi',
      where: 'nomor_nota = ?',
      whereArgs: [nomorNota],
      limit: 1,
    );
    if (baris.isEmpty) return null;
    return _rakit(baris.first);
  }

  Future<RekapHarian> rekap(DateTime hari) async {
    final awal = DateTime(hari.year, hari.month, hari.day);
    final akhir = awal.add(const Duration(days: 1));

    final hasil = await _db.rawQuery(
      'SELECT COUNT(*) AS jumlah, COALESCE(SUM(total), 0) AS total '
      'FROM transaksi WHERE waktu_ms >= ? AND waktu_ms < ?',
      [awal.millisecondsSinceEpoch, akhir.millisecondsSinceEpoch],
    );

    return RekapHarian(
      jumlahNota: (hasil.first['jumlah'] as int?) ?? 0,
      totalRupiah: (hasil.first['total'] as int?) ?? 0,
    );
  }

  Future<Transaksi> _rakit(Map<String, Object?> baris) async {
    final barisItem = await _db.query(
      'item',
      where: 'transaksi_id = ?',
      whereArgs: [baris['id']],
      orderBy: 'urutan ASC',
    );

    return Transaksi(
      nomorNota: baris['nomor_nota'] as String,
      waktu: DateTime.fromMillisecondsSinceEpoch(baris['waktu_ms'] as int),
      bayar: baris['bayar'] as int?,
      items: [
        for (final i in barisItem)
          ItemBelanja(
            nama: i['nama'] as String,
            qty: (i['qty'] as num).toDouble(),
            satuan: i['satuan'] as String,
            hargaSatuan: i['harga_satuan'] as int,
          ),
      ],
    );
  }
}
```

- [ ] **Step 4: Jalankan test untuk memastikan lulus**

Jalankan: `flutter test test/data/transaksi_repository_test.dart`
Diharapkan: PASS, 11 test.

- [ ] **Step 5: Gerbang mutu dan commit**

```bash
flutter test
flutter analyze
dart format --output=none --set-exit-if-changed .
git add lib/data/transaksi_repository.dart test/data/transaksi_repository_test.dart
git commit -m "feat(data): riwayat transaksi dan rekap harian"
```

**Catatan untuk pengulas:** `_rakit` menyusun ulang `ItemBelanja` lewat konstruktornya, yang menghitung ulang subtotal dari `qty x harga_satuan` dan **mengabaikan** kolom `subtotal` yang tersimpan. Untuk data yang ditulis aplikasi ini keduanya selalu sama, karena keduanya memakai rumus yang sama. Kolom `subtotal` tetap disimpan karena spec mewajibkannya sebagai catatan historis, dan Task 6 memakainya saat mengekspor. Bila kelak aturan pembulatan berubah, ketidakcocokan itu akan muncul di sini — dan itulah alasannya dicatat, bukan dihapus.

---

### Task 5: Bahan favorit

**Files:**

- Create: `lib/data/favorit_bawaan.dart`
- Create: `lib/data/favorit_repository.dart`
- Test: `test/data/favorit_repository_test.dart`

**Interfaces:**

- Consumes: `siapkanSkema` dari `basisdata.dart`
- Produces:
  - `class BahanFavorit` dengan `String nama`, `String satuanTerakhir`, `int jumlahPakai`, `bool bawaan`
  - `const List<({String nama, String satuan})> favoritBawaan`
  - `class FavoritRepository(Database db)` dengan:
    - `Future<void> isiBawaanBilaKosong()`
    - `Future<List<BahanFavorit>> daftar({int batas = 40})`
    - `Future<void> catatPemakaian(String nama, String satuan, DateTime waktu)`
    - `Future<void> sembunyikan(String nama)`
    - `Future<void> munculkanSemua()`

- [ ] **Step 1: Tulis test yang gagal**

Buat `test/data/favorit_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:struk_bangunan/data/basisdata.dart';
import 'package:struk_bangunan/data/favorit_bawaan.dart';
import 'package:struk_bangunan/data/favorit_repository.dart';

import '../bantuan_basisdata.dart';

Future<(Database, FavoritRepository)> _siap() async {
  final db = await bukaBasisdataUji();
  await siapkanSkema(db);
  return (db, FavoritRepository(db));
}

void main() {
  test('daftar bawaan tidak kosong dan tidak punya nama kembar', () {
    expect(favoritBawaan, isNotEmpty);
    final nama = favoritBawaan.map((f) => f.nama.toLowerCase()).toList();
    expect(nama.toSet(), hasLength(nama.length));
  });

  test('bawaan terisi saat basis data masih kosong', () async {
    final (db, repo) = await _siap();
    addTearDown(db.close);

    await repo.isiBawaanBilaKosong();
    final hasil = await repo.daftar(batas: 1000);

    expect(hasil, hasLength(favoritBawaan.length));
    expect(hasil.every((f) => f.bawaan), isTrue);
  });

  test('bawaan tidak diisi ulang bila sudah ada isinya', () async {
    final (db, repo) = await _siap();
    addTearDown(db.close);

    await repo.isiBawaanBilaKosong();
    await repo.catatPemakaian('Bahan Karangan', 'pcs', DateTime(2026, 9, 17));
    await repo.isiBawaanBilaKosong();

    final hasil = await repo.daftar(batas: 1000);
    expect(hasil, hasLength(favoritBawaan.length + 1));
  });

  test('nama baru masuk daftar saat dipakai', () async {
    final (db, repo) = await _siap();
    addTearDown(db.close);

    await repo.catatPemakaian('Kawat Bendrat', 'kg', DateTime(2026, 9, 17));
    final hasil = await repo.daftar();

    expect(hasil.map((f) => f.nama), contains('Kawat Bendrat'));
    expect(hasil.first.satuanTerakhir, 'kg');
    expect(hasil.first.bawaan, isFalse);
  });

  test('nama yang sama dengan beda besar-kecil huruf tidak digandakan',
      () async {
    final (db, repo) = await _siap();
    addTearDown(db.close);

    await repo.catatPemakaian('Semen Gresik', 'sak', DateTime(2026, 9, 17));
    await repo.catatPemakaian('semen gresik', 'sak', DateTime(2026, 9, 17));

    final hasil = await repo.daftar(batas: 1000);
    final cocok = hasil.where((f) => f.nama.toLowerCase() == 'semen gresik');
    expect(cocok, hasLength(1));
    expect(cocok.first.jumlahPakai, 2);
  });

  test('yang paling sering dipakai naik ke atas', () async {
    final (db, repo) = await _siap();
    addTearDown(db.close);

    await repo.catatPemakaian('Jarang', 'pcs', DateTime(2026, 9, 17, 8));
    for (var i = 0; i < 5; i++) {
      await repo.catatPemakaian('Sering', 'sak', DateTime(2026, 9, 17, 9));
    }

    final hasil = await repo.daftar();
    expect(hasil.first.nama, 'Sering');
    expect(hasil.first.jumlahPakai, 5);
  });

  test('satuan terakhir diperbarui tiap pemakaian', () async {
    final (db, repo) = await _siap();
    addTearDown(db.close);

    await repo.catatPemakaian('Pasir', 'kubik', DateTime(2026, 9, 17, 8));
    await repo.catatPemakaian('Pasir', 'rit', DateTime(2026, 9, 17, 9));

    final hasil = await repo.daftar();
    expect(hasil.first.satuanTerakhir, 'rit');
  });

  test('yang disembunyikan tidak muncul di daftar', () async {
    final (db, repo) = await _siap();
    addTearDown(db.close);

    await repo.catatPemakaian('Semen', 'sak', DateTime(2026, 9, 17));
    await repo.sembunyikan('Semen');

    expect(await repo.daftar(), isEmpty);
  });

  test('menyembunyikan tidak menghapus datanya', () async {
    final (db, repo) = await _siap();
    addTearDown(db.close);

    await repo.catatPemakaian('Semen', 'sak', DateTime(2026, 9, 17));
    await repo.sembunyikan('Semen');
    await repo.munculkanSemua();

    final hasil = await repo.daftar();
    expect(hasil.first.nama, 'Semen');
    expect(hasil.first.jumlahPakai, 1);
  });

  test('daftar menghormati batas jumlah', () async {
    final (db, repo) = await _siap();
    addTearDown(db.close);

    await repo.isiBawaanBilaKosong();
    expect(await repo.daftar(batas: 5), hasLength(5));
  });
}
```

- [ ] **Step 2: Jalankan test untuk memastikan gagal**

Jalankan: `flutter test test/data/favorit_repository_test.dart`
Diharapkan: GAGAL dengan error kompilasi — kedua berkas belum ada.

- [ ] **Step 3: Tulis daftar bawaan**

Buat `lib/data/favorit_bawaan.dart`:

```dart
/// Bahan bangunan yang lazim dijual, dipakai sebagai titik mulai daftar
/// favorit. Yang tidak pernah dipakai akan tenggelam sendiri karena urutan
/// ditentukan frekuensi pemakaian toko itu. Harga sengaja tidak disimpan:
/// harga bahan bangunan berubah mingguan, dan harga basi yang terpakai
/// diam-diam jauh lebih berbahaya daripada mengetik ulang.
const List<({String nama, String satuan})> favoritBawaan = [
  (nama: 'Semen', satuan: 'sak'),
  (nama: 'Pasir', satuan: 'rit'),
  (nama: 'Batu Split', satuan: 'rit'),
  (nama: 'Batu Bata Merah', satuan: 'buah'),
  (nama: 'Batako', satuan: 'buah'),
  (nama: 'Bata Ringan', satuan: 'kubik'),
  (nama: 'Besi Beton 8mm', satuan: 'batang'),
  (nama: 'Besi Beton 10mm', satuan: 'batang'),
  (nama: 'Besi Beton 12mm', satuan: 'batang'),
  (nama: 'Kawat Bendrat', satuan: 'kg'),
  (nama: 'Paku 5cm', satuan: 'kg'),
  (nama: 'Paku 7cm', satuan: 'kg'),
  (nama: 'Paku 10cm', satuan: 'kg'),
  (nama: 'Triplek 3mm', satuan: 'lembar'),
  (nama: 'Triplek 9mm', satuan: 'lembar'),
  (nama: 'Kayu Kaso', satuan: 'batang'),
  (nama: 'Kayu Reng', satuan: 'batang'),
  (nama: 'Papan Cor', satuan: 'lembar'),
  (nama: 'Seng Gelombang', satuan: 'lembar'),
  (nama: 'Genteng', satuan: 'buah'),
  (nama: 'Nok Genteng', satuan: 'buah'),
  (nama: 'Asbes', satuan: 'lembar'),
  (nama: 'Cat Tembok', satuan: 'kaleng'),
  (nama: 'Cat Kayu', satuan: 'kaleng'),
  (nama: 'Thinner', satuan: 'kaleng'),
  (nama: 'Dempul', satuan: 'kg'),
  (nama: 'Kuas Cat', satuan: 'buah'),
  (nama: 'Rol Cat', satuan: 'buah'),
  (nama: 'Keramik Lantai', satuan: 'dus'),
  (nama: 'Keramik Dinding', satuan: 'dus'),
  (nama: 'Semen Nat', satuan: 'kg'),
  (nama: 'Lem Keramik', satuan: 'sak'),
  (nama: 'Pipa PVC 1/2 inci', satuan: 'batang'),
  (nama: 'Pipa PVC 3 inci', satuan: 'batang'),
  (nama: 'Sambungan Pipa', satuan: 'buah'),
  (nama: 'Lem Pipa', satuan: 'buah'),
  (nama: 'Kran Air', satuan: 'buah'),
  (nama: 'Kloset', satuan: 'buah'),
  (nama: 'Kabel Listrik', satuan: 'meter'),
  (nama: 'Saklar', satuan: 'buah'),
  (nama: 'Stop Kontak', satuan: 'buah'),
  (nama: 'Lampu LED', satuan: 'buah'),
  (nama: 'Fitting Lampu', satuan: 'buah'),
  (nama: 'Engsel Pintu', satuan: 'buah'),
  (nama: 'Kunci Pintu', satuan: 'buah'),
  (nama: 'Gembok', satuan: 'buah'),
  (nama: 'Amplas', satuan: 'lembar'),
  (nama: 'Ember Cor', satuan: 'buah'),
  (nama: 'Terpal', satuan: 'meter'),
  (nama: 'Cangkul', satuan: 'buah'),
];
```

- [ ] **Step 4: Tulis repository**

Buat `lib/data/favorit_repository.dart`:

```dart
import 'package:sqflite/sqflite.dart';

import 'favorit_bawaan.dart';

class BahanFavorit {
  final String nama;
  final String satuanTerakhir;
  final int jumlahPakai;
  final bool bawaan;

  const BahanFavorit({
    required this.nama,
    required this.satuanTerakhir,
    required this.jumlahPakai,
    required this.bawaan,
  });
}

/// Daftar bahan yang sering dijual. Urutannya ditentukan kebiasaan toko itu
/// sendiri, bukan oleh kami.
class FavoritRepository {
  final Database _db;

  FavoritRepository(this._db);

  Future<void> isiBawaanBilaKosong() async {
    final jumlah =
        Sqflite.firstIntValue(
          await _db.rawQuery('SELECT COUNT(*) FROM favorit'),
        ) ??
        0;
    if (jumlah > 0) return;

    final batch = _db.batch();
    for (final bahan in favoritBawaan) {
      batch.insert('favorit', {
        'nama': bahan.nama,
        'satuan_terakhir': bahan.satuan,
        'jumlah_pakai': 0,
        'terakhir_dipakai_ms': 0,
        'bawaan': 1,
        'disembunyikan': 0,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  Future<List<BahanFavorit>> daftar({int batas = 40}) async {
    final baris = await _db.query(
      'favorit',
      where: 'disembunyikan = 0',
      orderBy: 'jumlah_pakai DESC, terakhir_dipakai_ms DESC, nama ASC',
      limit: batas,
    );
    return [
      for (final b in baris)
        BahanFavorit(
          nama: b['nama'] as String,
          satuanTerakhir: b['satuan_terakhir'] as String,
          jumlahPakai: b['jumlah_pakai'] as int,
          bawaan: (b['bawaan'] as int) == 1,
        ),
    ];
  }

  /// Menaikkan hitungan pakai dan memperbarui satuan terakhir. Nama yang
  /// belum terdaftar ditambahkan sendiri — itulah cara daftar ini belajar.
  Future<void> catatPemakaian(
    String nama,
    String satuan,
    DateTime waktu,
  ) async {
    final namaRapi = nama.trim();
    if (namaRapi.isEmpty) return;

    await _db.transaction((txn) async {
      final terubah = await txn.rawUpdate(
        'UPDATE favorit SET jumlah_pakai = jumlah_pakai + 1, '
        'satuan_terakhir = ?, terakhir_dipakai_ms = ? '
        'WHERE nama = ? COLLATE NOCASE',
        [satuan.trim(), waktu.millisecondsSinceEpoch, namaRapi],
      );
      if (terubah > 0) return;

      await txn.insert('favorit', {
        'nama': namaRapi,
        'satuan_terakhir': satuan.trim(),
        'jumlah_pakai': 1,
        'terakhir_dipakai_ms': waktu.millisecondsSinceEpoch,
        'bawaan': 0,
        'disembunyikan': 0,
      });
    });
  }

  Future<void> sembunyikan(String nama) async {
    await _db.rawUpdate(
      'UPDATE favorit SET disembunyikan = 1 WHERE nama = ? COLLATE NOCASE',
      [nama.trim()],
    );
  }

  Future<void> munculkanSemua() async {
    await _db.update('favorit', {'disembunyikan': 0});
  }
}
```

- [ ] **Step 5: Jalankan test untuk memastikan lulus**

Jalankan: `flutter test test/data/favorit_repository_test.dart`
Diharapkan: PASS, 10 test.

- [ ] **Step 6: Gerbang mutu dan commit**

```bash
flutter test
flutter analyze
dart format --output=none --set-exit-if-changed .
git add lib/data/favorit_bawaan.dart lib/data/favorit_repository.dart test/data/favorit_repository_test.dart
git commit -m "feat(data): daftar bahan favorit yang belajar dari pemakaian"
```

---

### Task 6: Cadangkan dan pulihkan

**Files:**

- Create: `lib/data/backup_service.dart`
- Test: `test/data/backup_service_test.dart`

**Interfaces:**

- Consumes: `siapkanSkema` dari `basisdata.dart`, `ProfilRepository`, `TransaksiRepository`, `FavoritRepository`
- Produces:
  - `class BackupRusak implements Exception` dengan `String pesan`
  - `class BackupService(Database db, ProfilRepository profil)` dengan:
    - `Future<String> ekspor()` — mengembalikan teks JSON
    - `Future<void> impor(String teks)` — **menimpa seluruh data**, melempar `BackupRusak` bila berkas tidak sah
  - `const int versiBackup = 1;`

- [ ] **Step 1: Tulis test yang gagal**

Buat `test/data/backup_service_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:struk_bangunan/data/backup_service.dart';
import 'package:struk_bangunan/data/basisdata.dart';
import 'package:struk_bangunan/data/favorit_repository.dart';
import 'package:struk_bangunan/data/profil_repository.dart';
import 'package:struk_bangunan/data/transaksi_repository.dart';
import 'package:struk_bangunan/domain/item_belanja.dart';
import 'package:struk_bangunan/domain/profil_toko.dart';

import '../bantuan_basisdata.dart';

Future<(Database, BackupService, ProfilRepository)> _siap() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  final db = await bukaBasisdataUji();
  await siapkanSkema(db);
  final profil = ProfilRepository(await SharedPreferences.getInstance());
  return (db, BackupService(db, profil), profil);
}

Future<void> _isiContoh(Database db, ProfilRepository profil) async {
  await profil.simpan(
    const ProfilToko(
      namaToko: 'TB. SINAR BANGUNAN',
      alamat: 'Jl. Raya Merdeka No. 45',
      lebarKertas: 80,
    ),
  );
  final transaksi = TransaksiRepository(db);
  await transaksi.simpan(
    items: [
      ItemBelanja(nama: 'Semen', qty: 3, satuan: 'sak', hargaSatuan: 65000),
    ],
    waktu: DateTime(2026, 9, 17, 14, 30),
    bayar: 200000,
  );
  await FavoritRepository(db).catatPemakaian(
    'Semen',
    'sak',
    DateTime(2026, 9, 17),
  );
}

void main() {
  test('ekspor menghasilkan JSON bernomor versi', () async {
    final (db, backup, profil) = await _siap();
    addTearDown(db.close);
    await _isiContoh(db, profil);

    final data = jsonDecode(await backup.ekspor()) as Map<String, Object?>;

    expect(data['versi'], versiBackup);
    expect(data['profil'], isA<Map<String, Object?>>());
    expect(data['transaksi'], isA<List<Object?>>());
    expect(data['favorit'], isA<List<Object?>>());
    expect(data['meta'], isA<Map<String, Object?>>());
  });

  test('ekspor lalu impor menghasilkan data yang sama', () async {
    final (db, backup, profil) = await _siap();
    addTearDown(db.close);
    await _isiContoh(db, profil);

    final berkas = await backup.ekspor();
    await backup.impor(berkas);

    final nota = await TransaksiRepository(db).ambil('0001');
    expect(nota, isNotNull);
    expect(nota!.total, 195000);
    expect(nota.bayar, 200000);
    expect(nota.items.single.nama, 'Semen');

    final hasilProfil = (await profil.muat())!;
    expect(hasilProfil.namaToko, 'TB. SINAR BANGUNAN');
    expect(hasilProfil.lebarKertas, 80);

    final favorit = await FavoritRepository(db).daftar();
    expect(favorit.map((f) => f.nama), contains('Semen'));
  });

  test('impor menimpa, bukan menggabungkan', () async {
    final (db, backup, profil) = await _siap();
    addTearDown(db.close);
    await _isiContoh(db, profil);
    final berkas = await backup.ekspor();

    await TransaksiRepository(db).simpan(
      items: [ItemBelanja(nama: 'Paku', qty: 1, satuan: 'kg', hargaSatuan: 1000)],
      waktu: DateTime(2026, 9, 18),
    );
    expect(await TransaksiRepository(db).terbaru(), hasLength(2));

    await backup.impor(berkas);
    expect(await TransaksiRepository(db).terbaru(), hasLength(1));
  });

  test('nomor nota berikutnya ikut terbawa', () async {
    final (db, backup, profil) = await _siap();
    addTearDown(db.close);
    await _isiContoh(db, profil);

    final berkas = await backup.ekspor();
    await backup.impor(berkas);

    final nota = await TransaksiRepository(db).simpan(
      items: [ItemBelanja(nama: 'Paku', qty: 1, satuan: 'kg', hargaSatuan: 1000)],
      waktu: DateTime(2026, 9, 18),
    );
    expect(nota.nomorNota, '0002');
  });

  test('teks yang bukan JSON ditolak', () async {
    final (db, backup, _) = await _siap();
    addTearDown(db.close);

    expect(() => backup.impor('bukan json'), throwsA(isA<BackupRusak>()));
  });

  test('JSON tanpa versi ditolak', () async {
    final (db, backup, _) = await _siap();
    addTearDown(db.close);

    expect(
      () => backup.impor(jsonEncode({'profil': {}, 'transaksi': []})),
      throwsA(isA<BackupRusak>()),
    );
  });

  test('versi yang lebih baru ditolak', () async {
    final (db, backup, _) = await _siap();
    addTearDown(db.close);

    expect(
      () => backup.impor(jsonEncode({'versi': versiBackup + 1})),
      throwsA(isA<BackupRusak>()),
    );
  });

  test('data lama tetap utuh bila berkas ditolak', () async {
    final (db, backup, profil) = await _siap();
    addTearDown(db.close);
    await _isiContoh(db, profil);

    try {
      await backup.impor('berkas rusak');
    } on BackupRusak {
      // memang diharapkan
    }

    expect(await TransaksiRepository(db).ambil('0001'), isNotNull);
    expect((await profil.muat())!.namaToko, 'TB. SINAR BANGUNAN');
  });

  test('berkas dengan tipe kolom yang salah ditolak', () async {
    final (db, backup, _) = await _siap();
    addTearDown(db.close);

    final rusak = jsonEncode({
      'versi': versiBackup,
      'profil': {'nama_toko': 'TB. X'},
      'meta': {'nomor_nota_berikutnya': '1'},
      'favorit': [],
      'transaksi': [
        {'nomor_nota': 123, 'waktu_ms': 'kemarin', 'total': 'banyak'},
      ],
    });

    expect(() => backup.impor(rusak), throwsA(isA<BackupRusak>()));
  });
}
```

- [ ] **Step 2: Jalankan test untuk memastikan gagal**

Jalankan: `flutter test test/data/backup_service_test.dart`
Diharapkan: GAGAL dengan error kompilasi — `backup_service.dart` belum ada.

- [ ] **Step 3: Tulis implementasi minimal**

Buat `lib/data/backup_service.dart`:

```dart
import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../domain/profil_toko.dart';
import 'profil_repository.dart';

const int versiBackup = 1;

class BackupRusak implements Exception {
  final String pesan;

  const BackupRusak(this.pesan);

  @override
  String toString() => pesan;
}

/// Cadangkan seluruh data toko ke satu berkas JSON, dan pulihkan dengan
/// menimpa — bukan menggabungkan, karena penggabungan bisa menghasilkan nomor
/// nota ganda.
class BackupService {
  final Database _db;
  final ProfilRepository _profil;

  BackupService(this._db, this._profil);

  Future<String> ekspor() async {
    final profil = await _profil.muat();
    final meta = await _db.query('meta');

    return jsonEncode({
      'versi': versiBackup,
      'dibuat_ms': DateTime.now().millisecondsSinceEpoch,
      'profil': profil == null ? null : _profilKePeta(profil),
      'meta': {
        for (final b in meta) b['kunci'] as String: b['nilai'] as String,
      },
      'transaksi': await _db.query('transaksi', orderBy: 'id ASC'),
      'item': await _db.query('item', orderBy: 'id ASC'),
      'favorit': await _db.query('favorit', orderBy: 'id ASC'),
    });
  }

  /// Validasi selesai sepenuhnya sebelum satu baris pun dihapus, sehingga
  /// berkas yang cacat tidak pernah merusak data yang sedang dipakai.
  Future<void> impor(String teks) async {
    final data = _bacaJson(teks);
    final transaksi = _ambilDaftar(data, 'transaksi');
    final item = _ambilDaftar(data, 'item');
    final favorit = _ambilDaftar(data, 'favorit');

    _wajib(transaksi, {
      'nomor_nota': String,
      'waktu_ms': int,
      'total': int,
    });
    _wajib(item, {
      'transaksi_id': int,
      'nama': String,
      'qty': num,
      'satuan': String,
      'harga_satuan': int,
      'subtotal': int,
      'urutan': int,
    });
    _wajib(favorit, {'nama': String});

    await _db.transaction((txn) async {
      await txn.delete('item');
      await txn.delete('transaksi');
      await txn.delete('favorit');
      await txn.delete('meta');

      for (final baris in transaksi) {
        await txn.insert('transaksi', Map<String, Object?>.from(baris));
      }
      for (final baris in item) {
        await txn.insert('item', Map<String, Object?>.from(baris));
      }
      for (final baris in favorit) {
        await txn.insert('favorit', Map<String, Object?>.from(baris));
      }

      final meta = data['meta'];
      if (meta is Map) {
        for (final entri in meta.entries) {
          await txn.insert('meta', {
            'kunci': entri.key.toString(),
            'nilai': entri.value.toString(),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });

    final profil = data['profil'];
    if (profil is Map) {
      await _profil.simpan(_petaKeProfil(profil));
    }
  }

  Map<String, Object?> _bacaJson(String teks) {
    Object? mentah;
    try {
      mentah = jsonDecode(teks);
    } on FormatException {
      throw const BackupRusak('Berkas ini bukan berkas cadangan yang sah.');
    }
    if (mentah is! Map<String, Object?>) {
      throw const BackupRusak('Isi berkas cadangan tidak dikenali.');
    }
    final versi = mentah['versi'];
    if (versi is! int) {
      throw const BackupRusak('Berkas cadangan tidak mencantumkan versi.');
    }
    if (versi > versiBackup) {
      throw const BackupRusak(
        'Berkas ini dibuat aplikasi versi lebih baru. Perbarui aplikasi dulu.',
      );
    }
    return mentah;
  }

  List<Map<Object?, Object?>> _ambilDaftar(
    Map<String, Object?> data,
    String kunci,
  ) {
    final nilai = data[kunci];
    if (nilai == null) return const [];
    if (nilai is! List) {
      throw BackupRusak('Bagian "$kunci" pada berkas cadangan rusak.');
    }
    return [
      for (final baris in nilai)
        if (baris is Map<Object?, Object?>)
          baris
        else
          throw BackupRusak('Bagian "$kunci" pada berkas cadangan rusak.'),
    ];
  }

  void _wajib(List<Map<Object?, Object?>> baris, Map<String, Type> kolom) {
    for (final b in baris) {
      for (final entri in kolom.entries) {
        final nilai = b[entri.key];
        final cocok = switch (entri.value) {
          const (String) => nilai is String,
          const (int) => nilai is int,
          const (num) => nilai is num,
          _ => false,
        };
        if (!cocok) {
          throw BackupRusak(
            'Kolom "${entri.key}" pada berkas cadangan tidak sesuai.',
          );
        }
      }
    }
  }

  Map<String, Object?> _profilKePeta(ProfilToko p) => {
    'nama_toko': p.namaToko,
    'alamat_toko': p.alamat,
    'nohp_toko': p.noHp,
    'catatan_toko': p.catatan,
    'nama_kasir': p.namaKasir,
    'lebar_kertas': p.lebarKertas,
  };

  ProfilToko _petaKeProfil(Map<Object?, Object?> p) => ProfilToko(
    namaToko: p['nama_toko'] as String? ?? '',
    alamat: p['alamat_toko'] as String? ?? '',
    noHp: p['nohp_toko'] as String? ?? '',
    catatan: p['catatan_toko'] as String? ?? '',
    namaKasir: p['nama_kasir'] as String? ?? '',
    lebarKertas: p['lebar_kertas'] as int? ?? 58,
  );
}
```

- [ ] **Step 4: Jalankan test untuk memastikan lulus**

Jalankan: `flutter test test/data/backup_service_test.dart`
Diharapkan: PASS, 9 test.

- [ ] **Step 5: Gerbang mutu dan commit**

```bash
flutter test
flutter analyze
dart format --output=none --set-exit-if-changed .
git add lib/data/backup_service.dart test/data/backup_service_test.dart
git commit -m "feat(data): cadangkan dan pulihkan data toko"
```

---

## Selesai bila

- `flutter test` hijau untuk seluruh berkas di `test/data/`.
- `flutter analyze` tidak melaporkan masalah dan `dart format --set-exit-if-changed` keluar dengan kode 0.
- Tidak ada berkas di `lib/data/` yang mengimpor `package:flutter/*`.
- Tidak ada berkas di `lib/domain/` yang berubah.
- Ekspor lalu impor menghasilkan data yang identik, dan berkas cadangan yang cacat tidak pernah merusak data yang sedang dipakai.

## Rencana berikutnya

- **Rencana 3 — Keluaran:** `output/` (ESC/POS, PDF, PNG lewat `RepaintBoundary`, layanan printer Bluetooth, berbagi).
- **Rencana 4 — Antarmuka & Rilis:** `state/`, seluruh layar `ui/`, pembatasan kuantitas dua desimal di titik masukan, konfigurasi Android, dan checklist rilis.

## Temuan yang diwariskan dari Rencana 1

Diperiksa ulang oleh rencana ini atau diteruskan ke rencana berikutnya:

- Kuantitas harus dibatasi dua angka desimal **di titik masukan** (Rencana 4). Tanpa itu struk bisa terbaca `0,33 x 1.000 = 333`.
- Batas atas kuantitas ditegakkan bersama pembatasan di atas; nilai ekstrem membuat pembulatan subtotal melempar `UnsupportedError`, bukan `ArgumentError`.
- `lebarKertas` selain 58 dan 80 diam-diam dianggap 58. Batasan itu ditegakkan di layar Pengaturan (Rencana 4).
- `cupertino_icons` adalah dependensi mati; buang saat tugas UI.
- Build rilis masih ditandatangani kunci debug; wajib ditutup sebelum rilis.
- `pubspec.yaml` `description`, `README.md`, dan `lib/main.dart` masih bawaan `flutter create`.
