import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:struk_bangunan/data/backup_service.dart';
import 'package:struk_bangunan/data/pengaturan_keluaran_repository.dart';
import 'package:struk_bangunan/data/profil_repository.dart';
import 'package:struk_bangunan/domain/profil_toko.dart';
import 'package:struk_bangunan/state/pemulih.dart';
import 'package:struk_bangunan/state/pencadang.dart';
import 'package:struk_bangunan/ui/komponen/chip_satuan.dart';
import 'package:struk_bangunan/ui/pengaturan/layar_pengaturan.dart';
import 'package:struk_bangunan/ui/tema.dart';

class _PencadangPalsu implements PencadangKontrak {
  _PencadangPalsu({
    this.nama = 'strukbangunan-backup-20260919.json',
    this.galat,
  });

  final String nama;
  final Object? galat;

  @override
  Future<String> cadangkan(DateTime sekarang) async {
    if (galat != null) throw galat!;
    return nama;
  }
}

class _PemulihPalsu implements PemulihKontrak {
  _PemulihPalsu({this.hasil = true, this.galat, this.sebelumKembali});

  final bool hasil;
  final Object? galat;

  /// Dipakai test untuk meniru efek pemulihan pada data di balik layar.
  final Future<void> Function()? sebelumKembali;

  int dipanggil = 0;

  @override
  Future<bool> pulihkan() async {
    dipanggil++;
    if (galat != null) throw galat!;
    await sebelumKembali?.call();
    return hasil;
  }
}

Future<void> _pasang(
  WidgetTester tester,
  SharedPreferences prefs, {
  VoidCallback? onTersimpan,
  PencadangKontrak? pencadang,
  PemulihKontrak? pemulih,
}) async {
  // Layar ini panjang (5 kolom + 2 kelompok pilihan); viewport uji bawaan
  // 800x600 tidak merepresentasikan ponsel yang jadi target aplikasi ini.
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: temaTerang(),
      home: LayarPengaturan(
        profil: ProfilRepository(prefs),
        pengaturan: PengaturanKeluaranRepository(prefs),
        pencadang: pencadang ?? _PencadangPalsu(),
        pemulih: pemulih ?? _PemulihPalsu(),
        onTersimpan: onTersimpan,
      ),
    ),
  );
  await tester.pumpAndSettle();
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

