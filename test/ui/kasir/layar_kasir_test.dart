import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:struk_bangunan/data/basisdata.dart';
import 'package:struk_bangunan/data/draf_repository.dart';
import 'package:struk_bangunan/data/favorit_repository.dart';
import 'package:struk_bangunan/data/transaksi_repository.dart';
import 'package:struk_bangunan/domain/item_belanja.dart';
import 'package:struk_bangunan/state/favorit_controller.dart';
import 'package:struk_bangunan/state/keranjang_controller.dart';
import 'package:struk_bangunan/ui/kasir/layar_kasir.dart';
import 'package:struk_bangunan/ui/komponen/baris_item.dart';
import 'package:struk_bangunan/ui/komponen/chip_satuan.dart';
import 'package:struk_bangunan/ui/tema.dart';

import '../../bantuan_basisdata.dart';

Future<KeranjangController> _pasang(
  WidgetTester tester, {
  List<ItemBelanja> draf = const [],
  Size? ukuran,
}) async {
  // Layar ini didesain untuk layar ponsel asli (tinggi), bukan viewport uji
  // bawaan 800x600 (rasio lanskap). Tanpa ini, form + strip favorit + bilah
  // total meluap di viewport bawaan meski tidak meluap di ponsel sungguhan.
  // `ukuran` (opsional) memilih ukuran logis sendiri untuk test multi-layar;
  // tanpa itu perilaku test lama (1080x2340 @ dpr 3.0) tidak berubah.
  if (ukuran != null) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = ukuran;
  } else {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
  }
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues({});
  final db = await bukaBasisdataUji();
  await siapkanSkema(db);
  addTearDown(db.close);
  await FavoritRepository(
    db,
  ).catatPemakaian('Paku 5cm', 'kg', DateTime(2026, 9, 18));
  final prefs = await SharedPreferences.getInstance();
  if (draf.isNotEmpty) {
    await DrafRepository(prefs).simpan(draf);
  }
  final keranjang = KeranjangController(
    draf: DrafRepository(prefs),
    transaksi: TransaksiRepository(db),
    favorit: FavoritRepository(db),
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: keranjang),
        ChangeNotifierProvider.value(
          value: FavoritController(FavoritRepository(db)),
        ),
      ],
      child: MaterialApp(
        theme: temaTerang(),
        home: LayarKasir(onKirim: () {}),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return keranjang;
}

Future<void> _isiForm(
  WidgetTester tester, {
  String nama = 'Semen',
  String jumlah = '3',
  String harga = '65000',
}) async {
  await tester.enterText(find.byKey(const Key('kolom-nama')), nama);
  await tester.enterText(find.byKey(const Key('kolom-jumlah')), jumlah);
  await tester.enterText(find.byKey(const Key('kolom-harga')), harga);
  await tester.pump();
}

String _isiKolom(WidgetTester tester, String kunci) => tester
    .widget<TextField>(
      find.descendant(
        of: find.byKey(Key(kunci)),
        matching: find.byType(TextField),
      ),
    )
    .controller!
    .text;

