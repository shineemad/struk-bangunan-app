import 'uang.dart';

/// Satu baris belanjaan. Subtotal dihitung dan dibekukan saat item dibuat,
/// sehingga nota lama yang dicetak ulang tidak pernah berubah nilainya.
class ItemBelanja {
  final String nama;
  final double qty;
  final String satuan;
  final int hargaSatuan;
  final int subtotal;

  const ItemBelanja._({
    required this.nama,
    required this.qty,
    required this.satuan,
    required this.hargaSatuan,
    required this.subtotal,
  });

  factory ItemBelanja({
    required String nama,
    required double qty,
    required String satuan,
    required int hargaSatuan,
  }) {
    final namaRapi = nama.trim();
    if (namaRapi.isEmpty) {
      throw ArgumentError.value(nama, 'nama', 'Nama bahan tidak boleh kosong');
    }
    if (qty <= 0) {
      throw ArgumentError.value(
        qty,
        'qty',
        'Jumlah harus lebih besar dari nol',
      );
    }
    if (hargaSatuan < 0) {
      throw ArgumentError.value(
        hargaSatuan,
        'hargaSatuan',
        'Harga tidak boleh negatif',
      );
    }
    if (hargaSatuan > maksRupiah) {
      throw ArgumentError.value(
        hargaSatuan,
        'hargaSatuan',
        'Harga melebihi batas yang diizinkan',
      );
    }
    return ItemBelanja._(
      nama: namaRapi,
      qty: qty,
      satuan: satuan.trim(),
      hargaSatuan: hargaSatuan,
      subtotal: (qty * hargaSatuan).round(),
    );
  }
}
