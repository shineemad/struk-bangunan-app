import 'package:flutter/material.dart';

import '../domain/receipt/receipt_document.dart';

/// Menampilkan struk yang sudah jadi, apa adanya.
///
/// Widget yang sama dipakai untuk pratinjau di layar dan sebagai sumber
/// gambar PNG, sehingga struk di HP pembeli tidak mungkin berbeda dari yang
/// dilihat kasir. Ia tidak memformat apa pun: seluruh perataan sudah selesai
/// dihitung [ReceiptBuilder].
class ReceiptWidget extends StatelessWidget {
  final ReceiptDocument dokumen;
  final double ukuranFont;

  const ReceiptWidget({super.key, required this.dokumen, this.ukuranFont = 12});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.all(ukuranFont),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final baris in dokumen.baris)
            Text(
              baris.teks,
              softWrap: false,
              maxLines: 1,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: ukuranFont,
                height: 1.3,
                color: Colors.black,
                fontWeight: baris.gaya == GayaBaris.tebal
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
        ],
      ),
    );
  }
}
