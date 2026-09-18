import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Mengubah apa pun yang berada di bawah [RepaintBoundary] bertanda
/// [kunciBoundary] menjadi byte PNG.
///
/// [pixelRatio] 3 menghasilkan gambar yang masih tajam saat pembeli
/// memperbesarnya di WhatsApp, tanpa membuat berkasnya besar.
///
/// Di dalam uji widget, pemanggilan ini **wajib** dibungkus
/// `tester.runAsync()`; tanpa itu ia menggantung.
Future<Uint8List> ambilPng(
  GlobalKey kunciBoundary, {
  double pixelRatio = 3,
}) async {
  final objek = kunciBoundary.currentContext?.findRenderObject();
  if (objek is! RenderRepaintBoundary) {
    throw StateError(
      'Kunci tidak menunjuk RepaintBoundary yang sedang tampil.',
    );
  }

  final gambar = await objek.toImage(pixelRatio: pixelRatio);
  try {
    final data = await gambar.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      throw StateError('Gambar struk gagal diubah menjadi PNG.');
    }
    return data.buffer.asUint8List();
  } finally {
    gambar.dispose();
  }
}
