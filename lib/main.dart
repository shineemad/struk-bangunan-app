import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/wadah.dart';
import 'data/backup_service.dart';
import 'output/share_service.dart';
import 'state/favorit_controller.dart';
import 'state/keranjang_controller.dart';
import 'state/pencadang.dart';
import 'state/pengirim_struk.dart';
import 'ui/beranda/layar_beranda.dart';
import 'ui/tema.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final wadah = await Wadah.buat();

  runApp(
    AplikasiStruk(
      wadah: wadah,
      pengirim: PengirimStruk(
        wadah.pengaturan,
        ShareService(await berkasSementaraCache()),
      ),
      pencadang: Pencadang(
        BackupService(wadah.db, wadah.profil, wadah.pengaturan),
        ShareService(await berkasSementaraCache()),
      ),
    ),
  );
}

class AplikasiStruk extends StatelessWidget {
  final Wadah wadah;
  final PengirimStrukKontrak pengirim;
  final PencadangKontrak pencadang;

  const AplikasiStruk({
    super.key,
    required this.wadah,
    required this.pengirim,
    required this.pencadang,
  });

  @override
  Widget build(BuildContext context) {
    // MultiProvider membungkus MaterialApp, bukan berada di dalam `home` —
    // LayarKasir yang didorong Beranda lewat Navigator.push butuh kedua
    // controller ini dari rute barunya sendiri, dan rute baru tidak berada
    // di bawah provider manapun yang dipasang di dalam `home`.
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => KeranjangController(
            draf: wadah.draf,
            transaksi: wadah.transaksi,
            favorit: wadah.favorit,
          ),
        ),
        ChangeNotifierProvider(create: (_) => FavoritController(wadah.favorit)),
      ],
      child: MaterialApp(
        title: 'Notaku',
        debugShowCheckedModeBanner: false,
        theme: temaTerang(),
        home: LayarBeranda(
          profil: wadah.profil,
          pengaturan: wadah.pengaturan,
          transaksi: wadah.transaksi,
          pengirim: pengirim,
          pencadang: pencadang,
        ),
      ),
    );
  }
}
