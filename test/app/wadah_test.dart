import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:struk_bangunan/app/wadah.dart';
import 'package:struk_bangunan/data/basisdata.dart';

import '../bantuan_basisdata.dart';

Future<Wadah> _siap() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  final db = await bukaBasisdataUji();
  await siapkanSkema(db);
  addTearDown(db.close);
  return Wadah(db, await SharedPreferences.getInstance());
}

void main() {
  test('menyiapkan favorit bawaan sekali saja', () async {
    final wadah = await _siap();

    await wadah.siapkan();
    final pertama = (await wadah.favorit.daftar()).length;
    await wadah.siapkan();

    expect(pertama, greaterThan(0));
    expect((await wadah.favorit.daftar()).length, pertama);
  });

  test('repository memakai basis data dan prefs yang sama', () async {
    final wadah = await _siap();
    await wadah.siapkan();

    await wadah.favorit.catatPemakaian('Semen', 'sak', DateTime(2026, 9, 18));
    final daftar = await wadah.favorit.daftar();

    expect(daftar.first.nama, 'Semen');
    expect(wadah.transaksi, isNotNull);
    expect(wadah.draf, isNotNull);
    expect(wadah.profil, isNotNull);
    expect(wadah.pengaturan, isNotNull);
  });
}
