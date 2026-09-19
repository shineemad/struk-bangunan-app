import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/pengaturan_keluaran_repository.dart';
import '../../data/profil_repository.dart';
import '../../domain/profil_toko.dart';
import '../../domain/uang.dart';
import '../../state/keranjang_controller.dart';
import '../../state/pengirim_struk.dart';
import '../kasir/layar_kasir.dart';
import '../pengaturan/layar_pengaturan.dart';
import '../struk/layar_pratinjau.dart';
import '../tema.dart';

/// Onboarding milik Rencana 5; sampai itu ada, toko yang belum pernah diatur
/// memakai nama ini.
const _profilBawaan = ProfilToko(namaToko: 'TOKO BANGUNAN');

/// Pusat navigasi aplikasi: memegang profil toko yang sedang berlaku, lalu
/// membuka Kasir dan Pengaturan. Bottom nav sengaja tidak dibuat — ia
/// mengandaikan tiga tujuan, sedangkan Riwayat (Rencana 5) belum ada.
class LayarBeranda extends StatefulWidget {
  final ProfilRepository profil;
  final PengaturanKeluaranRepository pengaturan;
  final PengirimStrukKontrak pengirim;

  const LayarBeranda({
    super.key,
    required this.profil,
    required this.pengaturan,
    required this.pengirim,
  });

  @override
  State<LayarBeranda> createState() => _LayarBerandaState();
}

class _LayarBerandaState extends State<LayarBeranda> {
  ProfilToko? _profil;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<KeranjangController>().muatDraf();
    });
    _muatProfil();
  }

  Future<void> _muatProfil() async {
    final profil = await widget.profil.muat() ?? _profilBawaan;
    if (mounted) setState(() => _profil = profil);
  }

  void _bukaKasir() {
    // Dibaca dari context Beranda (di bawah MultiProvider) sebelum push —
    // context rute baru yang didorong Navigator tidak berada di bawah
    // provider manapun yang dipasang di dalam rute ini.
    final keranjang = context.read<KeranjangController>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LayarKasir(
          onKirim: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => LayarPratinjau(
                profil: _profil ?? _profilBawaan,
                keranjang: keranjang,
                pengirim: widget.pengirim,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _bukaPengaturan() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LayarPengaturan(
          profil: widget.profil,
          pengaturan: widget.pengaturan,
          // Nama toko yang baru harus langsung terlihat di sini, dan struk
          // berikutnya harus memakai profil baru — profil yang basi berarti
          // struk pembeli mencetak nama toko yang salah.
          onTersimpan: _muatProfil,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profil = _profil;
    if (profil == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final keranjang = context.watch<KeranjangController>();
    final teksTombol = keranjang.kosong
        ? 'TRANSAKSI BARU'
        : 'LANJUTKAN · ${keranjang.items.length} barang · '
              'Rp ${formatRupiah(keranjang.total)}';

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Ukuran.jarak),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 64),
              Text(
                profil.namaToko,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 32),
              FilledButton(
                key: const Key('tombol-transaksi-baru-beranda'),
                onPressed: _bukaKasir,
                child: Text(teksTombol),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: Ukuran.sentuh,
                child: TextButton(
                  key: const Key('tombol-pengaturan'),
                  onPressed: _bukaPengaturan,
                  child: const Text('PENGATURAN'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
