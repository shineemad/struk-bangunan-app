import 'package:flutter/material.dart';

import '../komponen/tanda_notaku.dart';
import '../tema.dart';

/// Pembuka bermerek yang tampil sekali saat aplikasi dijalankan. Latarnya
/// sengaja sama dengan latar Beranda supaya pergantiannya tidak berkedip.
class LayarPembuka extends StatefulWidget {
  final VoidCallback onSelesai;

  const LayarPembuka({super.key, required this.onSelesai});

  @override
  State<LayarPembuka> createState() => _LayarPembukaState();
}

class _LayarPembukaState extends State<LayarPembuka>
    with SingleTickerProviderStateMixin {
  late final AnimationController _kendali = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  late final Animation<double> _tanda = CurvedAnimation(
    parent: _kendali,
    curve: const Interval(0, 0.31, curve: Curves.easeOut),
  );

  // Linear: lengkungnya sudah diterapkan di dalam TandaNotaku, dan menumpuk
  // dua easing membuat gerakan kertasnya tersendat di akhir.
  late final Animation<double> _kertas = CurvedAnimation(
    parent: _kendali,
    curve: const Interval(0.19, 0.69),
  );

  late final Animation<double> _kata = CurvedAnimation(
    parent: _kendali,
    curve: const Interval(0.56, 0.88, curve: Curves.easeOut),
  );

  bool _sudahMulai = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sudahMulai) return;
    _sudahMulai = true;

    // Pengguna yang mematikan animasi sistem biasanya melakukannya karena
    // pusing atau ingin cepat; menahan mereka 1,6 detik mengabaikan itu.
    if (MediaQuery.disableAnimationsOf(context)) {
      _kendali.value = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onSelesai();
      });
      return;
    }

    _kendali.forward().whenComplete(() {
      if (mounted) widget.onSelesai();
    });
  }

  @override
  void dispose() {
    _kendali.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;

    return Scaffold(
      body: Center(
        child: AnimatedBuilder(
          animation: _kendali,
          builder: (_, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Opacity(
                opacity: _tanda.value,
                child: Transform.scale(
                  scale: 0.85 + 0.15 * _tanda.value,
                  child: TandaNotaku(sisi: 104, kemajuan: _kertas.value),
                ),
              ),
              const SizedBox(height: 28),
              Opacity(
                opacity: _kata.value,
                child: Transform.translate(
                  offset: Offset(0, 8 * (1 - _kata.value)),
                  child: Column(
                    children: [
                      Text(
                        'Notaku',
                        style: teks.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Struk belanja untuk toko Anda',
                        style: teks.bodyMedium?.copyWith(
                          color: Warna.teksSekunder,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
