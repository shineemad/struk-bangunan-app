import 'dart:developer' as dev;

import 'package:flutter/material.dart';

import '../../data/backup_service.dart';
import '../../data/pengaturan_keluaran_repository.dart';
import '../../data/profil_repository.dart';
import '../../domain/profil_toko.dart';
import '../../state/pemulih.dart';
import '../../state/pencadang.dart';
import '../komponen/chip_satuan.dart';
import '../komponen/isian.dart';
import '../tema.dart';

class LayarPengaturan extends StatefulWidget {
  final ProfilRepository profil;
  final PengaturanKeluaranRepository pengaturan;
  final PencadangKontrak pencadang;
  final PemulihKontrak pemulih;

  /// Dipanggil setelah simpan atau pemulihan sukses, supaya layar pemanggil
  /// bisa menyegarkan data yang dipakainya.
  final VoidCallback? onTersimpan;

  const LayarPengaturan({
    super.key,
    required this.profil,
    required this.pengaturan,
    required this.pencadang,
    required this.pemulih,
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
  bool _sedangCadangkan = false;
  bool _sedangPulihkan = false;

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
    } else {
      // Cadangan bisa berasal dari pemasangan yang belum pernah diatur.
      for (final kolom in [_nama, _alamat, _noHp, _catatan, _kasir]) {
        kolom.clear();
      }
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

  /// Kegagalan membagikan berkas tidak boleh mengunci layar — sama seperti
  /// `_kirimWa` di `LayarPratinjau`.
  Future<void> _cadangkan() async {
    setState(() => _sedangCadangkan = true);
    try {
      final nama = await widget.pencadang.cadangkan(DateTime.now());
      if (!mounted) return;
      setState(() => _sedangCadangkan = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Cadangan tersimpan: $nama')));
    } catch (galat, jejak) {
      dev.log(
        'cadangkan gagal karena galat tak terduga',
        name: 'LayarPengaturan',
        error: galat,
        stackTrace: jejak,
      );
      if (!mounted) return;
      setState(() => _sedangCadangkan = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mencadangkan data. Coba lagi.')),
      );
    }
  }

  /// Memulihkan MENIMPA seluruh data yang ada, jadi ia selalu lewat
  /// konfirmasi lebih dulu. `BackupService.impor` sudah memvalidasi berkas
  /// sampai tuntas sebelum menghapus satu baris pun, sehingga berkas yang
  /// cacat meninggalkan data lama utuh.
  Future<void> _pulihkan() async {
    final lanjut = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Pulihkan data?'),
        content: const Text(
          'Seluruh penjualan, barang favorit, dan pengaturan yang ada di HP '
          'ini akan DIGANTI oleh isi berkas cadangan. Data yang sekarang '
          'tidak bisa dikembalikan lagi.',
        ),
        actions: [
          TextButton(
            key: const Key('batal-pulihkan'),
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('BATAL'),
          ),
          TextButton(
            key: const Key('ya-pulihkan'),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('PILIH BERKAS'),
          ),
        ],
      ),
    );
    if (lanjut != true || !mounted) return;

    setState(() => _sedangPulihkan = true);
    try {
      final dipulihkan = await widget.pemulih.pulihkan();
      if (!mounted) return;
      setState(() => _sedangPulihkan = false);
      // Pengguna menutup pemilih berkas: bukan kegagalan, jadi tidak ada
      // pesan galat yang perlu ditampilkan.
      if (!dipulihkan) return;
      // Kolom di layar ini masih memegang profil lama sampai dimuat ulang.
      await _muat();
      widget.onTersimpan?.call();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data berhasil dipulihkan.')),
      );
    } on BackupRusak catch (galat) {
      if (!mounted) return;
      setState(() => _sedangPulihkan = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(galat.pesan)));
    } catch (galat, jejak) {
      dev.log(
        'pulihkan gagal karena galat tak terduga',
        name: 'LayarPengaturan',
        error: galat,
        stackTrace: jejak,
      );
      if (!mounted) return;
      setState(() => _sedangPulihkan = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal memulihkan data. Coba lagi.')),
      );
    }
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
            const SizedBox(height: 32),
            Text('Cadangkan data', style: labelBagian),
            const SizedBox(height: 8),
            Text(
              'Data toko ini hanya tersimpan di HP ini dan akan hilang bila '
              'aplikasi dihapus. Simpan berkas cadangan ke WhatsApp atau '
              'Google Drive secara berkala agar data penjualan tetap aman.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('tombol-cadangkan'),
              onPressed: _sedangCadangkan ? null : _cadangkan,
              child: const Text('CADANGKAN DATA'),
            ),
            const SizedBox(height: 32),
            Text('Pulihkan data', style: labelBagian),
            const SizedBox(height: 8),
            Text(
              'Pakai ini saat ganti HP atau setelah aplikasi dipasang ulang. '
              'Pilih berkas cadangan yang pernah Anda simpan. Data yang ada '
              'di HP ini sekarang akan diganti.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              key: const Key('tombol-pulihkan'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(Ukuran.tombol),
                side: const BorderSide(color: Warna.garis),
                foregroundColor: Warna.teks,
              ),
              onPressed: _sedangPulihkan ? null : _pulihkan,
              child: const Text('PULIHKAN DARI CADANGAN'),
            ),
          ],
        ),
      ),
    );
  }
}
