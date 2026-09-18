import 'package:flutter/foundation.dart';

import '../data/favorit_repository.dart';

/// Baris favorit di layar Kasir. Urutannya sudah diputuskan repository:
/// paling sering dipakai lebih dulu, lalu yang paling baru dipakai.
class FavoritController extends ChangeNotifier {
  final FavoritRepository _repo;

  FavoritController(this._repo);

  List<BahanFavorit> _daftar = const [];
  bool _sedangMemuat = true;

  List<BahanFavorit> get daftar => List.unmodifiable(_daftar);

  bool get sedangMemuat => _sedangMemuat;

  Future<void> muat() async {
    _daftar = await _repo.daftar();
    _sedangMemuat = false;
    notifyListeners();
  }

  Future<void> sembunyikan(String nama) async {
    await _repo.sembunyikan(nama);
    await muat();
  }
}
