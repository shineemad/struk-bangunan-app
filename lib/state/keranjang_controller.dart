import 'package:flutter/foundation.dart';

import '../data/draf_repository.dart';
import '../data/favorit_repository.dart';
import '../data/transaksi_repository.dart';
import '../domain/item_belanja.dart';
import '../domain/transaksi.dart';

/// Keranjang belanja yang sedang berjalan.
///
/// Setiap perubahan langsung ditulis sebagai draf: toko bangunan sering
/// terinterupsi, dan kehilangan keranjang setengah jadi adalah kegagalan
/// yang mahal.
class KeranjangController extends ChangeNotifier {
  final DrafRepository _draf;
  final TransaksiRepository _transaksi;
  final FavoritRepository _favorit;

  KeranjangController({
    required DrafRepository draf,
    required TransaksiRepository transaksi,
    required FavoritRepository favorit,
  }) : _draf = draf,
       _transaksi = transaksi,
       _favorit = favorit;

  final List<ItemBelanja> _items = [];

  List<ItemBelanja> get items => List.unmodifiable(_items);

  int get total => _items.fold(0, (jumlah, item) => jumlah + item.subtotal);

  bool get kosong => _items.isEmpty;

  Future<void> muatDraf() async {
    _items
      ..clear()
      ..addAll(await _draf.muat());
    notifyListeners();
  }

  Future<void> tambah(ItemBelanja item) async {
    _items.add(item);
    await _draf.simpan(_items);
    notifyListeners();
  }

  Future<void> hapusPada(int indeks) async {
    _items.removeAt(indeks);
    await _draf.simpan(_items);
    notifyListeners();
  }

  Future<void> kosongkan() async {
    _items.clear();
    await _draf.hapus();
    notifyListeners();
  }

  /// Menyimpan nota, lalu mencatat pemakaian favorit **berurutan sesudahnya**.
  ///
  /// `catatPemakaian` membuka transaksinya sendiri dan tidak punya varian
  /// yang menerima executor. Memanggilnya dari dalam transaksi `simpan` akan
  /// menggantung selamanya, bukan gagal.
  Future<Transaksi> simpan({int? bayar, DateTime? waktu}) async {
    final nota = await _transaksi.simpan(
      items: _items,
      waktu: waktu ?? DateTime.now(),
      bayar: bayar,
    );

    for (final item in nota.items) {
      await _favorit.catatPemakaian(item.nama, item.satuan, nota.waktu);
    }

    await kosongkan();
    return nota;
  }
}
