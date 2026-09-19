import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/item_belanja.dart';
import '../../domain/uang.dart';
import '../../state/favorit_controller.dart';
import '../../state/keranjang_controller.dart';
import '../komponen/baris_item.dart';
import '../komponen/chip_satuan.dart';
import '../komponen/isian.dart';
import '../tema.dart';

class LayarKasir extends StatefulWidget {
  /// Dipanggil saat kasir menekan tombol kirim. Layar ini tidak tahu apa pun
  /// tentang tujuan berikutnya — pemanggilnya yang memutuskan.
  final VoidCallback onKirim;

  const LayarKasir({super.key, required this.onKirim});

  @override
  State<LayarKasir> createState() => _LayarKasirState();
}

class _LayarKasirState extends State<LayarKasir> {
  final _nama = TextEditingController();
  final _jumlah = TextEditingController(text: '1');
  final _harga = TextEditingController();
  final _fokusHarga = FocusNode();
  String _satuan = satuanBawaan.first;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<KeranjangController>().muatDraf();
      context.read<FavoritController>().muat();
    });
  }

  @override
  void dispose() {
    _nama.dispose();
    _jumlah.dispose();
    _harga.dispose();
    _fokusHarga.dispose();
    super.dispose();
  }

  bool get _bolehTambah => _nama.text.trim().isNotEmpty;

  /// Spec bagian 5: jumlah terisi otomatis 1, dengan tombol besar di kiri dan
  /// kanannya. Tidak pernah turun ke nol — `ItemBelanja` menolaknya, dan
  /// kesalahan yang bisa dicegah tidak boleh jadi pesan galat.
  void _ubahJumlah(int langkah) {
    final sekarang = bacaJumlah(_jumlah.text) ?? 1;
    final baru = (sekarang + langkah).clamp(1, 999999);
    setState(() => _jumlah.text = formatJumlah(baru.toDouble()));
  }

  Future<void> _tambah() async {
    final qty = bacaJumlah(_jumlah.text) ?? 1;
    final harga = parseRupiah(_harga.text) ?? 0;
    if (qty <= 0) return;

    await context.read<KeranjangController>().tambah(
      ItemBelanja(
        nama: _nama.text.trim(),
        qty: qty,
        satuan: _satuan,
        hargaSatuan: harga,
      ),
    );

    setState(() {
      _nama.clear();
      _jumlah.text = '1';
      _harga.clear();
    });
  }

  Future<void> _tanyaHapus(int indeks) async {
    final setuju = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Hapus barang ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Hapus', style: TextStyle(color: Warna.merusak)),
          ),
        ],
      ),
    );

    if (setuju ?? false) {
      if (!mounted) return;
      await context.read<KeranjangController>().hapusPada(indeks);
    }
  }

  void _pakaiFavorit(String nama, String satuan) {
    setState(() {
      _nama.text = nama;
      if (satuan.isNotEmpty) _satuan = satuan;
    });
    _fokusHarga.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final keranjang = context.watch<KeranjangController>();
    final favorit = context.watch<FavoritController>();
    final keyboardTerbuka = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Kasir')),
      body: Column(
        children: [
          // Bagian atas (tetap): form input, sepertiga atas layar. Hanya
          // kolom isian dan chip satuan yang bergulir (SingleChildScrollView)
          // bila kontennya tak muat — tombol TAMBAH di bawahnya tetap di
          // tempat, supaya tidak pernah jatuh di bawah lipatan pada layar
          // pendek. Form dipakai untuk setiap barang, tidak boleh hilang.
          Flexible(
            flex: 3,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Ukuran.jarak,
                        Ukuran.jarak,
                        Ukuran.jarak,
                        0,
                      ),
                      child: Column(
                        children: [
                          KolomIsian(
                            key: const Key('kolom-nama'),
                            label: 'Nama bahan',
                            controller: _nama,
                            hint: 'Semen, pasir, paku...',
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 12),
                          // Spec bagian 5: jumlah + satuan + harga satuan
                          // dalam satu baris — jumlah dan harga di sini,
                          // chip satuan tetap pada barisnya sendiri di
                          // bawah. flex 2:3 menyisakan kolom harga cukup
                          // lebar untuk nominal terpanjang (999.999.999).
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _TombolJumlah(
                                key: const Key('jumlah-kurang'),
                                ikon: Icons.remove,
                                label: 'Kurangi jumlah',
                                onTekan: () => _ubahJumlah(-1),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: KolomIsian(
                                  key: const Key('kolom-jumlah'),
                                  label: 'Jumlah',
                                  controller: _jumlah,
                                  angka: true,
                                  formatters: [FormatterJumlah()],
                                ),
                              ),
                              const SizedBox(width: 8),
                              _TombolJumlah(
                                key: const Key('jumlah-tambah'),
                                ikon: Icons.add,
                                label: 'Tambah jumlah',
                                onTekan: () => _ubahJumlah(1),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 3,
                                child: KolomIsian(
                                  key: const Key('kolom-harga'),
                                  label: 'Harga satuan',
                                  controller: _harga,
                                  hint: '0',
                                  angka: true,
                                  formatters: [FormatterRupiah()],
                                  focusNode: _fokusHarga,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: Ukuran.sentuh,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: satuanBawaan.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (_, i) => ChipSatuan(
                                satuan: satuanBawaan[i],
                                terpilih: satuanBawaan[i] == _satuan,
                                onPilih: () =>
                                    setState(() => _satuan = satuanBawaan[i]),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Ukuran.jarak,
                    0,
                    Ukuran.jarak,
                    Ukuran.jarak,
                  ),
                  child: FilledButton(
                    key: const Key('tombol-tambah'),
                    onPressed: _bolehTambah ? _tambah : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: Warna.tambah,
                    ),
                    child: const Text('+ TAMBAH KE DAFTAR'),
                  ),
                ),
              ],
            ),
          ),
          // Bagian tengah (bergulir): favorit lalu daftar item, spec bagian 5.
          Flexible(
            flex: 2,
            child: Column(
              children: [
                if (!favorit.sedangMemuat && favorit.daftar.isNotEmpty)
                  SizedBox(
                    height: Ukuran.sentuh + 16,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: Ukuran.jarak,
                      ),
                      itemCount: favorit.daftar.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final bahan = favorit.daftar[i];
                        return ChipSatuan(
                          satuan: bahan.nama,
                          terpilih: false,
                          onPilih: () =>
                              _pakaiFavorit(bahan.nama, bahan.satuanTerakhir),
                        );
                      },
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    key: const Key('daftar-item'),
                    itemCount: keranjang.items.length,
                    itemBuilder: (_, i) => BarisItem(
                      key: Key('baris-$i'),
                      item: keranjang.items[i],
                      indeks: i,
                      onHapus: () => _tanyaHapus(i),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!keyboardTerbuka)
            Container(
              padding: const EdgeInsets.all(Ukuran.jarak),
              decoration: const BoxDecoration(
                color: Warna.permukaan,
                border: Border(top: BorderSide(color: Warna.garis)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TOTAL',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Flexible(
                        child: Text(
                          'Rp ${formatRupiah(keranjang.total)}',
                          textAlign: TextAlign.right,
                          style: Theme.of(context).textTheme.headlineSmall!
                              .copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    key: const Key('tombol-kirim'),
                    onPressed: keranjang.kosong ? null : widget.onKirim,
                    child: const Text('BUAT STRUK'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Tombol besar pengapit kolom jumlah. Lebarnya mengikuti lantai area sentuh,
/// bukan ukuran ikonnya.
class _TombolJumlah extends StatelessWidget {
  final IconData ikon;
  final String label;
  final VoidCallback onTekan;

  const _TombolJumlah({
    super.key,
    required this.ikon,
    required this.label,
    required this.onTekan,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        width: Ukuran.tombol,
        height: Ukuran.isian,
        child: Material(
          color: Warna.isian,
          borderRadius: BorderRadius.circular(Ukuran.radiusIsian),
          child: InkWell(
            onTap: onTekan,
            borderRadius: BorderRadius.circular(Ukuran.radiusIsian),
            child: Icon(ikon, size: 28, color: Warna.teks),
          ),
        ),
      ),
    );
  }
}
