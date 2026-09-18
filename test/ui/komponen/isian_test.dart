import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:struk_bangunan/ui/komponen/chip_satuan.dart';
import 'package:struk_bangunan/ui/komponen/isian.dart';
import 'package:struk_bangunan/ui/tema.dart';

TextEditingValue _nilai(String teks) => TextEditingValue(
  text: teks,
  selection: TextSelection.collapsed(offset: teks.length),
);

String _ketik(TextInputFormatter formatter, String lama, String baru) =>
    formatter.formatEditUpdate(_nilai(lama), _nilai(baru)).text;

void main() {
  group('FormatterRupiah', () {
    final formatter = FormatterRupiah();

    test('memberi titik ribuan sambil diketik', () {
      expect(_ketik(formatter, '6', '65'), '65');
      expect(_ketik(formatter, '65', '650'), '650');
      expect(_ketik(formatter, '650', '6500'), '6.500');
      expect(_ketik(formatter, '6.500', '65000'), '65.000');
    });

    test('mengabaikan karakter selain angka', () {
      expect(_ketik(formatter, '65.000', '65.000a'), '65.000');
    });

    test('menolak nominal di atas batas dengan menahan nilai lama', () {
      expect(_ketik(formatter, '999.999.999', '9999999991'), '999.999.999');
    });

    test('mengosongkan kolom tetap boleh', () {
      expect(_ketik(formatter, '65.000', ''), '');
    });

    test('nol diizinkan karena barang bonus itu nyata', () {
      expect(_ketik(formatter, '', '0'), '0');
    });
  });

  group('FormatterJumlah', () {
    final formatter = FormatterJumlah();

    test('menerima bilangan bulat dan pecahan dua angka', () {
      expect(_ketik(formatter, '1', '1,5'), '1,5');
      expect(_ketik(formatter, '1,5', '1,55'), '1,55');
    });

    test('menolak angka desimal ketiga', () {
      expect(_ketik(formatter, '1,55', '1,555'), '1,55');
    });

    test('menolak koma kedua', () {
      expect(_ketik(formatter, '1,5', '1,5,'), '1,5');
    });

    test('menolak titik sebagai pemisah desimal', () {
      expect(_ketik(formatter, '1', '1.'), '1');
    });
  });

  group('bacaJumlah', () {
    test('membaca koma sebagai pemisah desimal', () {
      expect(bacaJumlah('1,5'), 1.5);
      expect(bacaJumlah('3'), 3);
    });

    test('mengembalikan null untuk isian yang tidak sah', () {
      expect(bacaJumlah(''), isNull);
      expect(bacaJumlah('abc'), isNull);
    });
  });

  group('KolomIsian', () {
    testWidgets('menampilkan labelnya dan tinggi kolomnya memenuhi lantai', (
      tester,
    ) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          theme: temaTerang(),
          home: Scaffold(
            body: KolomIsian(label: 'Nama Barang', controller: controller),
          ),
        ),
      );

      expect(find.text('Nama Barang'), findsOneWidget);
      expect(tester.getSize(find.byType(TextField)).height, Ukuran.isian);
    });
  });

  group('ChipSatuan', () {
    testWidgets(
      'memenuhi lantai area sentuh dan berubah tampilan saat terpilih',
      (tester) async {
        Future<void> pump(bool terpilih) => tester.pumpWidget(
          MaterialApp(
            theme: temaTerang(),
            home: Scaffold(
              body: ChipSatuan(
                satuan: 'kg',
                terpilih: terpilih,
                onPilih: () {},
              ),
            ),
          ),
        );

        await pump(false);
        expect(
          tester.getSize(find.byType(ChipSatuan)).height,
          greaterThanOrEqualTo(Ukuran.sentuh),
        );
        final materialTidakTerpilih = tester.widget<Material>(
          find
              .descendant(
                of: find.byType(ChipSatuan),
                matching: find.byType(Material),
              )
              .first,
        );
        expect(materialTidakTerpilih.color, Warna.isian);

        await pump(true);
        final materialTerpilih = tester.widget<Material>(
          find
              .descendant(
                of: find.byType(ChipSatuan),
                matching: find.byType(Material),
              )
              .first,
        );
        expect(materialTerpilih.color, Warna.aksen);
      },
    );
  });
}
