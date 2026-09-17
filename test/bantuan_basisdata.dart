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
