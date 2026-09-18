import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:struk_bangunan/domain/receipt/receipt_document.dart';
import 'package:struk_bangunan/output/receipt_widget.dart';

ReceiptDocument _contoh() => ReceiptDocument(
  lebar: 32,
  baris: [
    const BarisStruk('       TB. SINAR BANGUNAN       ', gaya: GayaBaris.tebal),
    const BarisStruk(
      '--------------------------------',
      gaya: GayaBaris.pemisah,
    ),
    const BarisStruk('Semen Tiga Roda'),
    const BarisStruk('               3x65.000  195.000'),
    const BarisStruk('TOTAL               Rp 1.825.000', gaya: GayaBaris.tebal),
  ],
);

Future<void> _pasang(WidgetTester tester, ReceiptDocument dokumen) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: ReceiptWidget(dokumen: dokumen)),
    ),
  );
}

void main() {
  testWidgets('menampilkan setiap baris apa adanya', (tester) async {
    final dokumen = _contoh();
    await _pasang(tester, dokumen);

    for (final baris in dokumen.baris) {
      expect(find.text(baris.teks), findsOneWidget);
    }
  });

  testWidgets('baris tebal dicetak tebal, baris lain tidak', (tester) async {
    final dokumen = _contoh();
    await _pasang(tester, dokumen);

    for (final baris in dokumen.baris) {
      final widget = tester.widget<Text>(find.text(baris.teks));
      expect(
        widget.style!.fontWeight,
        baris.gaya == GayaBaris.tebal ? FontWeight.bold : FontWeight.normal,
        reason: 'gaya salah pada: ${baris.teks}',
      );
    }
  });

  testWidgets('memakai huruf berlebar tetap', (tester) async {
    final dokumen = _contoh();
    await _pasang(tester, dokumen);

    final widget = tester.widget<Text>(find.text(dokumen.baris.first.teks));
    expect(widget.style!.fontFamily, 'monospace');
  });

  testWidgets('baris tidak pernah dibungkus ke baris berikutnya', (
    tester,
  ) async {
    // Pembungkusan akan merusak perataan kolom yang sudah dihitung
    // ReceiptBuilder, dan merusaknya diam-diam.
    final dokumen = _contoh();
    await _pasang(tester, dokumen);

    for (final baris in dokumen.baris) {
      final widget = tester.widget<Text>(find.text(baris.teks));
      expect(widget.softWrap, isFalse);
      expect(widget.maxLines, 1);
    }
  });

  testWidgets('struk kosong tidak melempar', (tester) async {
    await _pasang(tester, ReceiptDocument(lebar: 32, baris: const []));
    expect(find.byType(ReceiptWidget), findsOneWidget);
  });

  testWidgets('tampilan struk 58mm terkunci', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: RepaintBoundary(child: ReceiptWidget(dokumen: _contoh())),
        ),
      ),
    );

    await expectLater(
      find.byType(ReceiptWidget),
      matchesGoldenFile('goldens/struk_58mm.png'),
    );
  });
}
