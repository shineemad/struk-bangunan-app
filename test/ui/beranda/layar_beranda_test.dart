import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:struk_bangunan/data/basisdata.dart';
import 'package:struk_bangunan/data/draf_repository.dart';
import 'package:struk_bangunan/data/favorit_repository.dart';
import 'package:struk_bangunan/data/pengaturan_keluaran_repository.dart';
import 'package:struk_bangunan/data/profil_repository.dart';
import 'package:struk_bangunan/data/transaksi_repository.dart';
import 'package:struk_bangunan/domain/item_belanja.dart';
import 'package:struk_bangunan/domain/profil_toko.dart';
import 'package:struk_bangunan/domain/transaksi.dart';
import 'package:struk_bangunan/state/favorit_controller.dart';
import 'package:struk_bangunan/state/keranjang_controller.dart';
import 'package:struk_bangunan/state/pengirim_struk.dart';
import 'package:struk_bangunan/ui/beranda/layar_beranda.dart';
import 'package:struk_bangunan/ui/kasir/layar_kasir.dart';
import 'package:struk_bangunan/ui/pengaturan/layar_pengaturan.dart';
import 'package:struk_bangunan/ui/tema.dart';

import '../../bantuan_basisdata.dart';

/// Tidak melakukan apa-apa: test di berkas ini tidak pernah menekan tombol
/// kirim WA, tapi konstruktor `LayarBeranda` mewajibkan pengirim.
class _PengirimPalsu implements PengirimStrukKontrak {
  @override
  Future<void> kirim({
    required GlobalKey kunciBoundary,
    required Transaksi nota,
    required int lebarKolom,
  }) async {}
}

Future<void> _pasang(
  WidgetTester tester,
  SharedPreferences prefs, {
  Size? ukuran,
}) async {
  if (ukuran != null) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = ukuran;
  } else {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
  }
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final db = await bukaBasisdataUji();
  await siapkanSkema(db);
  addTearDown(db.close);

  // MultiProvider dipasang membungkus MaterialApp, bukan di dalam `home` —
  // LayarKasir yang didorong Beranda lewat Navigator.push butuh kedua
  // controller ini dari rute barunya sendiri.
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => KeranjangController(
            draf: DrafRepository(prefs),
            transaksi: TransaksiRepository(db),
            favorit: FavoritRepository(db),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => FavoritController(FavoritRepository(db)),
        ),
      ],
      child: MaterialApp(
        theme: temaTerang(),
        home: LayarBeranda(
          profil: ProfilRepository(prefs),
          pengaturan: PengaturanKeluaranRepository(prefs),
          pengirim: _PengirimPalsu(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('menampilkan nama toko dari profil tersimpan', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await ProfilRepository(
      prefs,
    ).simpan(const ProfilToko(namaToko: 'Toko Makmur Jaya'));

    await _pasang(tester, prefs);

    expect(find.text('Toko Makmur Jaya'), findsOneWidget);
  });

  testWidgets('memakai nama bawaan bila profil belum pernah diatur', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await _pasang(tester, prefs);

    expect(find.text('TOKO BANGUNAN'), findsOneWidget);
  });

  testWidgets('tombol transaksi baru membuka layar kasir', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await _pasang(tester, prefs);

    await tester.tap(find.byKey(const Key('tombol-transaksi-baru-beranda')));
    await tester.pumpAndSettle();

    expect(find.byType(LayarKasir), findsOneWidget);
  });

  testWidgets('tombol pengaturan membuka layar pengaturan', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await _pasang(tester, prefs);

    await tester.tap(find.byKey(const Key('tombol-pengaturan')));
    await tester.pumpAndSettle();

    expect(find.byType(LayarPengaturan), findsOneWidget);
  });

  testWidgets('menyimpan pengaturan memperbarui nama toko di beranda', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await ProfilRepository(
      prefs,
    ).simpan(const ProfilToko(namaToko: 'Toko Lama'));

    await _pasang(tester, prefs);
    expect(find.text('Toko Lama'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tombol-pengaturan')));
    await tester.pumpAndSettle();

    final kolomNama = find.byKey(const Key('kolom-nama-toko'));
    await tester.dragUntilVisible(
      kolomNama,
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    await tester.enterText(kolomNama, 'Toko Baru Sejahtera');
    await tester.pump();

    final tombolSimpan = find.byKey(const Key('tombol-simpan-pengaturan'));
    await tester.dragUntilVisible(
      tombolSimpan,
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    await tester.tap(tombolSimpan);
    await tester.pumpAndSettle();

    // LayarPengaturan tidak menutup diri sendiri setelah simpan — kasir
    // menekan tombol kembali secara manual, sama seperti pengguna sungguhan.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byType(LayarPengaturan), findsNothing);
    expect(find.text('Toko Baru Sejahtera'), findsOneWidget);
    expect(find.text('Toko Lama'), findsNothing);
  });

  testWidgets('menawarkan melanjutkan keranjang bila draf belum kosong', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await DrafRepository(prefs).simpan([
      ItemBelanja(nama: 'Semen', qty: 3, satuan: 'sak', hargaSatuan: 65000),
    ]);

    await _pasang(tester, prefs);

    final tombol = tester.widget<FilledButton>(
      find.byKey(const Key('tombol-transaksi-baru-beranda')),
    );
    final teks = (tombol.child as Text).data!;

    expect(teks, isNot('TRANSAKSI BARU'));
    expect(teks, contains('1 barang'));
    expect(teks, contains('Rp 195.000'));
  });

  testWidgets('tidak meluap pada layar pendek 360x640', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await _pasang(tester, prefs, ukuran: const Size(360, 640));

    expect(tester.takeException(), isNull);
  });
}
