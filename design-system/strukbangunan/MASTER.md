# StrukBangunan — Design System (MASTER)

- **Tanggal:** 18 September 2026
- **Lingkup:** Seluruh `lib/ui/` dan `lib/state/` yang akan dibangun Rencana 4. Pratinjau struk (`lib/output/receipt_widget.dart`) **dikecualikan** — ia meniru kertas, bukan antarmuka.
- **Stack:** Flutter 3.38.5 / Material 3, Android saja.

## 1. Otoritas

Tiga sumber, berurutan. Yang di atas menang.

| Urutan | Sumber                                                          | Perannya                                      |
| ------ | --------------------------------------------------------------- | --------------------------------------------- |
| 1      | `docs/superpowers/specs/2026-09-17-strukbangunan-app-design.md` | Mengikat. Ukuran huruf, area sentuh, perilaku |
| 2      | Gambar referensi yang diberikan pemilik proyek (18 Sep 2026)    | Arah visual: bentuk, warna, kerapian          |
| 3      | Hasil pencarian `ui-ux-pro-max`                                 | Rekomendasi terverifikasi, bukan perintah     |

**Pengguna aplikasi ini berusia 50–70 tahun.** Setiap kali estetika bertabrakan dengan keterbacaan, keterbacaan menang. Dokumen ini menyebut setiap tabrakan itu secara terbuka di bagian 10.

## 2. Yang diambil dari gambar referensi — dan yang ditolak

**Diambil:**

- Kartu putih besar ber-sudut membulat di atas latar abu sangat terang
- Kolom isian dan panel sebagai blok abu lembut tanpa garis tepi tebal
- Satu warna aksen biru saja, dipakai hemat: tombol utama dan keadaan terpilih
- Tombol utama berbentuk pil selebar layar di bagian bawah
- Ikon garis (outline) monokrom, bukan ikon penuh warna
- Ruang kosong yang lapang; tidak ada gradien, tidak ada bayangan tebal

**Ditolak, beserta alasannya:**

| Dari gambar                                | Mengapa ditolak                                                                                                   |
| ------------------------------------------ | ----------------------------------------------------------------------------------------------------------------- |
| Teks abu terang (~`#94A3B8`)               | Terukur **2,56:1** terhadap putih — gagal ambang 4,5:1, dan pengguna lansia yang paling dulu kehilangan detailnya |
| Placeholder sebagai satu-satunya label     | Label hilang begitu diketik; spec bagian 5 menuntut label terlihat                                                |
| Tombol lingkaran berisi ikon saja          | Tidak terbaca tanpa tebakan. Setiap tindakan wajib punya teks                                                     |
| Kartu yang sengaja terpotong di tepi layar | Isyarat "geser" yang halus; pengguna lansia jarang menemukannya                                                   |
| Saklar (toggle) tanpa teks keadaan         | "Nyala/mati" harus terbaca sebagai kata, bukan hanya posisi                                                       |
| Ukuran huruf kecil pada keterangan         | Spec menetapkan lantai: isian 18pt, tombol utama 20pt                                                             |

## 3. Warna

Sumber: hasil pencarian `--domain color` ("Knowledge Base/Documentation": _neutral grey + link blue_) — paling dekat dengan gambar referensi. Setiap rasio di bawah **dihitung**, bukan ditaksir.

| Peran              | Token           | Nilai     | Kontras terukur                        |
| ------------------ | --------------- | --------- | -------------------------------------- |
| Latar layar        | `latar`         | `#F8FAFC` | —                                      |
| Permukaan kartu    | `permukaan`     | `#FFFFFF` | —                                      |
| Isian & panel      | `isian`         | `#EAEFF3` | —                                      |
| Garis tepi         | `garis`         | `#E2E8F0` | —                                      |
| Teks utama         | `teks`          | `#0F172A` | **17,85:1** di kartu, 17,06:1 di latar |
| Teks sekunder      | `teksSekunder`  | `#475569` | **7,58:1** di kartu, 6,55:1 di isian   |
| Aksen / tindakan   | `aksen`         | `#2563EB` | **5,17:1** terhadap putih              |
| Teks di atas aksen | `diAtasAksen`   | `#FFFFFF` | **5,17:1**                             |
| Merusak (hapus)    | `merusak`       | `#DC2626` | **4,83:1** terhadap putih              |
| Teks di atas merah | `diAtasMerusak` | `#FFFFFF` | **4,83:1**                             |

Aturan:

