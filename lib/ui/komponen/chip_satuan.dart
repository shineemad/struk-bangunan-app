import 'package:flutter/material.dart';

import '../tema.dart';

const satuanBawaan = <String>[
  'sak',
  'kg',
  'batang',
  'lembar',
  'm',
  'rit',
  'pcs',
];

class ChipSatuan extends StatelessWidget {
  final String satuan;
  final bool terpilih;
  final VoidCallback onPilih;

  const ChipSatuan({
    super.key,
    required this.satuan,
    required this.terpilih,
    required this.onPilih,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: Ukuran.sentuh,
      child: Material(
        color: terpilih ? Warna.aksen : Warna.isian,
        borderRadius: BorderRadius.circular(Ukuran.radiusIsian),
        child: InkWell(
          onTap: onPilih,
          borderRadius: BorderRadius.circular(Ukuran.radiusIsian),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text(
                satuan,
                style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                  color: terpilih ? Colors.white : Warna.teks,
                  fontWeight: terpilih ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
