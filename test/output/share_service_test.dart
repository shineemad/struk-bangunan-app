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

/// Mencatat urutan pemanggilan metode, lalu meneruskan ke implementasi asli.
///
/// Dipakai untuk membuktikan urutan operasi `bagikan`, bukan hanya hasil
/// akhirnya — asersi hasil akhir saja tidak membuktikan urutan.
class _BerkasSementaraPencatat extends BerkasSementara {
  final List<String> urutanPanggilan = [];

  _BerkasSementaraPencatat(super.folder);

  @override
  Future<int> bersihkanLebihTuaDari(Duration umur, {DateTime? sekarang}) async {
    urutanPanggilan.add('bersihkan');
    return super.bersihkanLebihTuaDari(umur, sekarang: sekarang);
  }

  @override
  Future<File> tulis(String nama, List<int> isi) async {
    urutanPanggilan.add('tulis');
    return super.tulis(nama, isi);
  }
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

  test(
    'membagikan mengunci urutan bersihkan-tulis-kirim, bukan cuma hasil akhir',
    () async {
      final folder = await Directory.systemTemp.createTemp('struk_berbagi');
      addTearDown(() async {
        if (await folder.exists()) await folder.delete(recursive: true);
      });
      final target = Directory(p.join(folder.path, 'struk'));

      final basi = await BerkasSementara(target).tulis('basi.png', [7]);
      await basi.setLastModified(
        DateTime.now().subtract(const Duration(days: 2)),
      );

      final pencatat = _BerkasSementaraPencatat(target);
      final urutanPenuh = <String>[];
      final layanan = ShareService(
        pencatat,
        kirim: (_, _) async {
          urutanPenuh.add('kirim');
        },
      );

      await layanan.bagikan(nama: 'struk-0142.png', isi: [9, 9]);
      urutanPenuh.insertAll(0, pencatat.urutanPanggilan);

      expect(pencatat.urutanPanggilan, ['bersihkan', 'tulis']);
      expect(urutanPenuh, ['bersihkan', 'tulis', 'kirim']);
      expect(await basi.exists(), isFalse);
      expect(await File(p.join(target.path, 'struk-0142.png')).readAsBytes(), [
        9,
        9,
      ]);
    },
  );
}
