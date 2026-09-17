import 'package:flutter_test/flutter_test.dart';
import 'package:struk_bangunan/domain/receipt/kolom.dart';

void main() {
  group('garisPemisah', () {
    test('panjangnya persis selebar kertas', () {
      expect(garisPemisah(32).length, 32);
      expect(garisPemisah(32), '-' * 32);
      expect(garisPemisah(48).length, 48);
    });
  });

  group('rataTengah', () {
    test('menempatkan teks di tengah dengan pembulatan ke bawah', () {
      expect(rataTengah('TB. SINAR BANGUNAN', 32), '       TB. SINAR BANGUNAN');
      expect(
        rataTengah('*** TERIMA KASIH ***', 32),
        '      *** TERIMA KASIH ***',
      );
      expect(
        rataTengah('tidak dapat dikembalikan.', 32),
        '   tidak dapat dikembalikan.',
      );
    });

    test('memotong teks yang lebih panjang dari lebar', () {
      expect(rataTengah('A' * 40, 32).length, 32);
    });
  });

  group('rataKanan', () {
    test('mengisi spasi di kiri hingga penuh', () {
      expect(rataKanan('195.000', 32).length, 32);
      expect(rataKanan('195.000', 32).endsWith('195.000'), isTrue);
      expect(rataKanan('175.000', 9), '  175.000');
    });

    test('mempertahankan digit paling kanan bila terlalu panjang', () {
      expect(rataKanan('1.234.567', 5), '4.567');
    });
  });

  group('duaKolom', () {
    test('kiri menempel kiri, kanan menempel kanan, total selebar kertas', () {
      final baris = duaKolom('TOTAL', 'Rp 1.825.000', 32);
      expect(baris, 'TOTAL               Rp 1.825.000');
      expect(baris.length, 32);
    });

    test('memotong sisi kiri bila ruangnya tidak cukup', () {
      final baris = duaKolom('A' * 40, 'Rp 1.000', 32);
      expect(baris.length, 32);
      expect(baris.endsWith('Rp 1.000'), isTrue);
    });
  });

  group('bungkusKata', () {
    test('membungkus secara rakus pada batas lebar', () {
      expect(bungkusKata('Keramik Granit Roman 60x60 Putih Doff', 32), [
        'Keramik Granit Roman 60x60 Putih',
        'Doff',
      ]);
    });

    test('teks yang muat tetap satu baris', () {
      expect(bungkusKata('Semen Tiga Roda', 32), ['Semen Tiga Roda']);
    });

    test('kata tunggal lebih panjang dari lebar dipotong paksa', () {
      final hasil = bungkusKata('A' * 40, 32);
      expect(hasil, ['A' * 32, 'A' * 8]);
    });

    test('teks kosong menghasilkan satu baris kosong', () {
      expect(bungkusKata('', 32), ['']);
    });
  });

  group('susunBarisItem', () {
    test('nama pendek dengan jumlah lebih dari satu muat satu baris', () {
      expect(
        susunBarisItem(
          nama: 'Paku 7cm',
          rincian: '2x20.000',
          nominal: '40.000',
          lebar: 32,
        ),
        ['Paku 7cm        2x20.000  40.000'],
      );
    });

    test('jumlah satu menghilangkan rincian sehingga muat satu baris', () {
      expect(
        susunBarisItem(
          nama: 'Pasir (1 rit)',
          rincian: '',
          nominal: '850.000',
          lebar: 32,
        ),
        ['Pasir (1 rit)            850.000'],
      );
    });

    test('nama yang tidak muat jatuh ke dua baris tanpa dipotong', () {
      expect(
        susunBarisItem(
          nama: 'Semen Tiga Roda',
          rincian: '3x65.000',
          nominal: '195.000',
          lebar: 32,
        ),
        ['Semen Tiga Roda', '               3x65.000  195.000'],
      );
    });

    test('nama sangat panjang dibungkus lalu angka rata kanan', () {
      expect(
        susunBarisItem(
          nama: 'Keramik Granit Roman 60x60 Putih Doff',
          rincian: '4x185.000',
          nominal: '740.000',
          lebar: 32,
        ),
        [
          'Keramik Granit Roman 60x60 Putih',
          'Doff',
          '              4x185.000  740.000',
        ],
      );
    });

    test('nominal besar dengan jumlah dua digit tidak menjebol lebar', () {
      final baris = susunBarisItem(
        nama: 'Besi Beton 12mm',
        rincian: '12x1.250.000',
        nominal: '15.000.000',
        lebar: 32,
      );
      for (final b in baris) {
        expect(b.length, lessThanOrEqualTo(32));
      }
      expect(baris.last.endsWith('15.000.000'), isTrue);
    });

    test('kertas 80mm memakai 48 kolom', () {
      final baris = susunBarisItem(
        nama: 'Semen Tiga Roda',
        rincian: '3x65.000',
        nominal: '195.000',
        lebar: 48,
      );
      expect(baris.length, 1);
      expect(baris.single.length, 48);
    });
  });

  group('invarian lebar', () {
    test('tidak ada baris yang melebihi lebar kertas', () {
      const namaUji = [
        'Semen',
        'Semen Tiga Roda',
        'Keramik Granit Roman 60x60 Putih Doff',
        'Cat Tembok Avitex 25kg Warna Putih Tulang Sangat Panjang Sekali',
        'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
      ];
      const rincianUji = ['', '3x65.000', '12x1.250.000', '100x999.999.999'];
      const nominalUji = ['0', '40.000', '15.000.000', '999.999.999'];

      for (final lebar in [32, 48]) {
        for (final nama in namaUji) {
          for (final rincian in rincianUji) {
            for (final nominal in nominalUji) {
              final baris = susunBarisItem(
                nama: nama,
                rincian: rincian,
                nominal: nominal,
                lebar: lebar,
              );
              for (final b in baris) {
                expect(
                  b.length,
                  lessThanOrEqualTo(lebar),
                  reason:
                      'nama=$nama rincian=$rincian nominal=$nominal '
                      'lebar=$lebar baris="$b"',
                );
              }
            }
          }
        }
      }
    });
  });
}
