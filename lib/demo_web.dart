// SEMENTARA — pratinjau struk untuk dilihat di browser, bukan bagian aplikasi.
// Jalankan: flutter run -d chrome -t lib/demo_web.dart
// Hanya memakai lib/domain + lib/output/receipt_widget.dart, tanpa plugin
// apa pun, sehingga aman dijalankan di web.
import 'package:flutter/material.dart';

import 'domain/item_belanja.dart';
import 'domain/profil_toko.dart';
import 'domain/receipt/receipt_builder.dart';
import 'domain/receipt/receipt_document.dart';
import 'domain/transaksi.dart';
import 'output/receipt_widget.dart';

final _transaksi = Transaksi(
  nomorNota: '0142',
  waktu: DateTime(2026, 9, 18, 14, 30),
  items: [
    ItemBelanja(
      nama: 'Semen Tiga Roda',
      qty: 3,
      satuan: 'sak',
      hargaSatuan: 65000,
    ),
    ItemBelanja(nama: 'Pasir', qty: 1, satuan: 'rit', hargaSatuan: 850000),
    ItemBelanja(nama: 'Paku 7cm', qty: 2, satuan: 'kg', hargaSatuan: 20000),
    ItemBelanja(
      nama: 'Keramik Granit Roman 60x60 Putih Doff',
      qty: 4,
      satuan: 'dus',
      hargaSatuan: 185000,
    ),
    ItemBelanja(
      nama: 'Besi Beton 10mm',
      qty: 1.5,
      satuan: 'batang',
      hargaSatuan: 92000,
    ),
  ],
  bayar: 2000000,
);

ReceiptDocument _dokumen(int lebarKertas) => bangunStruk(
  profil: ProfilToko(
    namaToko: 'TB. SINAR BANGUNAN',
    alamat: 'Jl. Raya Merdeka No. 45',
    noHp: '0812-3456-7890',
    catatan: 'Barang yang sudah dibeli tidak dapat dikembalikan.',
    namaKasir: 'Admin',
    lebarKertas: lebarKertas,
  ),
  transaksi: _transaksi,
);

void main() => runApp(const _DemoApp());

class _DemoApp extends StatelessWidget {
  const _DemoApp();

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Pratinjau Struk — StrukBangunan',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: Colors.blue),
    home: const _LayarDemo(),
  );
}

class _LayarDemo extends StatefulWidget {
  const _LayarDemo();

  @override
  State<_LayarDemo> createState() => _LayarDemoState();
}

class _LayarDemoState extends State<_LayarDemo> {
  double _ukuranFont = 14;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFECEFF1),
      appBar: AppBar(
        title: const Text('Pratinjau struk — satu-satunya UI yang sudah ada'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Ukuran huruf'),
                Expanded(
                  child: Slider(
                    value: _ukuranFont,
                    min: 8,
                    max: 24,
                    divisions: 16,
                    label: _ukuranFont.toStringAsFixed(0),
                    onChanged: (n) => setState(() => _ukuranFont = n),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 32,
              runSpacing: 32,
              children: [
                _Kertas(
                  judul: 'Kertas 58mm — 32 kolom',
                  dokumen: _dokumen(58),
                  ukuranFont: _ukuranFont,
                ),
                _Kertas(
                  judul: 'Kertas 80mm — 48 kolom',
                  dokumen: _dokumen(80),
                  ukuranFont: _ukuranFont,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Kertas extends StatelessWidget {
  final String judul;
  final ReceiptDocument dokumen;
  final double ukuranFont;

  const _Kertas({
    required this.judul,
    required this.dokumen,
    required this.ukuranFont,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(judul, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Material(
          elevation: 3,
          child: ReceiptWidget(dokumen: dokumen, ukuranFont: ukuranFont),
        ),
      ],
    );
  }
}