- **Satu aksen saja.** Biru dipakai untuk tombol utama, chip terpilih, dan tautan. Tidak untuk dekorasi.
- Merah **hanya** untuk menghapus dan membatalkan. Tidak pernah untuk penekanan biasa.
- Hijau dipakai sekali saja, pada tombol **+ TAMBAH KE DAFTAR**, karena spec bagian 5 memintanya: `#15803D` di atas putih (**5,02:1**). Verifikasi ulang bila nilainya diubah.
- **Tidak ada warna mentah di dalam widget.** Semua lewat `ColorScheme` dan ekstensi tema.
- Mode gelap **tidak dibangun di v1**. Bila kelak dibangun, seluruh pasangan di atas dihitung ulang — jangan membalik nilai begitu saja.

## 4. Tipografi

**Font: bawaan sistem (Roboto).** Aplikasi ini tidak punya izin `INTERNET`, sehingga paket `google_fonts` — yang mengunduh font saat dijalankan — **tidak bisa dipakai sama sekali**. Bila kelak ingin memakai Inter (rekomendasi `--domain typography`: pasangan _Minimal Swiss_, Inter/Inter), berkas `.ttf`-nya **wajib dibundel** ke dalam APK.

Struk memakai `fontFamily: 'monospace'` dan tidak mengikuti skala ini.

| Peran                | Ukuran | Tebal | Catatan                                     |
| -------------------- | ------ | ----- | ------------------------------------------- |
| Judul layar          | 24     | 700   |                                             |
| Judul bagian         | 20     | 600   |                                             |
| Teks tombol utama    | **20** | 700   | Lantai dari spec bagian 5                   |
| Isi & isian          | **18** | 400   | Lantai dari spec bagian 5                   |
| Label kolom          | 16     | 500   | Selalu di **luar** kolom, bukan placeholder |
| Keterangan           | 14     | 400   | Ambang bawah. Tidak ada teks di bawah 14    |
| Total di bilah bawah | 28     | 700   | Angka terpenting di seluruh aplikasi        |

- Tinggi baris 1,4 untuk isi; 1,2 untuk judul.
- **Wajib** `MediaQuery.textScalerOf(context)`; jangan pernah memakai `textScaleFactor` (usang) atau ukuran mati.
- Tata letak diuji pada skala font sistem **terbesar** — ini ada di checklist rilis spec bagian 8, dan pengguna lansia umumnya sudah memperbesarnya.
- Nominal rupiah tidak pernah dipotong. Bila sempit, turunkan baris, jangan kecilkan huruf.

## 5. Jarak, sudut, dan kedalaman

- Skala jarak kelipatan 4: **8 / 12 / 16 / 24 / 32**. Sisi layar 16.
- Jarak antar-target sentuh **minimal 8** (hasil `--domain ux`: _Touch Spacing_).
- Sudut membulat: kolom isian dan chip **16**, kartu **20**, lembar/dialog **28**, tombol pil **999**.
- Kedalaman **nyaris rata**: pemisahan dibuat oleh warna permukaan dan garis `#E2E8F0`.
  Bayangan hanya di satu tempat — bilah bawah yang menempel — agar daftar terlihat lewat di belakangnya.

## 6. Ikon

- **Material Symbols bawaan Flutter** (`uses-material-design: true`), gaya **outlined**. Sudah ikut di APK, tidak menambah dependensi, dan tidak butuh jaringan.
- Ukuran 28 (baris daftar) dan 32 (tindakan utama).
- **Tidak ada emoji sebagai ikon.**
- **Tidak ada tombol ikon tanpa teks** — kecuali tombol hapus pada baris item, yang wajib punya `Semantics(label: 'Hapus <nama barang>')`.

## 7. Komponen inti

| Komponen           | Tinggi | Aturan                                                                                    |
| ------------------ | ------ | ----------------------------------------------------------------------------------------- |
| Tombol utama       | 56     | Pil, selebar layar, teks 20/700 putih di atas `aksen`                                     |
| Tombol tambah item | 56     | Sama, tetapi hijau `#15803D` sesuai spec                                                  |
| Tombol sekunder    | 48     | Garis tepi `garis`, teks `teks`                                                           |
| Kolom isian        | 56     | Latar `isian`, label di luar, sudut 16, keyboard angka untuk jumlah dan harga             |
| Chip satuan        | 48     | Terpilih: latar `aksen` + teks putih. Tidak terpilih: latar `isian` + teks `teks`         |
| Tombol − dan +     | 56×56  | Mengapit kolom jumlah                                                                     |
| Baris item         | ≥ 72   | Nama + rincian di kiri, subtotal di kanan, tombol hapus 48×48 `merusak` di ujung          |
| Kartu favorit      | ≥ 48   | Gulir mendatar. **Kartu terakhir tidak boleh terpotong tepi layar** — beri jarak akhir 16 |
| Bilah total bawah  | 88     | Menempel; sembunyi saat keyboard terbuka, muncul lagi setelahnya                          |
| Navigasi bawah     | 72     | **Tiga** tujuan, ikon 28 **plus** label teks 14. Tidak pernah ikon saja                   |
| Banner pengingat   | —      | Latar `isian`, dua tombol teks, tidak memblokir                                           |
| Dialog konfirmasi  | —      | Judul 20/600, isi 18, tombol merusak di kanan                                             |

