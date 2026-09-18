import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/wadah.dart';
import 'state/favorit_controller.dart';
import 'state/keranjang_controller.dart';
import 'ui/kasir/layar_kasir.dart';
import 'ui/tema.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(AplikasiStruk(wadah: await Wadah.buat()));
}

class AplikasiStruk extends StatelessWidget {
  final Wadah wadah;

  const AplikasiStruk({super.key, required this.wadah});

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
        child: LayarKasir(onKirim: () {}),
      ),
    );
  }
}
