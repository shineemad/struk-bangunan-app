import 'package:sqflite_common_ffi/sqflite_ffi.dart';

bool _ffiSiap = false;

/// Basis data sqflite dalam memori untuk pengujian.
///
/// Memakai `databaseFactoryFfiNoIsolate`, **bukan** `databaseFactoryFfi`:
/// varian isolate menjalankan sqflite di isolate terpisah, dan balasannya
/// tiba lewat event loop nyata. Di dalam `testWidgets`, badan test berjalan
/// dalam zona `FakeAsync`, dan balasan dari isolate nyata tidak pernah
/// dijadwalkan ulang ke zona palsu itu — `await bukaBasisdataUji()` (dan
/// setiap pemanggilan db sesudahnya) menggantung selamanya, terbukti lewat
/// probe langsung, bukan dugaan. Varian tanpa isolate berjalan di isolate
/// test yang sama, sehingga kompatibel dengan `pumpWidget`/`pumpAndSettle`
/// di sekitarnya. Jangan kembalikan ini ke `databaseFactoryFfi`.
Future<Database> bukaBasisdataUji() async {
  if (!_ffiSiap) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    _ffiSiap = true;
  }
  // Tanpa singleInstance: false, semua pemanggilan berbagi satu basis data
  // `:memory:` yang sama sehingga data antar test saling bocor.
  final db = await databaseFactoryFfiNoIsolate.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(singleInstance: false),
  );
  // Menyamai bukaBasisdata() (jalur aplikasi): PRAGMA ini per-koneksi, jadi
  // tanpa ini test berjalan di bawah aturan yang lebih longgar dari produksi.
  await db.execute('PRAGMA foreign_keys = ON');
  return db;
}
