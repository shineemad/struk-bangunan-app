import 'package:flutter_test/flutter_test.dart';
import 'package:struk_bangunan/data/basisdata.dart';
import 'package:struk_bangunan/data/favorit_repository.dart';
import 'package:struk_bangunan/state/favorit_controller.dart';

import '../bantuan_basisdata.dart';

Future<(FavoritRepository, FavoritController)> _siap() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final db = await bukaBasisdataUji();
  await siapkanSkema(db);
  addTearDown(db.close);
  final repo = FavoritRepository(db);
  return (repo, FavoritController(repo));
}

void main() {
  test('sebelum dimuat daftarnya kosong dan ditandai memuat', () async {
    final (_, favorit) = await _siap();

    expect(favorit.daftar, isEmpty);
    expect(favorit.sedangMemuat, isTrue);
  });

  test('memuat mengisi daftar dan memberi tahu pendengar', () async {
    final (repo, favorit) = await _siap();
    await repo.isiBawaanBilaKosong();
    var pemberitahuan = 0;
    favorit.addListener(() => pemberitahuan++);

    await favorit.muat();

    expect(favorit.daftar, isNotEmpty);
    expect(favorit.sedangMemuat, isFalse);
    expect(pemberitahuan, greaterThanOrEqualTo(1));
  });

  test('yang paling sering dipakai berada di urutan pertama', () async {
    final (repo, favorit) = await _siap();
    await repo.catatPemakaian('Pasir', 'rit', DateTime(2026, 9, 17));
    await repo.catatPemakaian('Semen', 'sak', DateTime(2026, 9, 17));
    await repo.catatPemakaian('Semen', 'sak', DateTime(2026, 9, 18));

    await favorit.muat();

    expect(favorit.daftar.first.nama, 'Semen');
    expect(favorit.daftar.first.jumlahPakai, 2);
  });

  test('menyembunyikan membuang bahan dari daftar', () async {
    final (repo, favorit) = await _siap();
    await repo.catatPemakaian('Semen', 'sak', DateTime(2026, 9, 18));
    await favorit.muat();

    await favorit.sembunyikan('Semen');

    expect(favorit.daftar.where((f) => f.nama == 'Semen'), isEmpty);
  });
}
