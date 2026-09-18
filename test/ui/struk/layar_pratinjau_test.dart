import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:struk_bangunan/data/basisdata.dart';
import 'package:struk_bangunan/data/draf_repository.dart';
import 'package:struk_bangunan/data/favorit_repository.dart';
import 'package:struk_bangunan/data/transaksi_repository.dart';
import 'package:struk_bangunan/domain/item_belanja.dart';
import 'package:struk_bangunan/domain/profil_toko.dart';
import 'package:struk_bangunan/domain/transaksi.dart';
import 'package:struk_bangunan/state/keranjang_controller.dart';
import 'package:struk_bangunan/state/pengirim_struk.dart';
import 'package:struk_bangunan/ui/struk/layar_pratinjau.dart';
import 'package:struk_bangunan/ui/tema.dart';

import '../../bantuan_basisdata.dart';

/// Pengirim palsu yang mencatat kapan ia dipanggil.
///
/// Jalur PNG/PDF sungguhan diuji terpisah di `pengirim_struk_test.dart`:
/// `ambilPng` menuntut `tester.runAsync()`, sementara `pumpAndSettle` tidak
/// boleh dipanggil dari dalamnya, jadi satu test tidak bisa melakukan
/// keduanya sekaligus.
class _PengirimPalsu implements PengirimStrukKontrak {
  final List<String> jejak = [];
  String? nomorNotaTerkirim;

  @override
  Future<void> kirim({
    required GlobalKey kunciBoundary,
    required Transaksi nota,
    required int lebarKolom,
  }) async {
    jejak.add('bagikan');
    nomorNotaTerkirim = nota.nomorNota;
  }
}

/// Pengirim palsu yang selalu gagal, untuk membuktikan layar pulih dari
/// kegagalan berbagi tanpa mengunci diri (Ruling 2).
class _PengirimGagal implements PengirimStrukKontrak {
  @override
  Future<void> kirim({
    required GlobalKey kunciBoundary,
    required Transaksi nota,
    required int lebarKolom,
  }) async {
    throw Exception('share sheet gagal dibuka');
  }
}

void main() {
  testWidgets('menyimpan lebih dulu, baru membagikan', (tester) async {
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
    await keranjang.tambah(
      ItemBelanja(nama: 'Semen', qty: 3, satuan: 'sak', hargaSatuan: 65000),
    );

    final pengirim = _PengirimPalsu();

    await tester.pumpWidget(
      MaterialApp(
        theme: temaTerang(),
        home: LayarPratinjau(
          profil: const ProfilToko(namaToko: 'TB. SINAR BANGUNAN'),
          keranjang: keranjang,
          pengirim: pengirim,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tombol-kirim-wa')));
    await tester.pumpAndSettle();

    // Nota sudah ada di basis data, dan nomor yang dikirim adalah nomor yang
    // tersimpan — bukti bahwa penyimpanan mendahului pembagian.
    expect(
      await TransaksiRepository(db).ambil('0001'),
      isNotNull,
      reason: 'transaksi wajib tersimpan lebih dulu',
    );
    expect(pengirim.jejak, ['bagikan']);
    expect(pengirim.nomorNotaTerkirim, '0001');
    expect(keranjang.kosong, isTrue);
  });

  testWidgets('menyimpan saja tidak membagikan apa pun', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = await bukaBasisdataUji();
    await siapkanSkema(db);
    addTearDown(db.close);
    final prefs = await SharedPreferences.getInstance();

    final pengirim = _PengirimPalsu();
    final keranjang = KeranjangController(
      draf: DrafRepository(prefs),
      transaksi: TransaksiRepository(db),
      favorit: FavoritRepository(db),
    );
    await keranjang.tambah(
      ItemBelanja(nama: 'Semen', qty: 3, satuan: 'sak', hargaSatuan: 65000),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: temaTerang(),
        home: LayarPratinjau(
          profil: const ProfilToko(namaToko: 'TB. SINAR BANGUNAN'),
          keranjang: keranjang,
          pengirim: pengirim,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tombol-simpan')));
    await tester.pumpAndSettle();

    expect(await TransaksiRepository(db).ambil('0001'), isNotNull);
    expect(pengirim.jejak, isEmpty);
    expect(find.textContaining('Tersimpan #0001'), findsOneWidget);
  });

  testWidgets('uang bayar menampilkan kembalian dengan nominal yang benar', (
    tester,
  ) async {
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
    await keranjang.tambah(
      ItemBelanja(nama: 'Semen', qty: 3, satuan: 'sak', hargaSatuan: 65000),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: temaTerang(),
        home: LayarPratinjau(
          profil: const ProfilToko(namaToko: 'TB. SINAR BANGUNAN'),
          keranjang: keranjang,
          pengirim: _PengirimPalsu(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Total = 3 sak x Rp 65.000 = Rp 195.000; bayar Rp 200.000 -> kembali
    // Rp 5.000. Memeriksa nominalnya, bukan cuma keberadaan label "Kembali"
    // — brief hanya memakai `findsWidgets`, yang lulus meski nominalnya salah.
    await tester.enterText(find.byKey(const Key('kolom-bayar')), '200000');
    await tester.pumpAndSettle();

    final barisKembali = tester.widget<Text>(find.textContaining('Kembali'));
    expect(barisKembali.data, contains('5.000'));
  });

  testWidgets(
    'kegagalan berbagi tetap menyimpan transaksi, membuka kembali tombol '
    'kirim, dan menampilkan pesan agar kasir bisa kirim ulang',
    (tester) async {
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
      await keranjang.tambah(
        ItemBelanja(nama: 'Semen', qty: 3, satuan: 'sak', hargaSatuan: 65000),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: temaTerang(),
          home: LayarPratinjau(
            profil: const ProfilToko(namaToko: 'TB. SINAR BANGUNAN'),
            keranjang: keranjang,
            pengirim: _PengirimGagal(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('tombol-kirim-wa')));
      await tester.pumpAndSettle();

      expect(
        await TransaksiRepository(db).ambil('0001'),
        isNotNull,
        reason: 'transaksi wajib tetap tersimpan meski berbagi gagal',
      );
      final tombol = tester.widget<FilledButton>(
        find.byKey(const Key('tombol-kirim-wa')),
      );
      expect(
        tombol.onPressed,
        isNotNull,
        reason: 'layar tidak boleh terkunci setelah kegagalan berbagi',
      );
      expect(
        find.textContaining('Struk #0001 tersimpan, tetapi gagal dikirim'),
        findsOneWidget,
      );
    },
  );
}
