import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:struk_bangunan/domain/receipt/receipt_document.dart';
import 'package:struk_bangunan/output/pdf_renderer.dart';
import 'package:struk_bangunan/output/png_renderer.dart';
import 'package:struk_bangunan/output/receipt_widget.dart';

// Menguraikan lebar (poin) dari kamus halaman PDF, mis. "/MediaBox[0 0 161 15]" -> 161.
double? _lebarMediaBoxDari(Uint8List pdf) {
  final cocok = RegExp(
    r'/MediaBox\s*\[\s*0\s+0\s+([\d.]+)\s+[\d.]+\s*\]',
  ).firstMatch(String.fromCharCodes(pdf));
  return cocok == null ? null : double.parse(cocok.group(1)!);
}

Future<Uint8List> _pngContoh(WidgetTester tester) async {
  final kunci = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: RepaintBoundary(
          key: kunci,
          child: ReceiptWidget(
            dokumen: ReceiptDocument(
              lebar: 32,
              baris: const [BarisStruk('TOTAL               Rp 1.825.000')],
            ),
          ),
        ),
      ),
    ),
  );

  late Uint8List png;
  await tester.runAsync(() async {
    png = await ambilPng(kunci);
  });
  return png;
}

void main() {
  testWidgets('menghasilkan PDF satu halaman yang sah', (tester) async {
    final png = await _pngContoh(tester);

    late Uint8List pdf;
    await tester.runAsync(() async {
      pdf = await susunPdf(png: png, lebarKolom: 32);
    });

    expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
    expect(pdf.length, greaterThan(png.length));
  });

  testWidgets('kertas 80mm menghasilkan halaman lebih lebar', (tester) async {
    final png = await _pngContoh(tester);

    late Uint8List sempit;
    late Uint8List lebar;
    await tester.runAsync(() async {
      sempit = await susunPdf(png: png, lebarKolom: 32);
      lebar = await susunPdf(png: png, lebarKolom: 48);
    });

    final lebarSempit = _lebarMediaBoxDari(sempit);
    final lebarLebar = _lebarMediaBoxDari(lebar);

    expect(lebarSempit, isNotNull);
    expect(lebarLebar, isNotNull);
    expect(lebarSempit!, closeTo(lebarHalamanPdf(32), 0.01));
    expect(lebarLebar!, closeTo(lebarHalamanPdf(48), 0.01));
    expect(lebarLebar, greaterThan(lebarSempit));
  });

  testWidgets('byte yang bukan gambar ditolak', (tester) async {
    await tester.runAsync(() async {
      await expectLater(
        susunPdf(png: Uint8List.fromList([1, 2, 3]), lebarKolom: 32),
        throwsA(isA<RangeError>()),
      );
    });
  });
}
