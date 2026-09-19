import 'dart:developer' as dev;

import 'package:flutter/material.dart';

import '../../data/backup_service.dart';
import '../../data/profil_repository.dart';
import '../../domain/profil_toko.dart';
import '../../state/pemulih.dart';
import '../komponen/isian.dart';
import '../komponen/tanda_notaku.dart';
import '../tema.dart';

/// Layar pertama yang dilihat pemilik toko. Hanya menanyakan yang benar-benar
/// dicetak di struk, karena setiap kolom tambahan adalah alasan untuk berhenti
/// sebelum transaksi pertama. Sisanya bisa diisi belakangan di Pengaturan.
class LayarOnboarding extends StatefulWidget {
  final ProfilRepository profil;
  final PemulihKontrak pemulih;
  final VoidCallback onSelesai;

  const LayarOnboarding({
    super.key,
    required this.profil,
    required this.pemulih,
    required this.onSelesai,
  });

  @override
  State<LayarOnboarding> createState() => _LayarOnboardingState();
}

class _LayarOnboardingState extends State<LayarOnboarding> {
  final _nama = TextEditingController();
  final _alamat = TextEditingController();
  final _noHp = TextEditingController();
  bool _sibuk = false;

  @override
  void dispose() {
    _nama.dispose();
    _alamat.dispose();
    _noHp.dispose();
    super.dispose();
  }

  bool get _bolehMulai => _nama.text.trim().isNotEmpty;

  Future<void> _mulai() async {
    setState(() => _sibuk = true);
    await widget.profil.simpan(
      ProfilToko(
        namaToko: _nama.text.trim(),
        alamat: _alamat.text.trim(),
        noHp: _noHp.text.trim(),
      ),
    );
    widget.onSelesai();
  }

  /// Jalan masuk bagi pengguna lama yang ganti HP. Tanpa ini mereka terpaksa
  /// mengetik ulang profil lebih dulu, lalu pemulihan menimpanya — dua langkah
  /// yang sia-sia dan membingungkan.
  Future<void> _pulihkan() async {
    setState(() => _sibuk = true);
    try {
      final dipulihkan = await widget.pemulih.pulihkan();
      if (!mounted) return;
      setState(() => _sibuk = false);
      if (dipulihkan) widget.onSelesai();
    } on BackupRusak catch (galat) {
      if (!mounted) return;
      setState(() => _sibuk = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(galat.pesan)));
    } catch (galat, jejak) {
      dev.log(
        'pulihkan saat onboarding gagal karena galat tak terduga',
        name: 'LayarOnboarding',
        error: galat,
        stackTrace: jejak,
      );
      if (!mounted) return;
      setState(() => _sibuk = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal memulihkan data. Coba lagi.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                children: [
                  const Center(child: TandaNotaku(sisi: 64)),
                  const SizedBox(height: 20),
                  Text('Selamat datang di Notaku', style: teks.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    'Buat struk belanja, lalu kirim lewat WhatsApp. Semua '
                    'data tersimpan di HP ini saja.',
                    style: teks.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  KolomIsian(
                    key: const Key('onboarding-nama-toko'),
                    label: 'Nama toko',
                    hint: 'TOKO BANGUNAN JAYA',
                    controller: _nama,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: Ukuran.jarak),
                  KolomIsian(
                    key: const Key('onboarding-alamat'),
                    label: 'Alamat (opsional)',
                    controller: _alamat,
                  ),
                  const SizedBox(height: Ukuran.jarak),
                  KolomIsian(
                    key: const Key('onboarding-nohp'),
                    label: 'Nomor HP (opsional)',
                    controller: _noHp,
                    angka: true,
                  ),
                  const SizedBox(height: 32),
                  const Divider(color: Warna.garis),
                  const SizedBox(height: 16),
                  Text(
                    'Pernah memakai Notaku di HP lain?',
                    style: teks.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    key: const Key('tombol-pulihkan-onboarding'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(Ukuran.tombol),
                      side: const BorderSide(color: Warna.garis),
                      foregroundColor: Warna.teks,
                    ),
                    onPressed: _sibuk ? null : _pulihkan,
                    child: const Text('PULIHKAN DARI CADANGAN'),
                  ),
                ],
              ),
            ),
            // Dipaku di dasar layar: aksi utama tidak boleh menuntut pengguna
            // menggulir dulu untuk menemukannya.
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: FilledButton(
                key: const Key('tombol-mulai'),
                onPressed: _bolehMulai && !_sibuk ? _mulai : null,
                child: const Text('MULAI PAKAI'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
