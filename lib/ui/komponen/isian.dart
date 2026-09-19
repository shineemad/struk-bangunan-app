import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/uang.dart';
import '../tema.dart';

/// Memformat nominal menjadi `65.000` sambil diketik, dan menolak nominal di
/// atas batas pada saat pengetikan — bukan dengan pesan galat setelahnya.
class FormatterRupiah extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue lama,
    TextEditingValue baru,
  ) {
    final angka = baru.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (angka.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final nilai = int.tryParse(angka);
    if (nilai == null || nilai > maksRupiah) return lama;

    final teks = formatRupiah(nilai);
    return TextEditingValue(
      text: teks,
      selection: TextSelection.collapsed(offset: teks.length),
    );
  }
}

/// Membatasi kuantitas pada dua angka di belakang koma **saat dimasukkan**.
///
/// Spec bagian 4: tanpa batas ini, `0,333` tampil sebagai `0,33` sementara
/// subtotalnya dihitung dari `0,333`, dan pembeli berhak mempertanyakannya.
class FormatterJumlah extends TextInputFormatter {
  static final _sah = RegExp(r'^\d{0,6}(,\d{0,2})?$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue lama,
    TextEditingValue baru,
  ) => _sah.hasMatch(baru.text) ? baru : lama;
}

/// `1,5` menjadi `1.5`. Mengembalikan null bila isiannya belum sah.
double? bacaJumlah(String teks) => double.tryParse(teks.replaceAll(',', '.'));

class KolomIsian extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool angka;
  final bool autofocus;
  final List<TextInputFormatter>? formatters;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;

  const KolomIsian({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.angka = false,
    this.autofocus = false,
    this.formatters,
    this.onChanged,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label tetap terlihat setelah kolom terisi; placeholder saja akan
        // menghilang justru saat pengguna paling butuh tahu ini kolom apa.
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        SizedBox(
          height: Ukuran.isian,
          child: TextField(
            controller: controller,
            autofocus: autofocus,
            focusNode: focusNode,
            onChanged: onChanged,
            style: Theme.of(context).textTheme.bodyLarge,
            keyboardType: angka
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            inputFormatters: formatters,
            decoration: InputDecoration(hintText: hint),
          ),
        ),
      ],
    );
  }
}
