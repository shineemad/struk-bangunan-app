import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

const int versiSkema = 1;

const String _namaBerkas = 'strukbangunan.db';

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
  return db.transaction(_ambilNomorNota);
}

/// Seperti [ambilNomorNotaBerikutnya], tetapi transaksi di sekelilingnya adalah
/// tanggung jawab pemanggil; fungsi ini tidak membuka transaksi sendiri.
Future<String> ambilNomorNotaBerikutnyaDalam(DatabaseExecutor txn) {
  return _ambilNomorNota(txn);
}

Future<String> _ambilNomorNota(DatabaseExecutor txn) async {
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
}
