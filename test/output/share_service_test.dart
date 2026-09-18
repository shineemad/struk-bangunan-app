import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:struk_bangunan/data/pengaturan_keluaran_repository.dart';
import 'package:struk_bangunan/output/berkas_sementara.dart';
import 'package:struk_bangunan/output/share_service.dart';

Future<BerkasSementara> _folderUji() async {
  final folder = await Directory.systemTemp.createTemp('struk_berbagi');
  addTearDown(() async {
    if (await folder.exists()) await folder.delete(recursive: true);
  });
  return BerkasSementara(Directory(p.join(folder.path, 'struk')));
}

void main() {
  test('nama berkas struk mengikuti format kiriman', () {
    expect(namaBerkasStruk('0142', FormatKiriman.png), 'struk-0142.png');
    expect(namaBerkasStruk('0142', FormatKiriman.pdf), 'struk-0142.pdf');
  });

  test('nama berkas cadangan memakai tanggal berdigit dua', () {
    expect(
      namaBerkasCadangan(DateTime(2026, 9, 5)),
      'strukbangunan-backup-20260905.json',
    );
    expect(
      namaBerkasCadangan(DateTime(2026, 12, 31)),
      'strukbangunan-backup-20261231.json',
    );
  });

  test('membagikan menulis berkas lalu menyerahkan jalurnya', () async {
    final berkas = await _folderUji();
    String? jalurTerkirim;
    String? teksTerkirim;
    final layanan = ShareService(
      berkas,
      kirim: (jalur, teks) async {
        jalurTerkirim = jalur;
        teksTerkirim = teks;
      },
    );

    await layanan.bagikan(
      nama: 'struk-0142.png',
      isi: [1, 2, 3],
      teks: 'Struk #0142',
    );

    expect(p.basename(jalurTerkirim!), 'struk-0142.png');
    expect(teksTerkirim, 'Struk #0142');
    expect(await File(jalurTerkirim!).readAsBytes(), [1, 2, 3]);
  });

  test('membagikan membuang berkas basi lebih dulu', () async {
    final berkas = await _folderUji();
    final basi = await berkas.tulis('basi.png', [7]);
    await basi.setLastModified(
      DateTime.now().subtract(const Duration(days: 2)),
    );

    final layanan = ShareService(berkas, kirim: (_, _) async {});
    await layanan.bagikan(nama: 'struk-0142.png', isi: [1]);

    expect(await basi.exists(), isFalse);
  });
}
