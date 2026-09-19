import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/wadah.dart';
import 'data/backup_service.dart';
import 'output/pemilih_berkas.dart';
import 'output/share_service.dart';
import 'state/favorit_controller.dart';
import 'state/keranjang_controller.dart';
import 'state/pemulih.dart';
import 'state/pencadang.dart';
import 'state/pengirim_struk.dart';
import 'ui/beranda/layar_beranda.dart';
import 'ui/pembuka/layar_pembuka.dart';
import 'ui/tema.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final wadah = await Wadah.buat();
  final backup = BackupService(wadah.db, wadah.profil, wadah.pengaturan);

  runApp(
    AplikasiStruk(
      wadah: wadah,
      pengirim: PengirimStruk(
        wadah.pengaturan,
        ShareService(await berkasSementaraCache()),
      ),
      pencadang: Pencadang(backup, ShareService(await berkasSementaraCache())),
      pemulih: Pemulih(backup, const PemilihBerkasAsli()),
    ),
  );
}

class AplikasiStruk extends StatefulWidget {
  final Wadah wadah;
  final PengirimStrukKontrak pengirim;
  final PencadangKontrak pencadang;
  final PemulihKontrak pemulih;

  const AplikasiStruk({
    super.key,
    required this.wadah,
    required this.pengirim,
    required this.pencadang,
    required this.pemulih,
  });

  @override
  State<AplikasiStruk> createState() => _AplikasiStrukState();
}

class _AplikasiStrukState extends State<AplikasiStruk> {
  bool _pembukaSelesai = false;

  @override
  Widget build(BuildContext context) {
    final wadah = widget.wadah;
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
        home: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: _pembukaSelesai
              ? LayarBeranda(
                  key: const ValueKey('beranda'),
                  profil: wadah.profil,
                  pengaturan: wadah.pengaturan,
                  transaksi: wadah.transaksi,
                  pengirim: widget.pengirim,
                  pencadang: widget.pencadang,
                  pemulih: widget.pemulih,
                )
              : LayarPembuka(
                  key: const ValueKey('pembuka'),
                  onSelesai: () => setState(() => _pembukaSelesai = true),
                ),
        ),
      ),
    );
  }
}
