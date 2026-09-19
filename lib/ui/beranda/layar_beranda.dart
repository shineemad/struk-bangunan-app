import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/pengaturan_keluaran_repository.dart';
import '../../data/profil_repository.dart';
import '../../data/transaksi_repository.dart';
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
  final TransaksiRepository transaksi;
  final PengirimStrukKontrak pengirim;

  const LayarBeranda({
    super.key,
    required this.profil,
    required this.pengaturan,
    required this.transaksi,
    required this.pengirim,
  });

  @override
  State<LayarBeranda> createState() => _LayarBerandaState();
}

class _LayarBerandaState extends State<LayarBeranda> {
  ProfilToko? _profil;
  RekapHarian? _rekap;
  Future<void> _draf = Future<void>.value();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _draf = context.read<KeranjangController>().muatDraf();
    });
    _muatProfil();
    _muatRekap();
  }

  Future<void> _muatProfil() async {
    final profil = await widget.profil.muat() ?? _profilBawaan;
    if (mounted) setState(() => _profil = profil);
  }

  Future<void> _muatRekap() async {
    final rekap = await widget.transaksi.rekap(DateTime.now());
    if (mounted) setState(() => _rekap = rekap);
  }

  Future<void> _bukaKasir() async {
    // Tunggu pemuatan draf Beranda selesai lebih dulu. `LayarKasir` memuat
    // drafnya sendiri lagi di initState (dipakai berdiri sendiri di test),
    // dan `KeranjangController.muatDraf` mengosongkan keranjang SEBELUM
    // `await` — dua pemanggilan yang tumpang tindih bisa menggandakan isi
    // keranjang. Menunggu di sini menjamin keduanya selalu berurutan.
    await _draf;
    if (!mounted) return;
    // Dibaca dari context Beranda (di bawah MultiProvider) sebelum push —
    // context rute baru yang didorong Navigator tidak berada di bawah
    // provider manapun yang dipasang di dalam rute ini.
    final keranjang = context.read<KeranjangController>();
    await Navigator.of(context).push(
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
    // Penjualan bisa bertambah selama kasir berada di layar lain.
    if (mounted) await _muatRekap();
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
    final teks = Theme.of(context).textTheme;
    final rekap = _rekap;
    // Label tombol utama tetap satu kata pendek (muat 20/700 satu baris di
    // 360dp) — rincian jumlah barang & total pindah ke kartu draf di atasnya.
    final labelTombol = keranjang.kosong ? 'TRANSAKSI BARU' : 'LANJUTKAN';

    return Scaffold(
      body: SafeArea(
        // Konten bergulir di atas, tombol menempel di bawah: jempol satu
        // tangan menjangkaunya tanpa menggeser genggaman, dan `Expanded`
        // membuat tata letaknya mustahil meluap di layar pendek.
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  Ukuran.jarak,
                  Ukuran.jarak,
                  Ukuran.jarak,
                  0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),
                    Text(profil.namaToko, style: teks.headlineSmall),
                    if (profil.alamat.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(profil.alamat, style: teks.bodySmall),
                    ],
                    const SizedBox(height: 24),
                    if (rekap != null)
                      _Kartu(
                        label: 'Penjualan hari ini',
                        nilai: 'Rp ${formatRupiah(rekap.totalRupiah)}',
                        keterangan: '${rekap.jumlahNota} nota',
                      ),
                    if (!keranjang.kosong) ...[
                      const SizedBox(height: 12),
                      _Kartu(
                        label: 'Keranjang belum selesai',
                        nilai: 'Rp ${formatRupiah(keranjang.total)}',
                        keterangan: '${keranjang.items.length} barang',
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Ukuran.jarak),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    key: const Key('tombol-transaksi-baru-beranda'),
                    onPressed: _bukaKasir,
                    child: Text(labelTombol),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    key: const Key('tombol-pengaturan'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(Ukuran.sentuh),
                      side: const BorderSide(color: Warna.garis),
                      foregroundColor: Warna.teks,
                    ),
                    onPressed: _bukaPengaturan,
                    child: const Text('PENGATURAN'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Kartu extends StatelessWidget {
  final String label;
  final String nilai;
  final String keterangan;

  const _Kartu({
    required this.label,
    required this.nilai,
    required this.keterangan,
  });

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Ukuran.jarak),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: teks.labelLarge),
            const SizedBox(height: 8),
            Text(nilai, style: teks.headlineSmall),
            const SizedBox(height: 4),
            Text(keterangan, style: teks.bodySmall),
          ],
        ),
      ),
    );
  }
}