// Tombol TAMBAH kini adalah anak tetap di luar area yang bergulir (fix F1),
// jadi selalu terlihat dan bisa ditekan langsung tanpa menggulir dulu.
Future<void> _tekanTambah(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('tombol-tambah')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('tombol tambah nonaktif selama nama bahan kosong', (
    tester,
  ) async {
    await _pasang(tester);

    final tombol = tester.widget<FilledButton>(
      find.byKey(const Key('tombol-tambah')),
    );
    expect(tombol.onPressed, isNull);

    await _isiForm(tester);
    final sesudah = tester.widget<FilledButton>(
      find.byKey(const Key('tombol-tambah')),
    );
    expect(sesudah.onPressed, isNotNull);
  });

  testWidgets('menambah item memperbarui daftar dan total', (tester) async {
    final keranjang = await _pasang(tester);
    await _isiForm(tester);

    await _tekanTambah(tester);

    expect(keranjang.items, hasLength(1));
    expect(keranjang.total, 195000);
    expect(find.text('Semen'), findsOneWidget);
    expect(find.text('Rp 195.000'), findsOneWidget);
  });

  testWidgets('kolom dikosongkan setelah item masuk', (tester) async {
    await _pasang(tester);
    await _isiForm(tester);

    await _tekanTambah(tester);

    expect(_isiKolom(tester, 'kolom-nama'), isEmpty);
    expect(_isiKolom(tester, 'kolom-jumlah'), '1');
    expect(_isiKolom(tester, 'kolom-harga'), isEmpty);
  });

  testWidgets('tombol kurang dan tambah mengubah jumlah', (tester) async {
    await _pasang(tester);

    await tester.tap(find.byKey(const Key('jumlah-tambah')));
    await tester.pump();
    expect(_isiKolom(tester, 'kolom-jumlah'), '2');

    await tester.tap(find.byKey(const Key('jumlah-kurang')));
    await tester.pump();
    expect(_isiKolom(tester, 'kolom-jumlah'), '1');

    // Tidak pernah turun ke nol: jumlah nol ditolak konstruktor ItemBelanja,
    // dan kasir tidak boleh menemui galat untuk sesuatu yang bisa dicegah.
    await tester.tap(find.byKey(const Key('jumlah-kurang')));
    await tester.pump();
    expect(_isiKolom(tester, 'kolom-jumlah'), '1');
  });

  testWidgets('menghapus item meminta konfirmasi lebih dulu', (tester) async {
    final keranjang = await _pasang(tester);
    await keranjang.tambah(
      ItemBelanja(nama: 'Semen', qty: 3, satuan: 'sak', hargaSatuan: 65000),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('hapus-0')));
    await tester.pumpAndSettle();

    expect(find.text('Hapus barang ini?'), findsOneWidget);
    expect(keranjang.items, hasLength(1));

    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    expect(keranjang.items, isEmpty);
  });

  testWidgets('membatalkan konfirmasi menyisakan itemnya', (tester) async {
    final keranjang = await _pasang(tester);
    await keranjang.tambah(
      ItemBelanja(nama: 'Semen', qty: 3, satuan: 'sak', hargaSatuan: 65000),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('hapus-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    expect(keranjang.items, hasLength(1));
  });

  testWidgets('tombol kirim nonaktif saat keranjang kosong', (tester) async {
    final keranjang = await _pasang(tester);

    final tombol = tester.widget<FilledButton>(
      find.byKey(const Key('tombol-kirim')),
    );
    expect(tombol.onPressed, isNull);

    await keranjang.tambah(
      ItemBelanja(nama: 'Semen', qty: 3, satuan: 'sak', hargaSatuan: 65000),
    );
    await tester.pumpAndSettle();

    final sesudah = tester.widget<FilledButton>(
      find.byKey(const Key('tombol-kirim')),
    );
    expect(sesudah.onPressed, isNotNull);
  });

  testWidgets(
    'menekan favorit mengisi nama, satuan, dan memindahkan fokus ke harga',
    (tester) async {
      await _pasang(tester);

      await tester.tap(find.text('Paku 5cm'));
      await tester.pumpAndSettle();

      expect(_isiKolom(tester, 'kolom-nama'), 'Paku 5cm');

      final chipKg = tester.widget<ChipSatuan>(
        find.byWidgetPredicate((w) => w is ChipSatuan && w.satuan == 'kg'),
      );
      expect(
        chipKg.terpilih,
        isTrue,
        reason: 'satuan terakhir bahan ikut terpilih',
      );

      final harga = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('kolom-harga')),
          matching: find.byType(TextField),
        ),
      );
      expect(
        harga.focusNode?.hasFocus,
        isTrue,
        reason: 'kursor pindah ke harga',
      );
    },
  );

  testWidgets(
    'nominal TOTAL terpanjang tidak meluap dan tetap terbaca utuh di ponsel sempit',
    (tester) async {
      // _pasang() sudah memasang viewport 360dp lebar (1080px @ 3.0 dpr) —
      // lebar ponsel Android arus utama, kasus yang diperbaiki fix D7.
      await _pasang(tester);
      await _isiForm(tester, jumlah: '1', harga: '999999999');

      await _tekanTambah(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Rp 999.999.999'), findsOneWidget);
    },
  );

  testWidgets('draf keranjang pulih setelah aplikasi dimatikan', (
    tester,
  ) async {
    final keranjang = await _pasang(
      tester,
      draf: [
        ItemBelanja(nama: 'Semen', qty: 3, satuan: 'sak', hargaSatuan: 65000),
      ],
    );

    expect(find.text('Semen'), findsOneWidget);
    expect(keranjang.total, 195000);
  });

  testWidgets('tombol jumlah punya label semantik untuk pembaca layar', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();

    await _pasang(tester);

    expect(find.bySemanticsLabel('Kurangi jumlah'), findsOneWidget);
    expect(find.bySemanticsLabel('Tambah jumlah'), findsOneWidget);

    handle.dispose();
  });

  group('daftar belanja punya ruang di berbagai ukuran layar', () {
    const ukuranLayar = {
      'Android murah (360x640)': Size(360, 640),
      'ponsel umum (360x780)': Size(360, 780),
      'ponsel tinggi (390x900)': Size(390, 900),
    };

    for (final entri in ukuranLayar.entries) {
      testWidgets('${entri.key}: tidak meluap dan daftar terlihat', (
        tester,
      ) async {
        final keranjang = await _pasang(tester, ukuran: entri.value);
        for (final nama in ['Semen', 'Pasir', 'Bata']) {
          await keranjang.tambah(
            ItemBelanja(nama: nama, qty: 3, satuan: 'sak', hargaSatuan: 65000),
          );
        }
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        final tinggiDaftar = tester
            .getSize(find.byKey(const Key('daftar-item')))
            .height;
        expect(tinggiDaftar, greaterThanOrEqualTo(72));
        expect(find.byType(BarisItem), findsAtLeastNWidgets(1));

        // Fix F1: '+ TAMBAH KE DAFTAR' harus seluruhnya berada di dalam
        // layar tanpa digulir, pada setiap ukuran — dibuktikan lewat
        // geometri (rect), bukan `find` (yang menemukan widget di luar
        // layar juga).
        final rectTombol = tester.getRect(
          find.byKey(const Key('tombol-tambah')),
        );
        expect(rectTombol.top, greaterThanOrEqualTo(0));
        expect(rectTombol.bottom, lessThanOrEqualTo(entri.value.height));
      });
    }
  });

  testWidgets('bilah TOTAL tidak tertimpa bilah navigasi sistem', (
    tester,
  ) async {
    // Ditemukan di perangkat nyata (RMX3710, Android 15): tanpa SafeArea,
    // tombol BUAT STRUK terpotong bilah navigasi. 48 dp meniru tinggi bilah
    // itu; padding bawah hanya bisa dihormati lewat SafeArea.
    const insetBawah = 48.0;
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(360, 780);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final db = await bukaBasisdataUji();
    await siapkanSkema(db);
    addTearDown(db.close);
    final prefs = await SharedPreferences.getInstance();
    final keranjang = KeranjangController(
      draf: DrafRepository(prefs),
      transaksi: TransaksiRepository(db),
      favorit: FavoritRepository(db),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: keranjang),
          ChangeNotifierProvider.value(
            value: FavoritController(FavoritRepository(db)),
          ),
        ],
        child: MaterialApp(
          theme: temaTerang(),
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(padding: const EdgeInsets.only(bottom: insetBawah)),
              child: LayarKasir(onKirim: () {}),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.byKey(const Key('tombol-kirim')));
    expect(rect.bottom, lessThanOrEqualTo(780 - insetBawah));
    expect(tester.takeException(), isNull);
  });

  testWidgets('tombol tambah tetap terlihat pada skala font besar', (
    tester,
  ) async {
    // Spec bagian 8: pengguna lansia umumnya sudah memperbesar font sistem.
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    SharedPreferences.setMockInitialValues({});
    final db = await bukaBasisdataUji();
    await siapkanSkema(db);
    addTearDown(db.close);
    final prefs = await SharedPreferences.getInstance();
    final keranjang = KeranjangController(
      draf: DrafRepository(prefs),
      transaksi: TransaksiRepository(db),
      favorit: FavoritRepository(db),
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: keranjang),
          ChangeNotifierProvider.value(
            value: FavoritController(FavoritRepository(db)),
          ),
        ],
        child: MaterialApp(
          theme: temaTerang(),
          home: LayarKasir(onKirim: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final rect = tester.getRect(find.byKey(const Key('tombol-tambah')));
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(640));
  });
}
