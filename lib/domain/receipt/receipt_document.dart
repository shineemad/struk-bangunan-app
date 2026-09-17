/// Penanda gaya cetak. ESC/POS memakainya untuk menebalkan huruf; widget
/// pratinjau dan PDF memakainya agar tampilannya sama.
enum GayaBaris { biasa, tebal, pemisah }

class BarisStruk {
  final String teks;
  final GayaBaris gaya;

  const BarisStruk(this.teks, {this.gaya = GayaBaris.biasa});
}

/// Struk yang sudah final: seluruh perataan sudah selesai dihitung. Penyaji
/// (ESC/POS, PDF, widget) hanya menerjemahkan, tidak boleh memformat ulang.
class ReceiptDocument {
  final int lebar;
  final List<BarisStruk> baris;

  ReceiptDocument({required this.lebar, required List<BarisStruk> baris})
    : baris = List.unmodifiable(baris);

  String get teksPolos => baris.map((b) => b.teks).join('\n');
}
