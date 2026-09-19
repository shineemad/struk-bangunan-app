import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:struk_bangunan/data/backup_service.dart';
import 'package:struk_bangunan/data/profil_repository.dart';
import 'package:struk_bangunan/state/pemulih.dart';
import 'package:struk_bangunan/ui/onboarding/layar_onboarding.dart';
import 'package:struk_bangunan/ui/tema.dart';

class _PemulihPalsu implements PemulihKontrak {
  _PemulihPalsu({this.hasil = true, this.galat});

  final bool hasil;
  final Object? galat;
  int dipanggil = 0;

  @override
  Future<bool> pulihkan() async {
    dipanggil++;
    if (galat != null) throw galat!;
    return hasil;
  }
}

Future<void> _pasang(
  WidgetTester tester,
  SharedPreferences prefs, {
  PemulihKontrak? pemulih,
  VoidCallback? onSelesai,
}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: temaTerang(),
      home: LayarOnboarding(
        profil: ProfilRepository(prefs),
        pemulih: pemulih ?? _PemulihPalsu(),
        onSelesai: onSelesai ?? () {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Tombol pemulihan berada di kaki layar dan belum tentu sudah dibangun.
Future<void> _gulirKe(WidgetTester tester, Key kunci) async {
  await tester.dragUntilVisible(
    find.byKey(kunci),
    find.byType(ListView),
    const Offset(0, -200),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('tombol mulai mati selama nama toko masih kosong', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await _pasang(tester, prefs);

    final tombol = find.byKey(const Key('tombol-mulai'));
    expect(tester.widget<FilledButton>(tombol).onPressed, isNull);

    await tester.enterText(
      find.byKey(const Key('onboarding-nama-toko')),
      'Toko Jaya',
    );
    await tester.pump();

    expect(tester.widget<FilledButton>(tombol).onPressed, isNotNull);
  });

  testWidgets('nama yang hanya berisi spasi tetap ditolak', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await _pasang(tester, prefs);

    await tester.enterText(
      find.byKey(const Key('onboarding-nama-toko')),
      '   ',
    );
    await tester.pump();

    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('tombol-mulai')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('menyimpan profil lalu memberi tahu pemanggil', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var selesai = 0;

    await _pasang(tester, prefs, onSelesai: () => selesai++);

    await tester.enterText(
      find.byKey(const Key('onboarding-nama-toko')),
      '  Toko Sumber Rezeki  ',
    );
    await tester.enterText(
      find.byKey(const Key('onboarding-alamat')),
      'Jl. Merdeka 17',
    );
    await tester.enterText(
      find.byKey(const Key('onboarding-nohp')),
      '081234567890',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('tombol-mulai')));
    await tester.pumpAndSettle();

    final tersimpan = await ProfilRepository(prefs).muat();
    // Spasi yang tidak sengaja ikut terketik akan tercetak di setiap struk.
    expect(tersimpan?.namaToko, 'Toko Sumber Rezeki');
    expect(tersimpan?.alamat, 'Jl. Merdeka 17');
    expect(tersimpan?.noHp, '081234567890');
    expect(selesai, 1);
  });

  testWidgets('memulihkan cadangan menyelesaikan onboarding tanpa mengetik', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final pemulih = _PemulihPalsu();
    var selesai = 0;

    await _pasang(tester, prefs, pemulih: pemulih, onSelesai: () => selesai++);

    await _gulirKe(tester, const Key('tombol-pulihkan-onboarding'));
    await tester.tap(find.byKey(const Key('tombol-pulihkan-onboarding')));
    await tester.pumpAndSettle();

    expect(pemulih.dipanggil, 1);
    expect(selesai, 1);
  });

  testWidgets('cadangan yang rusak menampilkan pesannya dan menahan pengguna', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var selesai = 0;

    await _pasang(
      tester,
      prefs,
      pemulih: _PemulihPalsu(
        galat: const BackupRusak('Berkas ini bukan cadangan yang sah.'),
      ),
      onSelesai: () => selesai++,
    );

    await _gulirKe(tester, const Key('tombol-pulihkan-onboarding'));
    await tester.tap(find.byKey(const Key('tombol-pulihkan-onboarding')));
    await tester.pumpAndSettle();

    // Pesan spesifik, bukan 'terjadi kesalahan': pengguna harus tahu bahwa
    // berkasnyalah yang salah, bukan aplikasinya.
    expect(find.text('Berkas ini bukan cadangan yang sah.'), findsOneWidget);
    expect(selesai, 0);
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('tombol-pulihkan-onboarding')),
          )
          .onPressed,
      isNotNull,
      reason: 'tombol harus bisa dicoba lagi',
    );
  });

  testWidgets('membatalkan pemilih berkas tidak menyelesaikan onboarding', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var selesai = 0;

    await _pasang(
      tester,
      prefs,
      pemulih: _PemulihPalsu(hasil: false),
      onSelesai: () => selesai++,
    );

    await _gulirKe(tester, const Key('tombol-pulihkan-onboarding'));
    await tester.tap(find.byKey(const Key('tombol-pulihkan-onboarding')));
    await tester.pumpAndSettle();

    expect(selesai, 0);
    // Membatalkan bukan kegagalan, jadi tidak boleh ada pesan galat.
    expect(find.byType(SnackBar), findsNothing);
  });
}
