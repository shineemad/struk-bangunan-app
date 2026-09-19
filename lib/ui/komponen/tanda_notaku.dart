import 'package:flutter/material.dart';

import '../tema.dart';

/// Tanda visual Notaku: selembar struk putih di atas persegi biru, dengan
/// proporsi yang sama persis dengan ikon peluncur (`tool/buat_ikon.py`).
///
/// [kemajuan] menggerakkan struk seolah keluar dari mesin cetak: 0 berarti
/// hanya persegi birunya, 1 berarti struk utuh dengan ketiga barisnya.
class TandaNotaku extends StatelessWidget {
  final double sisi;
  final double kemajuan;

  const TandaNotaku({super.key, this.sisi = 96, this.kemajuan = 1});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: sisi,
      child: CustomPaint(painter: _PelukisTanda(kemajuan)),
    );
  }
}

class _PelukisTanda extends CustomPainter {
  final double kemajuan;

  const _PelukisTanda(this.kemajuan);

  @override
  void paint(Canvas kanvas, Size ukuran) {
    final sisi = ukuran.shortestSide;
    final kuas = Paint()..color = Warna.aksen;
    kanvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & Size.square(sisi),
        Radius.circular(sisi * 0.22),
      ),
      kuas,
    );

    if (kemajuan <= 0) return;

    final p = sisi * 0.26;
    final kotak = Rect.fromLTRB(p, sisi * 0.22, sisi - p, sisi * 0.80);

    // Struk tersingkap dari atas ke bawah, bukan sekadar memudar: gerakannya
    // meniru kertas yang keluar dari printer, yang justru itulah produknya.
    final tersingkap = Curves.easeOut.transform(kemajuan.clamp(0.0, 1.0));
    kanvas.save();
    kanvas.clipRect(
      Rect.fromLTWH(
        kotak.left,
        kotak.top,
        kotak.width,
        kotak.height * tersingkap,
      ),
    );
    _gambarStruk(kanvas, kotak, Paint()..color = Colors.white);
    _gambarBaris(kanvas, kotak, kuas, tersingkap);
    kanvas.restore();
  }

  void _gambarStruk(Canvas kanvas, Rect kotak, Paint kuas) {
    final gerigi = kotak.height * 0.09;
    final badan = kotak.bottom - gerigi;
    kanvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(kotak.left, kotak.top, kotak.right, badan),
        Radius.circular(kotak.width * 0.06),
      ),
      kuas,
    );

    const gigi = 6;
    final langkah = kotak.width / gigi;
    final jalur = Path()..moveTo(kotak.left, badan);
    for (var i = 0; i < gigi; i++) {
      jalur.lineTo(kotak.left + langkah * (i + 0.5), kotak.bottom);
      jalur.lineTo(kotak.left + langkah * (i + 1), badan);
    }
    kanvas.drawPath(jalur..close(), kuas);
  }

  void _gambarBaris(Canvas kanvas, Rect kotak, Paint kuas, double tersingkap) {
    final tinggi = kotak.height * 0.91;
    final tebal = tinggi * 0.07;
    final kiri = kotak.left + kotak.width * 0.18;
    const rasio = [0.64, 0.64, 0.44];
    for (var i = 0; i < rasio.length; i++) {
      // Tiap baris punya jendelanya sendiri sehingga mereka muncul berurutan,
      // seperti teks yang dicetak baris demi baris.
      final mulai = 0.35 + i * 0.2;
      final maju = ((tersingkap - mulai) / 0.25).clamp(0.0, 1.0);
      if (maju <= 0) continue;
      final atas = kotak.top + tinggi * (0.30 + i * 0.20);
      kanvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(kiri, atas, kotak.width * rasio[i] * maju, tebal),
          Radius.circular(tebal / 2),
        ),
        kuas,
      );
    }
  }

  @override
  bool shouldRepaint(_PelukisTanda lama) => lama.kemajuan != kemajuan;
}
