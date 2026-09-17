/// Identitas toko yang dicetak di kepala struk.
class ProfilToko {
  final String namaToko;
  final String alamat;
  final String noHp;
  final String catatan;
  final String namaKasir;

  /// Lebar kertas dalam milimeter: 58 atau 80.
  final int lebarKertas;

  const ProfilToko({
    required this.namaToko,
    this.alamat = '',
    this.noHp = '',
    this.catatan = '',
    this.namaKasir = '',
    this.lebarKertas = 58,
  });

  /// Jumlah karakter per baris pada font printer standar (Font A).
  int get lebarKolom => lebarKertas == 80 ? 48 : 32;
}
