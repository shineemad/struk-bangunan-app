import 'package:flutter/material.dart';

import '../../domain/item_belanja.dart';
import '../../domain/uang.dart';
import '../tema.dart';

/// Satu barang di daftar belanja.
///
/// Tombol hapus berukuran penuh di ujung kanan, dan tidak ada geser-untuk-
/// hapus: gerakan itu terlalu mudah terpicu tidak sengaja dan jarang
/// ditemukan pengguna lansia.
class BarisItem extends StatelessWidget {
  final ItemBelanja item;
  final int indeks;
  final VoidCallback onHapus;

  const BarisItem({
    super.key,
    required this.item,
    required this.indeks,
    required this.onHapus,
  });

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;

    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Warna.garis)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.nama, style: teks.bodyLarge),
                const SizedBox(height: 4),
                Text(
                  '${formatJumlah(item.qty)} ${item.satuan} '
                  'x ${formatRupiah(item.hargaSatuan)}',
                  style: teks.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatRupiah(item.subtotal),
            style: teks.bodyLarge!.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: Ukuran.sentuh,
            height: Ukuran.sentuh,
            child: IconButton(
              key: Key('hapus-$indeks'),
              onPressed: onHapus,
              tooltip: 'Hapus ${item.nama}',
              icon: const Icon(Icons.delete_outline, color: Warna.merusak),
            ),
          ),
        ],
      ),
    );
  }
}
