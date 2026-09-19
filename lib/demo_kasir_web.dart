/// Entrypoint pratinjau di browser: `flutter run -d chrome -t lib/demo_kasir_web.dart`.
///
/// Aplikasi sungguhannya **tidak bisa** jalan di web — `sqflite` dan plugin
/// printer tidak punya dukungan web. Di sini hanya lapisan basis data yang
/// diganti stand-in dalam memori; tema, formatter, mesin struk, dan seluruh
/// layar adalah kode produksi apa adanya. Draf keranjang tetap nyata, karena
/// `SharedPreferences` memang jalan di browser.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'data/draf_repository.dart';
import 'data/favorit_repository.dart';
import 'data/pengaturan_keluaran_repository.dart';
import 'data/profil_repository.dart';
import 'data/transaksi_repository.dart';
import 'domain/transaksi.dart';
import 'output/png_renderer.dart';
import 'state/favorit_controller.dart';
import 'state/keranjang_controller.dart';
import 'state/pengirim_struk.dart';
import 'ui/beranda/layar_beranda.dart';
import 'ui/tema.dart';

/// Lebar bingkai ponsel. Design system menargetkan 360-390 dp; tanpa bingkai
/// ini tata letak terlihat melar dan menyesatkan di layar desktop.
const _lebarPonsel = 390.0;

final _pesan = GlobalKey<ScaffoldMessengerState>();

void main() => runApp(const DemoKasirWeb());

/// Menunggu `SharedPreferences` sebelum memasang `MultiProvider`+`MaterialApp`
/// sungguhan. `MultiProvider` wajib membungkus `MaterialApp` (bukan berada
/// di dalam `home`) — persis seperti `main.dart` — supaya `LayarKasir` yang
/// didorong Beranda lewat `Navigator.push` tetap bisa membaca kedua
/// controller dari rute barunya sendiri.
class DemoKasirWeb extends StatelessWidget {
  const DemoKasirWeb({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, hasil) {
        final prefs = hasil.data;
        if (prefs == null) {
          return const MaterialApp(
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }
        return _Demo(prefs: prefs);
      },
    );
  }
}

class _Demo extends StatefulWidget {
  const _Demo({required this.prefs});

  final SharedPreferences prefs;

  @override
  State<_Demo> createState() => _DemoState();
}

class _DemoState extends State<_Demo> {
  final _db = _DbPalsu();

  late final _keranjang = _KeranjangDemo(
    draf: DrafRepository(widget.prefs),
    transaksi: TransaksiRepository(_db),
    favorit: FavoritRepository(_db),
  );
  late final _favorit = _FavoritDemo(FavoritRepository(_db));

  @override
  void dispose() {
    _keranjang.dispose();
    _favorit.dispose();
    super.dispose();
  }

  void _lapor(String teks) {
    _pesan.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(teks)));
  }

  @override
  Widget build(BuildContext context) {
    // Tipe provider ditulis eksplisit: layar membaca `KeranjangController`,
    // bukan subkelas demonya.
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<KeranjangController>.value(value: _keranjang),
        ChangeNotifierProvider<FavoritController>.value(value: _favorit),
      ],
      child: MaterialApp(
        title: 'StrukBangunan — pratinjau web',
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: _pesan,
        theme: temaTerang(),
        // `builder` membungkus setiap rute, termasuk layar yang didorong
        // Navigator — kalau bingkainya dipasang di `home` saja, rute baru
        // memenuhi seluruh jendela dan ilusi ponselnya pecah.
        builder: (context, child) => ColoredBox(
          color: Warna.garis,
          child: Center(
            child: SizedBox(
              width: _lebarPonsel,
              child: ClipRect(child: child),
            ),
          ),
        ),
        home: LayarBeranda(
          profil: ProfilRepository(widget.prefs),
          pengaturan: PengaturanKeluaranRepository(widget.prefs),
          pengirim: _PengirimDemo(_lapor),
        ),
      ),
    );
  }
}

/// Keranjang produksi, kecuali penyimpanan notanya. `muatDraf`, `tambah`,
/// `hapusPada`, dan `kosongkan` hanya menyentuh `SharedPreferences`, jadi
/// keduanya tetap berjalan sungguhan di browser.
class _KeranjangDemo extends KeranjangController {
  _KeranjangDemo({
    required super.draf,
    required super.transaksi,
    required super.favorit,
  });

  int _nomor = 0;

  @override
  Future<Transaksi> simpan({int? bayar, DateTime? waktu}) async {
    final nota = Transaksi(
      nomorNota: (++_nomor).toString().padLeft(4, '0'),
      waktu: waktu ?? DateTime.now(),
      items: items,
      bayar: bayar,
    );
    await kosongkan();
    return nota;
  }
}

class _FavoritDemo extends FavoritController {
  _FavoritDemo(super.repo);

  final _isi = const [
    BahanFavorit(
      nama: 'Semen',
      satuanTerakhir: 'sak',
      jumlahPakai: 42,
      bawaan: true,
    ),
    BahanFavorit(
      nama: 'Pasir',
      satuanTerakhir: 'rit',
      jumlahPakai: 31,
      bawaan: true,
    ),
    BahanFavorit(
      nama: 'Batu Bata Merah',
      satuanTerakhir: 'buah',
      jumlahPakai: 18,
      bawaan: true,
    ),
    BahanFavorit(
      nama: 'Besi Beton 10mm',
      satuanTerakhir: 'batang',
      jumlahPakai: 9,
      bawaan: true,
    ),
    BahanFavorit(
      nama: 'Cat Tembok',
      satuanTerakhir: 'kaleng',
      jumlahPakai: 4,
      bawaan: true,
    ),
  ];

  final _disembunyikan = <String>{};

  @override
  List<BahanFavorit> get daftar => List.unmodifiable(
    _isi.where((bahan) => !_disembunyikan.contains(bahan.nama)),
  );

  @override
  bool get sedangMemuat => false;

  @override
  Future<void> muat() async => notifyListeners();

  @override
  Future<void> sembunyikan(String nama) async {
    _disembunyikan.add(nama);
    notifyListeners();
  }
}

/// Merender PNG-nya sungguhan — itu jalan di browser — lalu berhenti di situ.
/// `ShareService` memakai `dart:io`, jadi berbagi berkas hanya ada di Android.
class _PengirimDemo implements PengirimStrukKontrak {
  _PengirimDemo(this._lapor);

  final void Function(String teks) _lapor;

  @override
  Future<void> kirim({
    required GlobalKey kunciBoundary,
    required Transaksi nota,
    required int lebarKolom,
  }) async {
    final png = await ambilPng(kunciBoundary);
    _lapor(
      'Struk #${nota.nomorNota} dirender ${(png.lengthInBytes / 1024).round()} KB. '
      'Berbagi ke WhatsApp hanya jalan di Android.',
    );
  }
}

/// Hanya untuk memenuhi konstruktor repository yang tidak pernah dipakai di
/// pratinjau ini. Setiap pemanggilan sungguhan ke basis data adalah bug.
class _DbPalsu implements Database {
  @override
  dynamic noSuchMethod(Invocation panggilan) => throw UnsupportedError(
    'Pratinjau web tidak punya basis data: ${panggilan.memberName}',
  );
}