// Isian di bawah lipatan (chip pilihan, tombol simpan) bisa belum dibangun
// sama sekali oleh ListView pada layar yang tidak muat sekaligus — dan
// posisi gulir bisa berubah lagi setelah fokus berpindah antar kolom.
// `scrollUntilVisible` menggulir sedikit demi sedikit sampai elemennya
// sungguhan ada di pohon, alih-alih menghitung jarak sekali saja seperti
// `ensureVisible` (yang gagal bila elemennya belum pernah dibangun).
Future<void> _tekan(WidgetTester tester, String kunci) async {
  final target = find.byKey(Key(kunci));
  await tester.dragUntilVisible(
    target,
    find.byType(ListView),
    const Offset(0, -200),
  );
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<bool> _bolehSimpan(WidgetTester tester) async {
  final target = find.byKey(const Key('tombol-simpan-pengaturan'));
  await tester.dragUntilVisible(
    target,
    find.byType(ListView),
    const Offset(0, -200),
  );
  await tester.pumpAndSettle();
  return tester.widget<FilledButton>(target).onPressed != null;
}

// Mengecek tombol men-scroll daftar ke bawah, yang bisa membongkar kolom
// paling atas — gulir balik supaya kolomnya bisa disentuh lagi sesudahnya.
Future<void> _gulirKeAtas(WidgetTester tester) async {
  await tester.drag(find.byType(ListView), const Offset(0, 2000));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('memuat nilai yang sudah tersimpan ke kolomnya', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await ProfilRepository(prefs).simpan(
      const ProfilToko(
        namaToko: 'Toko Jaya',
        alamat: 'Jl. Merdeka 1',
        noHp: '081234567890',
        catatan: 'Sampai jumpa lagi',
        namaKasir: 'Budi',
        lebarKertas: 80,
      ),
    );
    await PengaturanKeluaranRepository(
      prefs,
    ).simpan(const PengaturanKeluaran(formatKiriman: FormatKiriman.pdf));

    await _pasang(tester, prefs);

    expect(_isiKolom(tester, 'kolom-nama-toko'), 'Toko Jaya');
    expect(_isiKolom(tester, 'kolom-alamat'), 'Jl. Merdeka 1');
    expect(_isiKolom(tester, 'kolom-nohp'), '081234567890');
    expect(_isiKolom(tester, 'kolom-catatan'), 'Sampai jumpa lagi');
    expect(_isiKolom(tester, 'kolom-kasir'), 'Budi');

    // Chip pilihan harus mencerminkan keadaan tersimpan, bukan cuma bawaan —
    // lebar 80mm/PDF yang tidak tercermin di sini berarti struk berikutnya
    // diam-diam kembali ke 58mm/PNG.
    //
    // Diperiksa dua tahap: menggulir sampai `format-pdf` membuang chip kertas
    // dari pohon widget, sehingga keduanya tidak bisa dibaca dalam satu posisi
    // gulir yang sama.
    await tester.dragUntilVisible(
      find.byKey(const Key('kertas-80')),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<ChipSatuan>(find.byKey(const Key('kertas-80'))).terpilih,
      isTrue,
    );
    expect(
      tester.widget<ChipSatuan>(find.byKey(const Key('kertas-58'))).terpilih,
      isFalse,
    );

    await tester.dragUntilVisible(
      find.byKey(const Key('format-pdf')),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<ChipSatuan>(find.byKey(const Key('format-pdf'))).terpilih,
      isTrue,
    );
    expect(
      tester.widget<ChipSatuan>(find.byKey(const Key('format-png'))).terpilih,
      isFalse,
    );
  });

  testWidgets('tombol simpan nonaktif selama nama toko kosong', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await _pasang(tester, prefs);

    expect(await _bolehSimpan(tester), isFalse);
    await _gulirKeAtas(tester);

    await tester.enterText(
      find.byKey(const Key('kolom-nama-toko')),
      'Toko Baru',
    );
    await tester.pump();

    expect(await _bolehSimpan(tester), isTrue);
  });

  testWidgets('menyimpan menulis profil ke repository', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await _pasang(tester, prefs);

    await tester.enterText(
      find.byKey(const Key('kolom-nama-toko')),
      'Toko Makmur',
    );
    await tester.enterText(
      find.byKey(const Key('kolom-alamat')),
      'Jl. Sudirman 5',
    );
    await tester.enterText(find.byKey(const Key('kolom-nohp')), '081298765432');
    await tester.enterText(
      find.byKey(const Key('kolom-catatan')),
      'Terima kasih',
    );
    await tester.enterText(find.byKey(const Key('kolom-kasir')), 'Sari');
    await tester.pump();

    await _tekan(tester, 'tombol-simpan-pengaturan');

    final tersimpan = await ProfilRepository(prefs).muat();
    expect(tersimpan, isNotNull);
    expect(tersimpan!.namaToko, 'Toko Makmur');
    expect(tersimpan.alamat, 'Jl. Sudirman 5');
    expect(tersimpan.noHp, '081298765432');
    expect(tersimpan.catatan, 'Terima kasih');
    expect(tersimpan.namaKasir, 'Sari');
    expect(tersimpan.lebarKertas, 58);
  });

  testWidgets('memilih 80 mm membuat struk 48 kolom', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await _pasang(tester, prefs);

    await tester.enterText(
      find.byKey(const Key('kolom-nama-toko')),
      'Toko Dua',
    );
    await tester.pump();
    await _tekan(tester, 'kertas-80');
    await _tekan(tester, 'tombol-simpan-pengaturan');

    final tersimpan = await ProfilRepository(prefs).muat();
    expect(tersimpan!.lebarKertas, 80);
    expect(tersimpan.lebarKolom, 48);
  });

  testWidgets('memilih PDF tersimpan sebagai format kiriman', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await _pasang(tester, prefs);

    await tester.enterText(
      find.byKey(const Key('kolom-nama-toko')),
      'Toko Tiga',
    );
    await tester.pump();
    await _tekan(tester, 'format-pdf');
    await _tekan(tester, 'tombol-simpan-pengaturan');

    final pengaturan = await PengaturanKeluaranRepository(prefs).muat();
    expect(pengaturan.formatKiriman, FormatKiriman.pdf);
  });

  testWidgets('menyimpan tidak menghapus printer yang sudah diingat', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await PengaturanKeluaranRepository(prefs).simpan(
      const PengaturanKeluaran(
        formatKiriman: FormatKiriman.png,
        printerMac: 'AA:BB:CC:DD:EE:FF',
        printerNama: 'RPP02N',
      ),
    );

    await _pasang(tester, prefs);

    await tester.enterText(
      find.byKey(const Key('kolom-nama-toko')),
      'Toko Empat',
    );
    await tester.pump();
    await _tekan(tester, 'format-pdf');
    await _tekan(tester, 'tombol-simpan-pengaturan');

    final pengaturan = await PengaturanKeluaranRepository(prefs).muat();
    expect(pengaturan.formatKiriman, FormatKiriman.pdf);
    expect(pengaturan.printerMac, 'AA:BB:CC:DD:EE:FF');
    expect(pengaturan.printerNama, 'RPP02N');
  });

  testWidgets('onTersimpan dipanggil setelah menyimpan', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var dipanggil = false;
    await _pasang(tester, prefs, onTersimpan: () => dipanggil = true);

    await tester.enterText(
      find.byKey(const Key('kolom-nama-toko')),
      'Toko Lima',
    );
    await tester.pump();
    await _tekan(tester, 'tombol-simpan-pengaturan');

    expect(dipanggil, isTrue);
  });

  testWidgets(
    'menekan cadangkan memanggil pencadang dan menampilkan nama berkasnya',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await _pasang(
        tester,
        prefs,
        pencadang: _PencadangPalsu(nama: 'strukbangunan-backup-20260919.json'),
      );

      await _tekan(tester, 'tombol-cadangkan');

      expect(
        find.textContaining('strukbangunan-backup-20260919.json'),
        findsOneWidget,
      );
    },
  );

  testWidgets('pencadangan yang gagal tidak mengunci layar', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await _pasang(
      tester,
      prefs,
      pencadang: _PencadangPalsu(galat: Exception('gagal terduga')),
    );

    await _tekan(tester, 'tombol-cadangkan');

    expect(find.textContaining('Gagal mencadangkan'), findsOneWidget);
    final target = find.byKey(const Key('tombol-cadangkan'));
    await tester.dragUntilVisible(
      target,
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(target).onPressed, isNotNull);
  });

  testWidgets('memulihkan selalu lewat konfirmasi lebih dulu', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final pemulih = _PemulihPalsu();
    await _pasang(tester, prefs, pemulih: pemulih);

    await _tekan(tester, 'tombol-pulihkan');

    // Berkas belum boleh diminta sebelum pengguna menyatakan setuju: menimpa
    // data karena salah tekan tidak bisa dibatalkan.
    expect(pemulih.dipanggil, 0);
    expect(find.text('Pulihkan data?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('batal-pulihkan')));
    await tester.pumpAndSettle();

    expect(pemulih.dipanggil, 0);
  });

  testWidgets('pemulihan sukses memuat ulang kolom dan memberi tahu beranda', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await ProfilRepository(
      prefs,
    ).simpan(const ProfilToko(namaToko: 'Toko Lama'));
    var diberiTahu = false;

    await _pasang(
      tester,
      prefs,
      onTersimpan: () => diberiTahu = true,
      // Meniru pemulihan sungguhan: profil di penyimpanan sudah berganti
      // ketika `pulihkan()` selesai.
      pemulih: _PemulihPalsu(
        sebelumKembali: () => ProfilRepository(
          prefs,
        ).simpan(const ProfilToko(namaToko: 'Toko Hasil Pulih')),
      ),
    );

    expect(_isiKolom(tester, 'kolom-nama-toko'), 'Toko Lama');

    await _tekan(tester, 'tombol-pulihkan');
    await tester.tap(find.byKey(const Key('ya-pulihkan')));
    await tester.pumpAndSettle();

    expect(find.text('Data berhasil dipulihkan.'), findsOneWidget);

    // Kembali ke puncak: menggulir ke tombol pulihkan membuang kolom nama
    // toko dari pohon widget.
    await tester.dragUntilVisible(
      find.byKey(const Key('kolom-nama-toko')),
      find.byType(ListView),
      const Offset(0, 200),
    );
    await tester.pumpAndSettle();

    // Kolom yang basi akan menyimpan balik profil lama begitu pengguna
    // menekan SIMPAN, diam-diam membatalkan pemulihannya.
    expect(_isiKolom(tester, 'kolom-nama-toko'), 'Toko Hasil Pulih');
    expect(diberiTahu, isTrue);
  });

  testWidgets('berkas cadangan yang rusak menampilkan pesannya sendiri', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var diberiTahu = false;

    await _pasang(
      tester,
      prefs,
      onTersimpan: () => diberiTahu = true,
      pemulih: _PemulihPalsu(
        galat: const BackupRusak('Berkas cadangan tidak memuat bagian "meta".'),
      ),
    );

    await _tekan(tester, 'tombol-pulihkan');
    await tester.tap(find.byKey(const Key('ya-pulihkan')));
    await tester.pumpAndSettle();

    expect(
      find.text('Berkas cadangan tidak memuat bagian "meta".'),
      findsOneWidget,
    );
    expect(diberiTahu, isFalse);
  });

  testWidgets('pemulihan yang gagal tidak mengunci layar', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await _pasang(
      tester,
      prefs,
      pemulih: _PemulihPalsu(galat: Exception('gagal terduga')),
    );

    await _tekan(tester, 'tombol-pulihkan');
    await tester.tap(find.byKey(const Key('ya-pulihkan')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Gagal memulihkan'), findsOneWidget);
    final target = find.byKey(const Key('tombol-pulihkan'));
    await tester.dragUntilVisible(
      target,
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<OutlinedButton>(target).onPressed, isNotNull);
  });

  testWidgets('membatalkan pemilih berkas tidak memberi kabar apa pun', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var diberiTahu = false;

    await _pasang(
      tester,
      prefs,
      onTersimpan: () => diberiTahu = true,
      pemulih: _PemulihPalsu(hasil: false),
    );

    await _tekan(tester, 'tombol-pulihkan');
    await tester.tap(find.byKey(const Key('ya-pulihkan')));
    await tester.pumpAndSettle();

    // Menutup pemilih berkas adalah keputusan sadar, bukan kegagalan.
    expect(find.byType(SnackBar), findsNothing);
    expect(diberiTahu, isFalse);
  });
}
