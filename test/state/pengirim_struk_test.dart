import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:struk_bangunan/data/pengaturan_keluaran_repository.dart';
import 'package:struk_bangunan/domain/item_belanja.dart';
import 'package:struk_bangunan/domain/receipt/receipt_document.dart';
import 'package:struk_bangunan/domain/transaksi.dart';
import 'package:struk_bangunan/output/berkas_sementara.dart';
import 'package:struk_bangunan/output/receipt_widget.dart';
import 'package:struk_bangunan/output/share_service.dart';
import 'package:struk_bangunan/state/pengirim_struk.dart';

Transaksi _nota() => Transaksi(
  nomorNota: '0142',
  waktu: DateTime(2026, 9, 18, 14, 30),
  items: [
    ItemBelanja(nama: 'Semen', qty: 3, satuan: 'sak', hargaSatuan: 65000),
  ],
);

Future<GlobalKey> _pasangStruk(WidgetTester tester) async {
  final kunci = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: RepaintBoundary(
          key: kunci,
          child: ReceiptWidget(
            dokumen: ReceiptDocument(
              lebar: 32,
              baris: const [BarisStruk('TOTAL               Rp   195.000')],
            ),
          ),
        ),
      ),
    ),
  );
  return kunci;
}

void main() {
  testWidgets('mengirim PNG dengan nama berkas dari nomor nota', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    // I/O sinkron di luar runAsync: lihat Ruling 1 di dispatch — versi await
    // menggantung karena badan testWidgets berjalan dalam zona FakeAsync.
    final folder = Directory.systemTemp.createTempSync('struk_kirim');
    addTearDown(() => folder.deleteSync(recursive: true));

    String? jalur;
    final pengirim = PengirimStruk(
      PengaturanKeluaranRepository(await SharedPreferences.getInstance()),
      ShareService(
        BerkasSementara(Directory(p.join(folder.path, 'struk'))),
        kirim: (berkas, _) async => jalur = berkas,
      ),
    );
    final kunci = await _pasangStruk(tester);

    await tester.runAsync(() async {
      await pengirim.kirim(kunciBoundary: kunci, nota: _nota(), lebarKolom: 32);
    });

    expect(p.basename(jalur!), 'struk-0142.png');
    expect(File(jalur!).readAsBytesSync(), isNotEmpty);
  });

  testWidgets('setelan PDF menghasilkan berkas PDF', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final folder = Directory.systemTemp.createTempSync('struk_kirim');
    addTearDown(() => folder.deleteSync(recursive: true));

    final pengaturan = PengaturanKeluaranRepository(
      await SharedPreferences.getInstance(),
    );
    await pengaturan.simpan(
      const PengaturanKeluaran(formatKiriman: FormatKiriman.pdf),
    );

    String? jalur;
    final pengirim = PengirimStruk(
      pengaturan,
      ShareService(
        BerkasSementara(Directory(p.join(folder.path, 'struk'))),
        kirim: (berkas, _) async => jalur = berkas,
      ),
    );
    final kunci = await _pasangStruk(tester);

    await tester.runAsync(() async {
      await pengirim.kirim(kunciBoundary: kunci, nota: _nota(), lebarKolom: 32);
    });

    expect(p.basename(jalur!), 'struk-0142.pdf');
    final isi = File(jalur!).readAsBytesSync();
    expect(String.fromCharCodes(isi.take(5)), '%PDF-');
  });
}
