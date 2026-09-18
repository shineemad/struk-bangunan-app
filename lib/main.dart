import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/wadah.dart';
import 'domain/profil_toko.dart';
import 'output/share_service.dart';
import 'state/favorit_controller.dart';
import 'state/keranjang_controller.dart';
import 'state/pengirim_struk.dart';
import 'ui/kasir/layar_kasir.dart';
import 'ui/struk/layar_pratinjau.dart';
import 'ui/tema.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final wadah = await Wadah.buat();
  // Onboarding milik Rencana 5; sampai itu ada, struk memakai nama bawaan.
  final profil =
      await wadah.profil.muat() ?? const ProfilToko(namaToko: 'TOKO BANGUNAN');

  runApp(
    AplikasiStruk(
      wadah: wadah,
      profil: profil,
      pengirim: PengirimStruk(
        wadah.pengaturan,
        ShareService(await berkasSementaraCache()),
      ),
    ),
  );
}

class AplikasiStruk extends StatelessWidget {
  final Wadah wadah;
  final ProfilToko profil;
  final PengirimStrukKontrak pengirim;

  const AplikasiStruk({
    super.key,
    required this.wadah,
    required this.profil,
    required this.pengirim,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StrukBangunan',
      debugShowCheckedModeBanner: false,
      theme: temaTerang(),
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => KeranjangController(
              draf: wadah.draf,
              transaksi: wadah.transaksi,
              favorit: wadah.favorit,
            ),
          ),
          ChangeNotifierProvider(
            create: (_) => FavoritController(wadah.favorit),
          ),
        ],
        child: _Beranda(profil: profil, pengirim: pengirim),
      ),
    );
  }
}

class _Beranda extends StatelessWidget {
  final ProfilToko profil;
  final PengirimStrukKontrak pengirim;

  const _Beranda({required this.profil, required this.pengirim});

  @override
  Widget build(BuildContext context) {
    // `context` di sini sudah berada di bawah MultiProvider, sedangkan
    // context milik rute baru tidak — karena itu controller dibaca di sini,
    // bukan di dalam builder rutenya.
    final keranjang = context.read<KeranjangController>();

    return LayarKasir(
      onKirim: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => LayarPratinjau(
            profil: profil,
            keranjang: keranjang,
            pengirim: pengirim,
          ),
        ),
      ),
    );
  }
}
