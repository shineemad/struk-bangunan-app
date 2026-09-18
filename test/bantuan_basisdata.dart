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
  final db = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(singleInstance: false),
  );
  // Menyamai bukaBasisdata() (jalur aplikasi): PRAGMA ini per-koneksi, jadi
  // tanpa ini test berjalan di bawah aturan yang lebih longgar dari produksi.
  await db.execute('PRAGMA foreign_keys = ON');
  return db;
}