## 8. Gerak

Dial `--motion 2/10` (subtle). Aplikasi ini alat kerja, bukan pertunjukan.

- Perpindahan layar dan munculnya dialog: **200 ms**, `Curves.easeOut`.
- Umpan balik tekan: riak Material bawaan, jangan dimatikan. **Tidak ada perubahan keadaan 0 ms** — pengguna harus melihat bahwa tekanannya diterima.
- Item masuk daftar: fade + geser 12 px, **150 ms**. Tidak ada animasi berantai.
- Hormati `MediaQuery.disableAnimations`; jangan pernah menganimasikan `width`/`height`.

## 9. Aksesibilitas — tidak bisa ditawar

1. Area sentuh **minimal 48×48 dp** (Android; hasil `--domain ux`: _Touch Target Size_), jarak antar target ≥ 8.
2. Kontras teks ≥ **4,5:1**; setiap pasangan baru **dihitung**, bukan dikira.
3. Setiap kolom punya label yang tetap terlihat saat diisi.
4. Galat muncul **di bawah kolomnya**, bukan hanya di puncak layar, dengan kata sehari-hari tanpa kode galat.
5. Setiap tombol ikon punya `Semantics` berlabel.
6. Tata letak tidak pecah pada skala font sistem terbesar.
7. Tidak ada makna yang disampaikan **hanya** lewat warna — sertakan kata atau ikon.

## 10. Tabrakan yang sudah diputuskan

| Tabrakan                                                       | Putusan                                                                                                |
| -------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| Gambar referensi rapi dengan huruf kecil                       | Skala dinaikkan ke lantai spec (18/20). Tampilan jadi lebih "besar" daripada referensi — itu disengaja |
| Gambar memakai ikon tanpa label                                | Semua tindakan diberi teks; kerapiannya dikorbankan                                                    |
| Rekomendasi otomatis alat: palet rose + pola halaman pemasaran | **Ditolak.** Tidak cocok dengan gambar maupun jenis produk. Dipakai pencarian terarah sebagai gantinya |
| Rekomendasi font Inter lewat `google_fonts`                    | **Ditolak.** Paket itu mengunduh saat dijalankan, mustahil tanpa izin `INTERNET`                       |
| Mode gelap didukung gaya Minimalism                            | Ditunda ke setelah v1; tidak ada yang memintanya, dan setiap pasangan warna harus dihitung ulang       |

## 11. Checklist sebelum menyerahkan UI

- [ ] Tidak ada emoji sebagai ikon; semuanya Material Symbols outlined
- [ ] Tidak ada warna mentah di dalam widget — semua lewat tema
- [ ] Setiap target sentuh ≥ 48 dp, jarak ≥ 8
- [ ] Setiap pasangan teks/latar ≥ 4,5:1, dihitung
- [ ] Setiap kolom punya label terlihat + keyboard yang benar
- [ ] Dijalankan pada skala font sistem terbesar tanpa tata letak pecah
- [ ] Umpan balik tekan terlihat di setiap tindakan
- [ ] Bilah total sembunyi saat keyboard terbuka dan muncul kembali setelahnya
- [ ] Navigasi bawah tetap tiga tujuan dengan label
- [ ] Tidak ada tindakan merusak tanpa konfirmasi

## 12. Pemetaan ke layar Rencana 4

| Layar      | Komponen yang dipakai                                                           |
| ---------- | ------------------------------------------------------------------------------- |
| Onboarding | Kartu putih, kolom isian, tombol utama                                          |
| Kasir      | Kolom isian, chip satuan, − / +, kartu favorit, baris item, bilah total, banner |
| Pratinjau  | `ReceiptWidget` apa adanya + tiga tombol utama (Kirim WA, Simpan, nanti: Cetak) |
| Riwayat    | Kartu rekap, daftar nota, pratinjau yang sama                                   |
| Pengaturan | Kolom isian, saklar berlabel teks, tombol sekunder, dialog konfirmasi           |

Penyimpangan per layar ditulis di `design-system/strukbangunan/pages/<nama>.md`; berkas itu menimpa MASTER hanya untuk layar tersebut.
