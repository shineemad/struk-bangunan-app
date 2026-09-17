import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:struk_bangunan/data/draf_repository.dart';
import 'package:struk_bangunan/domain/item_belanja.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  test('draf kosong bila belum pernah disimpan', () async {
    final repo = DrafRepository(await SharedPreferences.getInstance());
    expect(await repo.muat(), isEmpty);
  });

  test('menyimpan lalu memulihkan keranjang beserta subtotalnya', () async {
    final repo = DrafRepository(await SharedPreferences.getInstance());
    final items = [
      ItemBelanja(
        nama: 'Semen Tiga Roda',
        qty: 3,
        satuan: 'sak',
        hargaSatuan: 65000,
      ),
      ItemBelanja(nama: 'Pasir', qty: 1.5, satuan: 'rit', hargaSatuan: 850000),
    ];

    await repo.simpan(items);
    final hasil = await repo.muat();

    expect(hasil, hasLength(2));
    expect(hasil[0].nama, 'Semen Tiga Roda');
    expect(hasil[0].qty, 3);
    expect(hasil[0].subtotal, 195000);
    expect(hasil[1].qty, 1.5);
    expect(hasil[1].subtotal, 1275000);
  });

  test('hapus mengosongkan draf', () async {
    final repo = DrafRepository(await SharedPreferences.getInstance());
    await repo.simpan([
      ItemBelanja(nama: 'Semen', qty: 1, satuan: 'sak', hargaSatuan: 65000),
    ]);
    await repo.hapus();

    expect(await repo.muat(), isEmpty);
  });

  test('draf yang rusak diperlakukan sebagai kosong, bukan melempar', () async {
    SharedPreferences.setMockInitialValues({'draf_keranjang': 'bukan json'});
    final repo = DrafRepository(await SharedPreferences.getInstance());

    expect(await repo.muat(), isEmpty);
  });

  test('baris yang cacat dilewati, bukan menggagalkan seluruh draf', () async {
    // Simulasi draf dengan baris malformed (harga_satuan berupa string)
    // dan baris well-formed yang harus tetap dimuat.
    SharedPreferences.setMockInitialValues({
      'draf_keranjang': '''
[
  {
    "nama": 123,
    "qty": 1,
    "satuan": "sak",
    "harga_satuan": 65000
  },
  {
    "nama": "Semen Baik",
    "qty": 2,
    "satuan": "sak",
    "harga_satuan": 75000
  }
]
      ''',
    });
    final repo = DrafRepository(await SharedPreferences.getInstance());

    final hasil = await repo.muat();

    expect(hasil, hasLength(1));
    expect(hasil[0].nama, 'Semen Baik');
    expect(hasil[0].qty, 2);
    expect(hasil[0].subtotal, 150000);
  });
}
