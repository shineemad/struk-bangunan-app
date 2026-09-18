import 'package:flutter_test/flutter_test.dart';

import '../bantuan_basisdata.dart';

void main() {
  test('basis data dalam memori bisa dibuka dan ditulis', () async {
    final db = await bukaBasisdataUji();
    addTearDown(db.close);

    await db.execute('CREATE TABLE coba (nilai TEXT)');
    await db.insert('coba', {'nilai': 'halo'});
    final baris = await db.query('coba');

    expect(baris, hasLength(1));
    expect(baris.first['nilai'], 'halo');
  });

  test('tiap pemanggilan memberi basis data yang terpisah', () async {
    final a = await bukaBasisdataUji();
    final b = await bukaBasisdataUji();
    addTearDown(a.close);
    addTearDown(b.close);

    await a.execute('CREATE TABLE coba (nilai TEXT)');
    await a.insert('coba', {'nilai': 'hanya di a'});

    expect(() => b.query('coba'), throwsA(isA<Exception>()));
  });
}
