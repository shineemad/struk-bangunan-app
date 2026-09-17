/// Aturan tata letak teks struk. Murni string: berkas ini tidak tahu apa pun
/// tentang uang, barang, maupun printer.
library;

String garisPemisah(int lebar) => '-' * lebar;

String rataTengah(String teks, int lebar) {
  if (teks.length >= lebar) return teks.substring(0, lebar);
  return ' ' * ((lebar - teks.length) ~/ 2) + teks;
}

/// Bila teks lebih panjang dari lebar, sisi kiri yang dibuang agar digit
/// paling kanan (yang paling menentukan nilai) tetap terbaca.
String rataKanan(String teks, int lebar) {
  if (teks.length >= lebar) return teks.substring(teks.length - lebar);
  return ' ' * (lebar - teks.length) + teks;
}

String duaKolom(String kiri, String kanan, int lebar) {
  if (kanan.length >= lebar) return rataKanan(kanan, lebar);
  final ruangKiri = lebar - kanan.length - 1;
  final kiriPotong = kiri.length > ruangKiri
      ? kiri.substring(0, ruangKiri)
      : kiri;
  return kiriPotong + ' ' * (lebar - kiriPotong.length - kanan.length) + kanan;
}

/// Membungkus per kata secara rakus. Kata tunggal yang lebih panjang dari
/// [lebar] dipotong paksa; itu satu-satunya keadaan yang memenggal teks.
List<String> bungkusKata(String teks, int lebar) {
  final hasil = <String>[];
  var baris = '';

  for (final kata in teks.split(RegExp(r'\s+')).where((k) => k.isNotEmpty)) {
    var sisa = kata;
    while (sisa.length > lebar) {
      if (baris.isNotEmpty) {
        hasil.add(baris);
        baris = '';
      }
      hasil.add(sisa.substring(0, lebar));
      sisa = sisa.substring(lebar);
    }
    if (sisa.isEmpty) continue;

    if (baris.isEmpty) {
      baris = sisa;
    } else if (baris.length + 1 + sisa.length <= lebar) {
      baris = '$baris $sisa';
    } else {
      hasil.add(baris);
      baris = sisa;
    }
  }

  if (baris.isNotEmpty) hasil.add(baris);
  if (hasil.isEmpty) hasil.add('');
  return hasil;
}

/// Aturan C-adaptif: satu baris bila nama muat di sisa ruang, dua baris bila
/// tidak. Nama tidak pernah dipotong kecuali satu katanya melebihi [lebar].
List<String> susunBarisItem({
  required String nama,
  required String rincian,
  required String nominal,
  required int lebar,
}) {
  final kanan = rincian.isEmpty ? nominal : '$rincian  $nominal';
  final ruangNama = lebar - kanan.length - 1;

  if (ruangNama > 0 && nama.length <= ruangNama) {
    return [duaKolom(nama, kanan, lebar)];
  }
  return [...bungkusKata(nama, lebar), rataKanan(kanan, lebar)];
}
