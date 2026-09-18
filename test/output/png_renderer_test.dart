import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:struk_bangunan/domain/receipt/receipt_document.dart';
import 'package:struk_bangunan/output/png_renderer.dart';
import 'package:struk_bangunan/output/receipt_widget.dart';

void main() {
  testWidgets('menghasilkan PNG yang sah dari struk yang tampil', (
    tester,
  ) async {
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

    // toImage dan toByteData menuntut gelang kejadian sungguhan; tanpa
    // runAsync keduanya menggantung di dalam uji widget.
    late Uint8List png;
    await tester.runAsync(() async {
      png = await ambilPng(kunci);
    });

    expect(png.take(4).toList(), [0x89, 0x50, 0x4E, 0x47]);
    expect(png.length, greaterThan(100));
  });

  testWidgets('kunci yang tidak menunjuk RepaintBoundary ditolak', (
    tester,
  ) async {
    final kunci = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(home: SizedBox(key: kunci, width: 10, height: 10)),
    );

    await tester.runAsync(() async {
      await expectLater(ambilPng(kunci), throwsStateError);
    });
  });
}
