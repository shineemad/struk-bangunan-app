import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:struk_bangunan/ui/komponen/tanda_notaku.dart';
import 'package:struk_bangunan/ui/pembuka/layar_pembuka.dart';
import 'package:struk_bangunan/ui/tema.dart';

Future<int> _pasang(WidgetTester tester, {bool animasiMati = false}) async {
  var selesai = 0;
  await tester.pumpWidget(
    MaterialApp(
      theme: temaTerang(),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: animasiMati),
        child: LayarPembuka(onSelesai: () => selesai++),
      ),
    ),
  );
  return selesai;
}

void main() {
  testWidgets('menahan layar selama animasi masih berjalan', (tester) async {
    var selesai = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: temaTerang(),
        home: MediaQuery(
          data: const MediaQueryData(),
          child: LayarPembuka(onSelesai: () => selesai++),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 400));
    expect(selesai, 0, reason: 'pembuka belum boleh menyerahkan layar');

    await tester.pumpAndSettle();
    expect(selesai, 1);
  });

  testWidgets('menyerahkan layar tepat sekali', (tester) async {
    var selesai = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: temaTerang(),
        home: MediaQuery(
          data: const MediaQueryData(),
          child: LayarPembuka(onSelesai: () => selesai++),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Animasi yang sudah selesai tidak boleh memicu callback lagi saat ada
    // frame tambahan — pemanggil memakainya untuk berpindah layar.
    await tester.pump(const Duration(seconds: 2));

    expect(selesai, 1);
  });

  testWidgets('kertas struk tersingkap bertahap, bukan langsung utuh', (
    tester,
  ) async {
    await _pasang(tester);

    await tester.pump(const Duration(milliseconds: 400));
    final awal = tester.widget<TandaNotaku>(find.byType(TandaNotaku)).kemajuan;

    await tester.pump(const Duration(milliseconds: 500));
    final tengah = tester
        .widget<TandaNotaku>(find.byType(TandaNotaku))
        .kemajuan;

    expect(awal, lessThan(1));
    expect(tengah, greaterThan(awal));

    await tester.pumpAndSettle();
    expect(tester.widget<TandaNotaku>(find.byType(TandaNotaku)).kemajuan, 1);
  });

  testWidgets('pengguna yang mematikan animasi sistem tidak ditahan', (
    tester,
  ) async {
    var selesai = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: temaTerang(),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: LayarPembuka(onSelesai: () => selesai++),
        ),
      ),
    );

    // Satu frame, bukan 1,6 detik.
    await tester.pump();

    expect(selesai, 1);
    expect(tester.widget<TandaNotaku>(find.byType(TandaNotaku)).kemajuan, 1);
  });
}
