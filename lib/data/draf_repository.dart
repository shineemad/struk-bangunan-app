import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/item_belanja.dart';

/// Keranjang yang sedang berjalan. Toko bangunan sering terinterupsi, jadi
/// keranjang setengah jadi tidak boleh hilang saat aplikasi tertutup.
class DrafRepository {
  final SharedPreferences _prefs;

  DrafRepository(this._prefs);

  static const _kunci = 'draf_keranjang';

  Future<List<ItemBelanja>> muat() async {
    final teks = _prefs.getString(_kunci);
    if (teks == null || teks.isEmpty) return [];
    try {
      final data = jsonDecode(teks);
      if (data is! List) return [];
      return data.map(_dariPeta).whereType<ItemBelanja>().toList();
    } on FormatException {
      return [];
    }
  }

  Future<void> simpan(List<ItemBelanja> items) async {
    final data = items
        .map(
          (i) => {
            'nama': i.nama,
            'qty': i.qty,
            'satuan': i.satuan,
            'harga_satuan': i.hargaSatuan,
          },
        )
        .toList();
    await _prefs.setString(_kunci, jsonEncode(data));
  }

  Future<void> hapus() => _prefs.remove(_kunci);

  /// Baris yang cacat dilewati, bukan menggagalkan seluruh draf.
  static ItemBelanja? _dariPeta(Object? data) {
    if (data is! Map) return null;
    final nama = data['nama'];
    final qty = data['qty'];
    final satuan = data['satuan'];
    final harga = data['harga_satuan'];
    if (nama is! String || qty is! num || satuan is! String || harga is! int) {
      return null;
    }
    try {
      return ItemBelanja(
        nama: nama,
        qty: qty.toDouble(),
        satuan: satuan,
        hargaSatuan: harga,
      );
    } on ArgumentError {
      return null;
    }
  }
}
