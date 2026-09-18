import 'package:flutter/material.dart';

import 'app/wadah.dart';
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
      home: const Scaffold(
        body: Center(child: Text('Layar Kasir menyusul di Tugas 6')),
      ),
    );
  }
}
