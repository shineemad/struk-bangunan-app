import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/item_belanja.dart';

class DrafRepository {
  final SharedPreferences _prefs;

  DrafRepository(this._prefs);

  static const _kunci = 'draf_keranjang';

  /// Mengembalikan draf keranjang terakhir. Kosong ([]) bila belum pernah
  /// disimpan, atau [JSON] rusak.
  Future<List<ItemBelanja>> muat() async {
    final json = _prefs.getString(_kunci);
    if (json == null || json.isEmpty) return [];
    try {
      return _dariPeta(jsonDecode(json));
    } catch (_) {
      return [];
    }
  }

  /// Menyimpan draf keranjang sebagai [JSON].
  Future<void> simpan(List<ItemBelanja> items) async {
    final data = items
        .map(
          (e) => {
            'nama': e.nama,
            'qty': e.qty,
            'satuan': e.satuan,
            'hargaSatuan': e.hargaSatuan,
          },
        )
        .toList();
    await _prefs.setString(_kunci, jsonEncode(data));
  }

  /// Menghapus draf.
  Future<void> hapus() async {
    await _prefs.remove(_kunci);
  }

  /// Mengubah [peta] menjadi [ItemBelanja]. Mengembalikan list kosong []
  /// bila JSON tidak valid atau isi tidak sesuai format.
  static List<ItemBelanja> _dariPeta(dynamic peta) {
    try {
      if (peta is! List) return [];
      final items = <ItemBelanja>[];
      for (final m in peta) {
        if (m is! Map) return [];
        items.add(
          ItemBelanja(
            nama: m['nama'] ?? '',
            qty: (m['qty'] ?? 0).toDouble(),
            satuan: m['satuan'] ?? '',
            hargaSatuan: m['hargaSatuan'] ?? 0,
          ),
        );
      }
      return items;
    } catch (_) {
      return [];
    }
  }
}
