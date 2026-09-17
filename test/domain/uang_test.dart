import 'package:flutter_test/flutter_test.dart';
import 'package:struk_bangunan/domain/uang.dart';

void main() {
  group('formatRupiah', () {
    test('menyisipkan titik setiap tiga digit', () {
      expect(formatRupiah(0), '0');
      expect(formatRupiah(500), '500');
      expect(formatRupiah(65000), '65.000');
      expect(formatRupiah(195000), '195.000');
      expect(formatRupiah(1825000), '1.825.000');
      expect(formatRupiah(999999999), '999.999.999');
    });

    test('nilai negatif memakai awalan minus', () {
      expect(formatRupiah(-25000), '-25.000');
    });
  });

  group('parseRupiah', () {
    test('mengabaikan titik, spasi, dan awalan Rp', () {
      expect(parseRupiah('65.000'), 65000);
      expect(parseRupiah('65000'), 65000);
      expect(parseRupiah('Rp 65.000'), 65000);
    });

    test('mengembalikan null bila tidak ada digit', () {
      expect(parseRupiah(''), isNull);
      expect(parseRupiah('abc'), isNull);
    });

    test('mengembalikan null bila bertanda minus', () {
      expect(parseRupiah('-25.000'), isNull);
      expect(parseRupiah('-25000'), isNull);
    });

    test('menerima nilai tepat di batas', () {
      expect(parseRupiah('999.999.999'), 999999999);
    });

    test('mengembalikan null bila melebihi batas', () {
      expect(parseRupiah('1.000.000.000'), isNull);
    });
  });

  group('formatJumlah', () {
    test('bilangan bulat tanpa desimal', () {
      expect(formatJumlah(1), '1');
      expect(formatJumlah(3), '3');
      expect(formatJumlah(12), '12');
    });

    test('pecahan memakai koma dan membuang nol di belakang', () {
      expect(formatJumlah(1.5), '1,5');
      expect(formatJumlah(0.5), '0,5');
      expect(formatJumlah(2.25), '2,25');
    });
  });
}
