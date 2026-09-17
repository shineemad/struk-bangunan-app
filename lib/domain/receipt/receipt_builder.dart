import '../item_belanja.dart';
import '../profil_toko.dart';
import '../transaksi.dart';
import '../uang.dart';
import 'kolom.dart';
import 'receipt_document.dart';

/// Satu-satunya tempat yang memutuskan bentuk struk. Penyaji ESC/POS, PDF,
/// dan widget hanya menerjemahkan hasilnya.
ReceiptDocument bangunStruk({
  required ProfilToko profil,
  required Transaksi transaksi,
}) {
  final lebar = profil.lebarKolom;
  final baris = <BarisStruk>[];

  void tulis(String teks, {GayaBaris gaya = GayaBaris.biasa}) {
    baris.add(BarisStruk(teks, gaya: gaya));
  }

  // Pergantian baris yang diketik pengguna dihormati, lalu tiap barisnya
  // dibungkus bila masih melebihi lebar kertas.
  List<String> pecah(String teks) => [
    for (final satuBaris in teks.split('\n')) ...bungkusKata(satuBaris, lebar),
  ];

  // Kepala
  for (final b in pecah(profil.namaToko)) {
    tulis(rataTengah(b, lebar), gaya: GayaBaris.tebal);
  }
  if (profil.alamat.isNotEmpty) {
    for (final b in pecah(profil.alamat)) {
      tulis(rataTengah(b, lebar));
    }
  }
  if (profil.noHp.isNotEmpty) {
    for (final b in pecah('Telp/WA: ${profil.noHp}')) {
      tulis(rataTengah(b, lebar));
    }
  }
  tulis(garisPemisah(lebar), gaya: GayaBaris.pemisah);

  // Keterangan nota
  tulis('${'No. Nota'.padRight(9)}: #${transaksi.nomorNota}');
  tulis('${'Tanggal'.padRight(9)}: ${_tanggalJam(transaksi.waktu)}');
  if (profil.namaKasir.isNotEmpty) {
    tulis('${'Kasir'.padRight(9)}: ${profil.namaKasir}');
  }
  tulis(garisPemisah(lebar), gaya: GayaBaris.pemisah);

  // Daftar barang
  for (final item in transaksi.items) {
    for (final b in susunBarisItem(
      nama: _namaTampil(item),
      rincian: _rincian(item),
      nominal: formatRupiah(item.subtotal),
      lebar: lebar,
    )) {
      tulis(b);
    }
  }
  tulis(garisPemisah(lebar), gaya: GayaBaris.pemisah);

  // Blok nominal. Semua angka dirata-kanankan pada lebar yang sama agar
  // titik ribuannya sejajar.
  final nilai = <int>[
    transaksi.total,
    if (transaksi.bayar != null) transaksi.bayar!,
    if (transaksi.kembali != null) transaksi.kembali!,
  ];
  final lebarAngka = nilai
      .map((n) => formatRupiah(n).length)
      .reduce((a, b) => a > b ? a : b);
  String rupiah(int n) => 'Rp ${rataKanan(formatRupiah(n), lebarAngka)}';

  tulis(
    duaKolom('TOTAL', rupiah(transaksi.total), lebar),
    gaya: GayaBaris.tebal,
  );
  if (transaksi.bayar != null) {
    tulis(duaKolom('Bayar', rupiah(transaksi.bayar!), lebar));
    tulis(duaKolom('Kembali', rupiah(transaksi.kembali!), lebar));
  }
  tulis(garisPemisah(lebar), gaya: GayaBaris.pemisah);

  // Kaki
  tulis(rataTengah('*** TERIMA KASIH ***', lebar));
  if (profil.catatan.isNotEmpty) {
    for (final b in pecah(profil.catatan)) {
      tulis(rataTengah(b, lebar));
    }
  }

  return ReceiptDocument(lebar: lebar, baris: baris);
}

String _namaTampil(ItemBelanja item) {
  if (item.qty == 1 && item.satuan.isNotEmpty) {
    return '${item.nama} (1 ${item.satuan})';
  }
  return item.nama;
}

/// Kosong bila jumlahnya satu; satuannya sudah menempel di nama.
String _rincian(ItemBelanja item) {
  if (item.qty == 1) return '';
  return '${formatJumlah(item.qty)}x${formatRupiah(item.hargaSatuan)}';
}

String _duaDigit(int n) => n.toString().padLeft(2, '0');

String _tanggalJam(DateTime waktu) =>
    '${_duaDigit(waktu.day)}/${_duaDigit(waktu.month)}/${waktu.year} '
    '${_duaDigit(waktu.hour)}:${_duaDigit(waktu.minute)}';
