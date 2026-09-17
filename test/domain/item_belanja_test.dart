import 'package:flutter_test/flutter_test.dart';
import 'package:struk_bangunan/domain/item_belanja.dart';

void main() {
  test('subtotal adalah qty dikali harga satuan', () {
    final item = ItemBelanja(
      nama: 'Semen Tiga Roda',
      qty: 3,
      satuan: 'sak',
      hargaSatuan: 65000,
    );
    expect(item.subtotal, 195000);
  });

  test('qty pecahan dibulatkan ke rupiah terdekat', () {
    final item = ItemBelanja(
      nama: 'Pasir',
      qty: 1.5,
      satuan: 'rit',
      hargaSatuan: 850000,
    );
    expect(item.subtotal, 1275000);

    final ganjil = ItemBelanja(
      nama: 'Cat',
      qty: 0.333,
      satuan: 'kaleng',
      hargaSatuan: 1000,
    );
    expect(ganjil.subtotal, 333);
  });

  test('harga nol diizinkan untuk barang bonus', () {
    final item = ItemBelanja(
      nama: 'Kawat Ikat',
      qty: 1,
      satuan: 'kg',
      hargaSatuan: 0,
    );
    expect(item.subtotal, 0);
  });

  test('nama dirapikan dari spasi berlebih', () {
    final item = ItemBelanja(
      nama: '  Paku 7cm  ',
      qty: 2,
      satuan: ' kg ',
      hargaSatuan: 20000,
    );
    expect(item.nama, 'Paku 7cm');
    expect(item.satuan, 'kg');
  });

  test('menolak nama kosong', () {
    expect(
      () => ItemBelanja(nama: '   ', qty: 1, satuan: 'pcs', hargaSatuan: 1000),
      throwsArgumentError,
    );
  });

  test('menolak qty nol atau negatif', () {
    expect(
      () => ItemBelanja(nama: 'Semen', qty: 0, satuan: 'sak', hargaSatuan: 1000),
      throwsArgumentError,
    );
    expect(
      () => ItemBelanja(nama: 'Semen', qty: -1, satuan: 'sak', hargaSatuan: 1000),
      throwsArgumentError,
    );
  });

  test('menolak harga negatif atau di atas batas', () {
    expect(
      () => ItemBelanja(nama: 'Semen', qty: 1, satuan: 'sak', hargaSatuan: -1),
      throwsArgumentError,
    );
    expect(
      () => ItemBelanja(
        nama: 'Semen',
        qty: 1,
        satuan: 'sak',
        hargaSatuan: 1000000000,
      ),
      throwsArgumentError,
    );
  });
}
