import 'package:flutter/material.dart';

import '../../data/pengaturan_keluaran_repository.dart';
import '../../data/profil_repository.dart';
import '../../domain/profil_toko.dart';
import '../komponen/chip_satuan.dart';
import '../komponen/isian.dart';
import '../tema.dart';

class LayarPengaturan extends StatefulWidget {
  final ProfilRepository profil;
  final PengaturanKeluaranRepository pengaturan;

  /// Dipanggil setelah simpan sukses, supaya layar pemanggil bisa
  /// menyegarkan profil yang dipakainya.
  final VoidCallback? onTersimpan;

  const LayarPengaturan({
    super.key,
    required this.profil,
    required this.pengaturan,
    this.onTersimpan,
  });

  @override
  State<LayarPengaturan> createState() => _LayarPengaturanState();
}

class _LayarPengaturanState extends State<LayarPengaturan> {
  final _nama = TextEditingController();
  final _alamat = TextEditingController();
  final _noHp = TextEditingController();
  final _catatan = TextEditingController();
  final _kasir = TextEditingController();
  int _lebarKertas = 58;
  FormatKiriman _formatKiriman = FormatKiriman.png;

  // Diingat apa adanya dari pengaturan tersimpan agar simpan() tidak
  // menghapus printer yang sudah dipasangkan — repository ini menimpa
  // ketiga kunci sekaligus dan PengaturanKeluaran tidak punya copyWith.
  String _printerMac = '';
  String _printerNama = '';

  bool _sedangMemuat = true;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    final profil = await widget.profil.muat();
    final pengaturan = await widget.pengaturan.muat();
    if (profil != null) {
      _nama.text = profil.namaToko;
      _alamat.text = profil.alamat;
      _noHp.text = profil.noHp;
      _catatan.text = profil.catatan;
      _kasir.text = profil.namaKasir;
      _lebarKertas = profil.lebarKertas;
    }
    _formatKiriman = pengaturan.formatKiriman;
    _printerMac = pengaturan.printerMac;
    _printerNama = pengaturan.printerNama;
    if (mounted) setState(() => _sedangMemuat = false);
  }

  @override
  void dispose() {
    _nama.dispose();
    _alamat.dispose();
    _noHp.dispose();
    _catatan.dispose();
    _kasir.dispose();
    super.dispose();
  }

  bool get _bolehSimpan => _nama.text.trim().isNotEmpty;

  Future<void> _simpan() async {
    await widget.profil.simpan(
      ProfilToko(
        namaToko: _nama.text.trim(),
        alamat: _alamat.text.trim(),
        noHp: _noHp.text.trim(),
        catatan: _catatan.text.trim(),
        namaKasir: _kasir.text.trim(),
        lebarKertas: _lebarKertas,
      ),
    );
    await widget.pengaturan.simpan(
      PengaturanKeluaran(
        formatKiriman: _formatKiriman,
        printerMac: _printerMac,
        printerNama: _printerNama,
      ),
    );
    widget.onTersimpan?.call();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Pengaturan tersimpan.')));
  }

  @override
  Widget build(BuildContext context) {
    if (_sedangMemuat) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pengaturan')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final labelBagian = Theme.of(context).textTheme.labelLarge;

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Ukuran.jarak),
          children: [
            KolomIsian(
              key: const Key('kolom-nama-toko'),
              label: 'Nama toko',
              controller: _nama,
              hint: 'Toko Bangunan Jaya',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            KolomIsian(
              key: const Key('kolom-alamat'),
              label: 'Alamat',
              controller: _alamat,
              hint: 'Jl. Merdeka No. 10',
            ),
            const SizedBox(height: 12),
            KolomIsian(
              key: const Key('kolom-nohp'),
              label: 'Nomor HP / WhatsApp',
              controller: _noHp,
              hint: '08123456789',
            ),
            const SizedBox(height: 12),
            KolomIsian(
              key: const Key('kolom-catatan'),
              label: 'Pesan penutup struk',
              controller: _catatan,
              hint: 'Terima kasih telah berbelanja',
            ),
            const SizedBox(height: 12),
            KolomIsian(
              key: const Key('kolom-kasir'),
              label: 'Nama kasir',
              controller: _kasir,
              hint: 'Opsional',
            ),
            const SizedBox(height: 20),
            Text('Lebar kertas', style: labelBagian),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChipSatuan(
                  key: const Key('kertas-58'),
                  satuan: '58 mm',
                  terpilih: _lebarKertas == 58,
                  onPilih: () => setState(() => _lebarKertas = 58),
                ),
                ChipSatuan(
                  key: const Key('kertas-80'),
                  satuan: '80 mm',
                  terpilih: _lebarKertas == 80,
                  onPilih: () => setState(() => _lebarKertas = 80),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Format kiriman WhatsApp', style: labelBagian),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChipSatuan(
                  key: const Key('format-png'),
                  satuan: 'Gambar (PNG)',
                  terpilih: _formatKiriman == FormatKiriman.png,
                  onPilih: () =>
                      setState(() => _formatKiriman = FormatKiriman.png),
                ),
                ChipSatuan(
                  key: const Key('format-pdf'),
                  satuan: 'Dokumen (PDF)',
                  terpilih: _formatKiriman == FormatKiriman.pdf,
                  onPilih: () =>
                      setState(() => _formatKiriman = FormatKiriman.pdf),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'PNG langsung terlihat di WhatsApp. PDF cocok untuk diarsipkan.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('tombol-simpan-pengaturan'),
              onPressed: _bolehSimpan ? _simpan : null,
              child: const Text('SIMPAN'),
            ),
          ],
        ),
      ),
    );
  }
}
