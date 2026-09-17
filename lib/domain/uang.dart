/// Batas atas nilai uang yang boleh dimasukkan pengguna.
const int maksRupiah = 999999999;

/// 65000 -> "65.000".
String formatRupiah(int nilai) {
  final digit = nilai.abs().toString();
  final hasil = StringBuffer();
  for (var i = 0; i < digit.length; i++) {
    if (i > 0 && (digit.length - i) % 3 == 0) hasil.write('.');
    hasil.write(digit[i]);
  }
  return nilai < 0 ? '-$hasil' : hasil.toString();
}

/// "Rp 65.000" -> 65000. Null bila tidak ada digit, bertanda minus, atau
/// melebihi [maksRupiah].
int? parseRupiah(String teks) {
  if (teks.contains('-')) return null;
  final digit = teks.replaceAll(RegExp(r'[^0-9]'), '');
  if (digit.isEmpty) return null;
  final nilai = int.tryParse(digit);
  if (nilai == null || nilai > maksRupiah) return null;
  return nilai;
}

/// 3.0 -> "3", 1.5 -> "1,5". Maksimal dua angka di belakang koma.
String formatJumlah(double qty) {
  if (qty == qty.roundToDouble()) return qty.round().toString();
  final teks = qty
      .toStringAsFixed(2)
      .replaceAll(RegExp(r'0+$'), '')
      .replaceAll(RegExp(r'\.$'), '');
  return teks.replaceAll('.', ',');
}
