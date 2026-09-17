import 'item_belanja.dart';

/// Satu nota belanja. Kembalian boleh negatif; pemanggil yang memutuskan
/// apakah keadaan itu ditampilkan sebagai kekurangan bayar.
class Transaksi {
  final String nomorNota;
  final DateTime waktu;
  final List<ItemBelanja> items;
  final int? bayar;

  Transaksi({
    required this.nomorNota,
    required this.waktu,
    required List<ItemBelanja> items,
    this.bayar,
  }) : items = List.unmodifiable(items);

  int get total => items.fold(0, (jumlah, item) => jumlah + item.subtotal);

  int? get kembali => bayar == null ? null : bayar! - total;
}
