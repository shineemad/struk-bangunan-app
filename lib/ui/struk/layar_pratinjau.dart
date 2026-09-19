import 'dart:developer' as dev;

import 'package:flutter/material.dart';

import '../../domain/profil_toko.dart';
import '../../domain/receipt/receipt_builder.dart';
import '../../domain/transaksi.dart';
import '../../domain/uang.dart';
import '../../output/receipt_widget.dart';
import '../../state/keranjang_controller.dart';
import '../../state/pengirim_struk.dart';
import '../komponen/isian.dart';
import '../tema.dart';

class LayarPratinjau extends StatefulWidget {
  final ProfilToko profil;
  final KeranjangController keranjang;
  final PengirimStrukKontrak pengirim;

  const LayarPratinjau({
    super.key,
    required this.profil,
    required this.keranjang,
    required this.pengirim,
  });

  @override
  State<LayarPratinjau> createState() => _LayarPratinjauState();
}

class _LayarPratinjauState extends State<LayarPratinjau> {
  final _kunciStruk = GlobalKey();
  final _bayar = TextEditingController();
  Transaksi? _tersimpan;
  bool _sibuk = false;
  Future<Transaksi>? _penyimpanan;

  @override
  void dispose() {
    _bayar.dispose();
    super.dispose();
  }

  Transaksi get _pratinjau =>
      _tersimpan ??
      Transaksi(
        nomorNota: '----',
        waktu: DateTime.now(),
        items: widget.keranjang.items,
        bayar: parseRupiah(_bayar.text),
      );

  /// Menyimpan sekali saja, bahkan bila dua tombol ditekan dalam frame yang
  /// sama. `??=` berjalan sinkron sebelum `await` pertama, jadi pemanggil
  /// kedua menunggu Future yang sama alih-alih memulai transaksi kedua.
  Future<Transaksi> _simpanSekali() => _penyimpanan ??= _mulaiSimpan();

  Future<Transaksi> _mulaiSimpan() async {
    final nota = await widget.keranjang.simpan(bayar: parseRupiah(_bayar.text));
    if (mounted) setState(() => _tersimpan = nota);
    return nota;
  }

  Future<void> _simpanSaja() async {
    setState(() => _sibuk = true);
    await _simpanSekali();
    if (mounted) setState(() => _sibuk = false);
  }

  /// Penyimpanan tidak pernah dibungkus try/catch: itulah aturan tak bisa
  /// ditawar. Hanya pembuatan berkas dan pembagian yang boleh gagal, dan
  /// kegagalannya tidak boleh mengunci layar — nota sudah aman, kasir cukup
  /// diberi tahu supaya bisa mencoba kirim ulang.
  Future<void> _kirimWa() async {
    setState(() => _sibuk = true);
    final nota = await _simpanSekali();
    await WidgetsBinding.instance.endOfFrame;
    try {
      await widget.pengirim.kirim(
        kunciBoundary: _kunciStruk,
        nota: nota,
        lebarKolom: widget.profil.lebarKolom,
      );
    } catch (galat, jejak) {
      dev.log(
        'kirim gagal karena galat tak terduga',
        name: 'LayarPratinjau',
        error: galat,
        stackTrace: jejak,
      );
      if (!mounted) return;
      setState(() => _sibuk = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Struk #${nota.nomorNota} tersimpan, tetapi gagal dikirim. '
            'Coba kirim ulang.',
          ),
        ),
      );
      return;
    }
    if (mounted) setState(() => _sibuk = false);
  }

  @override
  Widget build(BuildContext context) {
    final dokumen = bangunStruk(profil: widget.profil, transaksi: _pratinjau);

    return Scaffold(
      appBar: AppBar(title: const Text('Struk')),
      body: ListView(
        padding: const EdgeInsets.all(Ukuran.jarak),
        children: [
          Center(
            child: RepaintBoundary(
              key: _kunciStruk,
              child: ReceiptWidget(dokumen: dokumen, ukuranFont: 13),
            ),
          ),
          const SizedBox(height: 24),
          if (_tersimpan == null)
            KolomIsian(
              key: const Key('kolom-bayar'),
              label: 'Uang dibayar (boleh dikosongkan)',
              controller: _bayar,
              hint: '0',
              angka: true,
              formatters: [FormatterRupiah()],
              onChanged: (_) => setState(() {}),
            ),
          if (_tersimpan != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Tersimpan #${_tersimpan!.nomorNota}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('tombol-kirim-wa'),
            onPressed: _sibuk ? null : _kirimWa,
            child: const Text('KIRIM WA'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('tombol-simpan'),
            onPressed: _sibuk || _tersimpan != null ? null : _simpanSaja,
            style: FilledButton.styleFrom(
              backgroundColor: Warna.isian,
              foregroundColor: Warna.teks,
            ),
            child: const Text('SIMPAN SAJA'),
          ),
          if (_tersimpan != null) ...[
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('tombol-transaksi-baru'),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('TRANSAKSI BARU'),
            ),
          ],
        ],
      ),
    );
  }
}
