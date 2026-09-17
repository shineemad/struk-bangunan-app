import 'package:flutter_test/flutter_test.dart';
import 'package:struk_bangunan/domain/item_belanja.dart';
import 'package:struk_bangunan/domain/profil_toko.dart';
import 'package:struk_bangunan/domain/receipt/receipt_builder.dart';
import 'package:struk_bangunan/domain/receipt/receipt_document.dart';
import 'package:struk_bangunan/domain/transaksi.dart';

const _profil = ProfilToko(
  namaToko: 'TB. SINAR BANGUNAN',
  alamat: 'Jl. Raya Merdeka No. 45',
  noHp: '0812-3456-7890',
  namaKasir: 'Admin',
  catatan: 'Barang yang sudah dibeli\ntidak dapat dikembalikan.',
);

Transaksi _transaksiContoh() => Transaksi(
  nomorNota: '0142',
  waktu: DateTime(2026, 9, 17, 14, 30),
  bayar: 2000000,
  items: [
    ItemBelanja(
      nama: 'Semen Tiga Roda',
      qty: 3,
      satuan: 'sak',
      hargaSatuan: 65000,
    ),
    ItemBelanja(nama: 'Pasir', qty: 1, satuan: 'rit', hargaSatuan: 850000),
    ItemBelanja(nama: 'Paku 7cm', qty: 2, satuan: 'kg', hargaSatuan: 20000),
    ItemBelanja(
      nama: 'Keramik Granit Roman 60x60 Putih Doff',
      qty: 4,
      satuan: 'dus',
      hargaSatuan: 185000,
    ),
  ],
);

void main() {
  test('menghasilkan struk yang sama persis dengan contoh di spec', () {
    final dokumen = bangunStruk(profil: _profil, transaksi: _transaksiContoh());

    const diharapkan = '''
       TB. SINAR BANGUNAN
    Jl. Raya Merdeka No. 45
    Telp/WA: 0812-3456-7890
--------------------------------
No. Nota : #0142
Tanggal  : 17/09/2026 14:30
Kasir    : Admin
--------------------------------
Semen Tiga Roda
               3x65.000  195.000
Pasir (1 rit)            850.000
Paku 7cm        2x20.000  40.000
Keramik Granit Roman 60x60 Putih
Doff
              4x185.000  740.000
--------------------------------
TOTAL               Rp 1.825.000
Bayar               Rp 2.000.000
Kembali             Rp   175.000
--------------------------------
      *** TERIMA KASIH ***
    Barang yang sudah dibeli
   tidak dapat dikembalikan.''';

    expect(dokumen.teksPolos, diharapkan);
  });

  test('tidak ada baris yang melebihi lebar kertas', () {
    final dokumen = bangunStruk(profil: _profil, transaksi: _transaksiContoh());
    for (final baris in dokumen.baris) {
      expect(baris.teks.length, lessThanOrEqualTo(dokumen.lebar));
    }
  });

  test('baris Bayar dan Kembali tidak dicetak bila kasir tidak mengisinya', () {
    final dokumen = bangunStruk(
      profil: _profil,
      transaksi: Transaksi(
        nomorNota: '0143',
        waktu: DateTime(2026, 9, 17, 15, 0),
        items: [
          ItemBelanja(
            nama: 'Semen Tiga Roda',
            qty: 1,
            satuan: 'sak',
            hargaSatuan: 65000,
          ),
        ],
      ),
    );
    expect(dokumen.teksPolos, contains('TOTAL'));
    expect(dokumen.teksPolos, isNot(contains('Bayar')));
    expect(dokumen.teksPolos, isNot(contains('Kembali')));
  });

  test('kolom profil yang kosong tidak menyisakan baris kosong', () {
    final dokumen = bangunStruk(
      profil: const ProfilToko(namaToko: 'TB. MAJU JAYA'),
      transaksi: Transaksi(
        nomorNota: '0001',
        waktu: DateTime(2026, 9, 17, 8, 5),
        items: [
          ItemBelanja(nama: 'Semen', qty: 1, satuan: 'sak', hargaSatuan: 65000),
        ],
      ),
    );
    expect(dokumen.teksPolos, isNot(contains('Telp/WA')));
    expect(dokumen.teksPolos, isNot(contains('Kasir')));
    expect(dokumen.teksPolos, contains('*** TERIMA KASIH ***'));
    for (final baris in dokumen.baris) {
      expect(baris.teks.trim(), isNotEmpty);
    }
  });

  test('baris TOTAL dan nama toko ditandai tebal', () {
    final dokumen = bangunStruk(profil: _profil, transaksi: _transaksiContoh());
    final tebal = dokumen.baris
        .where((b) => b.gaya == GayaBaris.tebal)
        .map((b) => b.teks.trim())
        .toList();
    expect(tebal, contains('TB. SINAR BANGUNAN'));
    expect(tebal.any((t) => t.startsWith('TOTAL')), isTrue);
  });

  test('kertas 80mm menghasilkan baris selebar 48 kolom', () {
    final dokumen = bangunStruk(
      profil: const ProfilToko(
        namaToko: 'TB. SINAR BANGUNAN',
        lebarKertas: 80,
      ),
      transaksi: _transaksiContoh(),
    );
    expect(dokumen.lebar, 48);
    expect(
      dokumen.baris.firstWhere((b) => b.gaya == GayaBaris.pemisah).teks.length,
      48,
    );
  });
}
