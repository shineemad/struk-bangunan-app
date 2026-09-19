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
import 'package:struk_bangunan/ui/struk/layar_pratinjau.dart';
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
  List<ItemBelanja> penjualanHariIni = const [],
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

  if (penjualanHariIni.isNotEmpty) {
    await TransaksiRepository(
      db,
    ).simpan(items: penjualanHariIni, waktu: DateTime.now());
  }

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
          transaksi: TransaksiRepository(db),
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

    // Design system bagian 7: tombol sekunder tinggi minimal 48 (Ukuran.sentuh).
    final tinggiTombol = tester
        .getSize(find.byKey(const Key('tombol-pengaturan')))
        .height;
    expect(tinggiTombol, greaterThanOrEqualTo(Ukuran.sentuh));

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

  testWidgets(
    'menyimpan pengaturan memperbarui nama toko sampai ke struk pratinjau',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await ProfilRepository(
        prefs,
      ).simpan(const ProfilToko(namaToko: 'Toko Lama'));

      await _pasang(tester, prefs);

      // Ubah nama toko lewat Pengaturan, seperti test di atas.
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
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // Biarkan SnackBar 'Pengaturan tersimpan.' usai sepenuhnya — ia milik
      // ScaffoldMessenger di akar MaterialApp, jadi kalau masih tampil ia
      // menutupi tombol-kirim di layar Kasir/Pratinjau berikutnya.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // Tempuh sampai Pratinjau: Kasir -> isi satu barang -> BUAT STRUK.
      await tester.tap(find.byKey(const Key('tombol-transaksi-baru-beranda')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('kolom-nama')), 'Semen');
      await tester.enterText(find.byKey(const Key('kolom-harga')), '65000');
      await tester.pump();
      await tester.tap(find.byKey(const Key('tombol-tambah')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tombol-kirim')));
      await tester.pumpAndSettle();

      expect(find.byType(LayarPratinjau), findsOneWidget);
      // Nama toko yang baru harus sampai ke struk pembeli, bukan cuma
      // terlihat di Beranda — profil basi berarti struk salah nama toko.
      expect(
        find.descendant(
          of: find.byType(LayarPratinjau),
          matching: find.textContaining('Toko Baru Sejahtera'),
        ),
        findsWidgets,
      );
    },
  );

  testWidgets('menampilkan rekap penjualan hari ini', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await _pasang(
      tester,
      prefs,
      penjualanHariIni: [
        ItemBelanja(nama: 'Semen', qty: 3, satuan: 'sak', hargaSatuan: 65000),
      ],
    );

    expect(find.text('Penjualan hari ini'), findsOneWidget);
    expect(find.text('Rp 195.000'), findsOneWidget);
    expect(find.text('1 nota'), findsOneWidget);
  });

  testWidgets('rekap menunjukkan nol sebelum ada penjualan', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await _pasang(tester, prefs);

    expect(find.text('Rp 0'), findsOneWidget);
    expect(find.text('0 nota'), findsOneWidget);
  });

  testWidgets(
    'melanjutkan keranjang: label tombol utama tidak membungkus dan tombol '
    'pengaturan tetap terjangkau di layar pendek 360x640',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await DrafRepository(prefs).simpan([
        ItemBelanja(nama: 'Semen', qty: 3, satuan: 'sak', hargaSatuan: 65000),
      ]);

      await _pasang(tester, prefs, ukuran: const Size(360, 640));

      final tombol = tester.widget<FilledButton>(
        find.byKey(const Key('tombol-transaksi-baru-beranda')),
      );
      expect((tombol.child as Text).data, 'LANJUTKAN');

      // Tinggi tombol tepat Ukuran.tombol membuktikan labelnya tidak
      // membungkus dua baris (kalau membungkus, tombolnya akan tumbuh lebih
      // tinggi dari lantai 56 ini).
      final tinggiTombol = tester
          .getSize(find.byKey(const Key('tombol-transaksi-baru-beranda')))
          .height;
      expect(tinggiTombol, moreOrLessEquals(Ukuran.tombol, epsilon: 0.5));

      // Rincian jumlah barang dan totalnya tidak hilang — hanya dipindah
      // keluar dari label tombol ke baris keterangan terpisah.
      expect(find.textContaining('1 barang'), findsOneWidget);
      expect(find.textContaining('Rp 195.000'), findsOneWidget);

      // Tombol Pengaturan tetap terjangkau tanpa digulir, bahkan pada
      // ponsel murah 360x640 — buktinya geometri (rect), bukan `find`.
      final rectPengaturan = tester.getRect(
        find.byKey(const Key('tombol-pengaturan')),
      );
      expect(rectPengaturan.bottom, lessThanOrEqualTo(640));

      expect(tester.takeException(), isNull);
    },
  );
}
