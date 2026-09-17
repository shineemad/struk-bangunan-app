import 'package:flutter_test/flutter_test.dart';
import 'package:struk_bangunan/domain/item_belanja.dart';
import 'package:struk_bangunan/domain/transaksi.dart';

ItemBelanja _item(String nama, double qty, int harga) =>
    ItemBelanja(nama: nama, qty: qty, satuan: 'pcs', hargaSatuan: harga);

void main() {
  test('total adalah jumlah seluruh subtotal', () {
    final transaksi = Transaksi(
      nomorNota: '0142',
      waktu: DateTime(2026, 9, 17, 14, 30),
      items: [_item('Semen', 3, 65000), _item('Paku', 2, 20000)],
    );
    expect(transaksi.total, 235000);
  });

  test('total nol bila tidak ada item', () {
    final transaksi = Transaksi(
      nomorNota: '0001',
      waktu: DateTime(2026, 9, 17),
      items: const [],
    );
    expect(transaksi.total, 0);
  });

  test('kembali null bila kasir tidak mengisi uang bayar', () {
    final transaksi = Transaksi(
      nomorNota: '0142',
      waktu: DateTime(2026, 9, 17),
      items: [_item('Semen', 1, 65000)],
    );
    expect(transaksi.kembali, isNull);
  });

  test('kembali adalah bayar dikurangi total', () {
    final transaksi = Transaksi(
      nomorNota: '0142',
      waktu: DateTime(2026, 9, 17),
      items: [_item('Semen', 1, 65000)],
      bayar: 100000,
    );
    expect(transaksi.kembali, 35000);
  });

  test('kembali negatif bila uang bayar kurang', () {
    final transaksi = Transaksi(
      nomorNota: '0142',
      waktu: DateTime(2026, 9, 17),
      items: [_item('Semen', 1, 65000)],
      bayar: 50000,
    );
    expect(transaksi.kembali, -15000);
  });

  test('daftar item tidak bisa diubah dari luar', () {
    final transaksi = Transaksi(
      nomorNota: '0142',
      waktu: DateTime(2026, 9, 17),
      items: [_item('Semen', 1, 65000)],
    );
    expect(
      () => transaksi.items.add(_item('Paku', 1, 20000)),
      throwsUnsupportedError,
    );
  });
}
