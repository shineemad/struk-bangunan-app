import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:struk_bangunan/output/berkas_sementara.dart';

Future<BerkasSementara> _siap() async {
  final folder = await Directory.systemTemp.createTemp('struk_sementara');
  addTearDown(() async {
    if (await folder.exists()) await folder.delete(recursive: true);
  });
  return BerkasSementara(Directory(p.join(folder.path, 'struk')));
}

void main() {
  test('menulis berkas beserta isinya', () async {
    final berkas = await _siap();
    final hasil = await berkas.tulis('struk-0001.png', [1, 2, 3]);

    expect(await hasil.exists(), isTrue);
    expect(await hasil.readAsBytes(), [1, 2, 3]);
  });

  test('membuang berkas yang sudah basi dan menyisakan yang baru', () async {
    final berkas = await _siap();
    final lama = await berkas.tulis('lama.png', [1]);
    await berkas.tulis('baru.png', [2]);
    await lama.setLastModified(
      DateTime.now().subtract(const Duration(hours: 5)),
    );

    final dibuang = await berkas.bersihkanLebihTuaDari(
      const Duration(hours: 1),
    );

    expect(dibuang, 1);
    expect(await lama.exists(), isFalse);
    expect(await File(p.join(berkas.folder.path, 'baru.png')).exists(), isTrue);
  });

  test('membersihkan folder yang belum ada tidak melempar', () async {
    final berkas = await _siap();
    expect(await berkas.bersihkanLebihTuaDari(const Duration(hours: 1)), 0);
  });

  test('menulis dua kali dengan nama sama menimpa isinya', () async {
    final berkas = await _siap();
    await berkas.tulis('struk-0001.png', [1, 2, 3]);
    final hasil = await berkas.tulis('struk-0001.png', [9]);

    expect(await hasil.readAsBytes(), [9]);
  });
}
