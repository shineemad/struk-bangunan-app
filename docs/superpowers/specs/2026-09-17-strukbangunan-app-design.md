# Desain StrukBangunan App

- **Tanggal:** 17 September 2026
- **Status:** Disetujui, siap masuk tahap perencanaan implementasi
- **Sumber:** `PRD_Aplikasi_Struk_Toko_Bangunan.pdf` (PRD v1.0) + sesi brainstorming 17 Sep 2026
- **Platform:** Android saja
- **Model distribusi:** Gratis, offline-first, disebar ke banyak toko

---

## 1. Ringkasan

Aplikasi kasir sederhana untuk pemilik toko bahan bangunan berusia 50–70 tahun. Pengguna mengetik nama bahan, jumlah, dan harga, lalu mencetak struk ke printer Bluetooth thermal 58mm atau mengirimkannya sebagai gambar lewat WhatsApp. Seluruh data tersimpan di HP; tidak ada server, tidak ada akun, tidak ada koneksi internet.

Prinsip dari PRD dipertahankan: **"Minimal Input, Maximum Output."**

### Keputusan pokok

| Keputusan | Pilihan | Alasan |
|---|---|---|
| Platform | Android saja | Printer thermal murah memakai Bluetooth Classic SPP yang tertutup di iOS. Menjanjikan iOS berarti menjanjikan fitur yang mati |
| Lingkup v1 | PRD + qty + riwayat + favorit + backup | KPI 45 detik tidak tercapai tanpa favorit; aplikasi tanpa riwayat terasa seperti kalkulator sekali pakai |
| Isi daftar favorit | Preset bawaan + belajar dari riwayat | Manfaat terasa sejak hari pertama, lalu menyesuaikan diri dengan barang toko tersebut |
| Harga di favorit | **Tidak disimpan** | Harga bahan bangunan berubah mingguan; harga basi yang terpakai diam-diam bisa membuat toko rugi |
| Format kiriman WhatsApp | PNG utama, PDF opsional | PNG tampil langsung di dalam chat tanpa perlu diunduh |
| Tata letak layar utama | Satu layar penuh | Tidak ada perpindahan layar, pengguna tidak bisa tersesat |
| Format baris item struk | C-adaptif | Satu baris bila muat, dua baris bila nama panjang. Nama tidak pernah dipotong |
| Arsitektur keluaran | Satu model struk, tiga penyaji | Aturan pemformatan hidup di satu tempat dan bisa diuji tanpa perangkat keras |
| Satuan nilai uang | `int` rupiah penuh | `double` menghasilkan galat pembulatan yang tidak bisa dijelaskan ke pembeli |

---

## 2. Lingkup v1

### Termasuk

| ID | Fitur | Keterangan |
|---|---|---|
| FT-01 | Pengaturan toko | Nama, alamat, no. WA, pesan penutup, nama kasir, lebar kertas |
| FT-02 | Input transaksi cepat | Nama bahan, jumlah, satuan, harga satuan |
| FT-03 | Kalkulasi otomatis | Subtotal per item, total, uang bayar, kembalian |
| FT-04 | Pratinjau struk | Tampilan identik dengan hasil cetak |
| FT-05 | Cetak Bluetooth thermal | ESC/POS langsung, 58mm dan 80mm |
| FT-06 | Bagikan via WhatsApp | PNG utama, PDF opsional, lewat share sheet |
| FT-07 | Kuantitas & satuan | Jumlah pecahan diperbolehkan |
| FT-08 | Bahan favorit | Preset bawaan, urutan mengikuti frekuensi pakai |
| FT-09 | Riwayat transaksi | Daftar nota, rekap harian, cetak & kirim ulang |
| FT-10 | Nomor nota otomatis | Berurutan, ikut terbawa saat backup |
| FT-11 | Cadangkan & pulihkan | Satu file JSON lewat share sheet |
| FT-12 | Pengingat backup | Banner setelah 30 hari tanpa backup |

### Sengaja tidak termasuk

Kasbon/hutang pelanggan, diskon, multi-harga eceran–grosir, manajemen stok, kategori barang, laporan Excel, multi-kasir, sinkronisasi awan, akun pengguna, iOS. Semuanya ditahan sampai ada pengguna nyata yang memintanya.

---

## 3. Arsitektur

Empat lapis dengan arah ketergantungan satu arah.

```
ui/  ->  state/  ->  data/  ->  domain/
                 ->  output/ ->  domain/
```

`domain/` tidak mengimpor Flutter, sqflite, maupun plugin apa pun. Seluruh aturan struk karenanya bisa diuji dengan `dart test` tanpa emulator dan tanpa printer.

```
lib/
  domain/                      # Dart murni, nol dependensi eksternal
    profil_toko.dart
    item_belanja.dart
    transaksi.dart
    uang.dart                  # format & parse rupiah
    receipt/
      receipt_document.dart    # struk final, sudah berupa baris-baris teks
      receipt_builder.dart     # Transaksi + ProfilToko -> ReceiptDocument
      kolom.dart               # aturan C-adaptif, perataan lebar kertas
  data/
    profil_repository.dart     # shared_preferences
    database.dart              # skema sqflite + migrasi
    transaksi_repository.dart
    favorit_repository.dart
    draft_repository.dart      # keranjang berjalan
    backup_service.dart
  output/
    esc_pos_renderer.dart      # ReceiptDocument -> List<int>
    pdf_renderer.dart          # ReceiptDocument -> PDF
    receipt_widget.dart        # ReceiptDocument -> widget (pratinjau & PNG)
    printer_service.dart       # pindai, sambung, kirim, ingat printer terakhir
    share_service.dart
  state/
    keranjang_controller.dart
    profil_controller.dart
    favorit_controller.dart
    riwayat_controller.dart
  ui/
    kasir/  struk/  riwayat/  pengaturan/  onboarding/  common/
```

### Kontrak antar modul

- `ReceiptBuilder` adalah **satu-satunya** komponen yang boleh memutuskan bentuk struk. Ketiga penyaji di `output/` hanya menerima `ReceiptDocument` yang sudah jadi dan tidak boleh mengetahui aturan pembulatan, pemotongan nama, atau lebar kertas.
- `esc_pos_renderer.dart` menentukan **apa** yang dicetak; `printer_service.dart` menentukan **bagaimana** sampai ke printer. Pemisahan ini membuat isi struk bisa diuji tanpa menyalakan Bluetooth.
- Repository mengembalikan objek `domain/`, bukan `Map` mentah dari database.

---

## 4. Model data & penyimpanan

Seluruh data berada di dalam sandbox aplikasi pada HP. Aplikasi **tidak mencantumkan izin `INTERNET`** di `AndroidManifest.xml`, sehingga klaim offline 100% terjamin secara teknis.

### Nilai uang

Semua nilai uang disimpan sebagai `int` rupiah penuh. Kuantitas memakai `double` karena "1,5 rit pasir" itu nyata. Subtotal dibulatkan ke rupiah terdekat **sekali saja**, saat item dibuat, lalu disimpan.

### Profil toko — `shared_preferences`

`nama_toko`, `alamat_toko`, `nohp_toko`, `catatan_toko`, `nama_kasir`, `lebar_kertas` (58 atau 80), `format_kiriman` (`gambar` atau `pdf`, bawaan `gambar`), `printer_terakhir_mac`, `printer_terakhir_nama`, `draf_keranjang` (JSON keranjang berjalan), `backup_terakhir_ms`, `backup_ditunda_sampai_ms`.

### Basis data — `sqflite` (`strukbangunan.db`)

| Tabel | Kolom |
|---|---|
| `transaksi` | `id`, `nomor_nota`, `waktu_ms`, `total`, `bayar` (nullable), `kembali` (nullable) |
| `item` | `id`, `transaksi_id`, `nama`, `qty`, `satuan`, `harga_satuan`, `subtotal`, `urutan` |
| `favorit` | `id`, `nama` (unik, `COLLATE NOCASE`), `satuan_terakhir`, `jumlah_pakai`, `terakhir_dipakai_ms`, `bawaan`, `disembunyikan` |
| `meta` | `kunci`, `nilai` |

`item.subtotal` disimpan dan tidak pernah dihitung ulang saat menampilkan. Nota lama yang dicetak ulang harus keluar persis seperti aslinya.

`meta` menyimpan `nomor_nota_berikutnya` dan `versi_skema`. Nomor nota disimpan di database, bukan di `shared_preferences`, supaya ikut terbawa saat backup — nomor yang mengulang dari 1 setelah ganti HP akan mengacaukan klaim pembeli.

### Favorit

Sesudah transaksi tersimpan, `jumlah_pakai` untuk setiap nama bahan naik satu. Nama yang belum terdaftar otomatis ditambahkan. Urutan tampil: `jumlah_pakai` menurun, lalu `terakhir_dipakai_ms` menurun. Preset bawaan yang tidak pernah dipakai tenggelam sendiri. Tabel ini tidak punya kolom harga.

### Cadangkan & pulihkan

Backup menghasilkan satu berkas `strukbangunan-backup-YYYYMMDD.json` berisi profil, favorit, seluruh transaksi beserta itemnya, dan nilai `meta`. Berkas dikeluarkan lewat share sheet agar pengguna menyimpannya sendiri.

Pulihkan **menimpa seluruh data**, tidak menggabungkan — penggabungan bisa menghasilkan nomor nota ganda. Urutannya ketat: baca berkas → validasi versi dan tipe setiap kolom → baru hapus dan tulis ulang. Data lama tidak disentuh sebelum validasi lolos. Ukuran berkas dibatasi dan setiap nilai diperiksa tipenya, karena berkas berasal dari luar aplikasi dan bisa rusak atau bukan berkas kita. Konfirmasi berupa peringatan tegas bahwa seluruh data sekarang akan diganti.

Isi backup murni data toko sendiri — tidak ada kata sandi atau token — sehingga aman dikirim lewat WhatsApp.

### Berkas sementara

PNG dan PDF struk ditulis ke direktori cache, dibagikan lewat share sheet, lalu dibersihkan. Tidak disimpan ke galeri, agar galeri pengguna tidak dipenuhi ratusan gambar struk.

---

## 5. Alur layar & perilaku UI

### Navigasi

Bottom navigation tiga tujuan dengan ikon besar dan label teks: **Kasir**, **Riwayat**, **Pengaturan**. Kasir selalu menjadi layar pembuka. Tidak ada drawer dan tidak ada menu titik tiga.

### Aksesibilitas

Font isian minimal 18pt, teks tombol utama minimal 20pt, area sentuh minimal 48×48 dp. Warna tindakan positif hijau/biru, tindakan merusak merah, dengan kontras tinggi. Kolom harga dan jumlah memicu keyboard angka.

### Onboarding

Satu layar, muncul sekali. **Nama toko wajib**; alamat, nomor WA, dan pesan penutup boleh dilewati dan diisi belakangan lewat Pengaturan.

### Layar Kasir

- **Bagian atas (tetap):** kolom nama bahan; baris jumlah + satuan + harga satuan; tombol hijau **+ TAMBAH KE DAFTAR**. Semua isian berada di sepertiga atas layar sehingga tidak pernah tertutup keyboard.
- **Bagian tengah (bergulir):** baris favorit yang digeser mendatar, lalu daftar item yang sudah masuk.
- **Bagian bawah (menempel):** total belanja + tombol biru **KIRIM & CETAK STRUK**. Baris ini disembunyikan saat keyboard terbuka dan muncul kembali setelah keyboard tertutup.

Detail yang menentukan kecepatan:

- Jumlah terisi otomatis `1`, dengan tombol **−** dan **+** besar di kiri dan kanannya.
- Satuan dipilih dari chip: `sak`, `kg`, `batang`, `lembar`, `m`, `rit`, `pcs`, `lainnya`. Satuan terakhir untuk bahan tersebut otomatis terpilih.
- Kolom harga memformat sendiri menjadi `65.000` sambil diketik.
- Menekan favorit mengisi nama dan satuan, lalu memindahkan kursor ke kolom harga dengan keyboard angka terbuka.
- Menekan favorit agak lama membuka satu pilihan: "Sembunyikan dari daftar". Favorit yang disembunyikan tidak dihapus, hanya tidak ditampilkan, dan bisa dimunculkan lagi lewat Pengaturan.
- Subtotal muncul kecil di bawah kolom harga sebelum item ditambahkan, sehingga salah ketik nol ketahuan lebih awal.

### Mengubah daftar

Setiap baris item punya tombol hapus merah berukuran penuh 48dp di ujung kanan. **Tidak ada geser-untuk-hapus** — gerakan itu terlalu mudah terpicu tidak sengaja dan jarang ditemukan pengguna lansia. Menekan baris item membuka dialog ubah jumlah dan harga. Menghapus item dan mengosongkan seluruh daftar sama-sama meminta konfirmasi.

Dua item bernama sama tidak digabung otomatis; kasir mungkin sengaja memisahkannya karena harganya berbeda.

### Pratinjau Struk

Menampilkan struk persis seperti yang akan tercetak, dengan kolom opsional "Uang dibayar" yang menghitung kembalian, dan tiga tombol besar: **Cetak**, **Kirim WA**, **Simpan saja**.

**Kirim WA** mengirimkan berkas sesuai setelan `format_kiriman`: gambar PNG secara bawaan, atau PDF bila pengguna mengubahnya di Pengaturan. Tidak ada pilihan format di layar ini — menambah percabangan di titik tersibuk justru memperlambat.

Transaksi tersimpan ke database setelah salah satu dari ketiga tombol ditekan — bukan saat item ditambahkan — sehingga keranjang yang ditinggalkan tidak mengotori riwayat dan tidak memakan nomor nota. Setelah selesai, muncul konfirmasi "Tersimpan #0142" dan tombol **TRANSAKSI BARU**; keranjang tidak pernah dikosongkan diam-diam.

### Riwayat

Rekap hari ini di bagian teratas ("Hari ini: 14 nota · Rp 3.240.000"), disusul daftar nota terbaru. Menekan satu nota membuka pratinjau yang sama dengan opsi cetak ulang dan kirim ulang. **Nota tidak bisa diubah atau dihapus** setelah tersimpan.

### Pengaturan

Profil toko, lebar kertas, format kiriman WhatsApp, pilih printer, **Tes Cetak**, kelola favorit yang disembunyikan, cadangkan data, pulihkan data.

### Pengingat backup

Bila `backup_terakhir_ms` sudah lewat 30 hari, layar Kasir menampilkan banner yang tidak memblokir: "Sudah sebulan data belum dicadangkan." dengan tombol **Cadangkan Sekarang** dan **Nanti Saja**. "Nanti Saja" mengisi `backup_ditunda_sampai_ms` tujuh hari ke depan.

### Draf keranjang

Keranjang berjalan disimpan setiap kali berubah dan dipulihkan saat aplikasi dibuka kembali. Toko bangunan sering terinterupsi, dan kehilangan keranjang setengah jadi adalah kegagalan yang mahal.

---

## 6. Format struk

Kertas 58mm memuat **32 karakter** per baris pada Font A (384 dot); kertas 80mm memuat **48 karakter**. Seluruh aturan di bawah memakai lebar `W` sehingga pergantian ukuran kertas hanya mengubah satu angka.

### Susunan

```
|<---------- 32 kolom ---------->|
       TB. SINAR BANGUNAN
    Jl. Raya Merdeka No. 45
    Telp/WA: 0812-3456-7890
--------------------------------
No. Nota : #0142
Tanggal  : 17/09/2026 14:30
Kasir    : Admin
--------------------------------
Semen Tiga Roda
               3x65.000  195.000
Pasir (1 rit)            850.000
Paku 7cm        2x20.000  40.000
Keramik Granit Roman 60x60
Putih Doff
              4x185.000  740.000
--------------------------------
TOTAL               Rp 1.825.000
Bayar               Rp 2.000.000
Kembali             Rp   175.000
--------------------------------
      *** TERIMA KASIH ***
    Barang yang sudah dibeli
   tidak dapat dikembalikan.
```

Baris penggaris di atas bukan bagian dari struk; ia hanya menandai lebar 32 kolom. Setiap baris item, baris TOTAL, dan garis pemisah pada contoh ini tepat 32 karakter.

### Algoritma baris item (C-adaptif)

```
jika qty == 1:
    nama_tampil = "{nama} ({satuan})"
    kanan       = subtotal
selain itu:
    nama_tampil = nama
    kanan       = "{qty}x{harga_satuan}" + dua spasi + subtotal

sisa = W - panjang(kanan) - 1

jika panjang(nama_tampil) <= sisa:
    satu baris: nama_tampil + spasi pengisi + kanan        (tepat W karakter)
selain itu:
    nama_tampil dibungkus per kata, tiap baris maksimal W
    baris berikutnya: kanan, rata kanan                    (tepat W karakter)
```

Aturan tambahan:

- Satu kata tunggal yang lebih panjang dari `W` dipotong paksa pada `W`. Ini satu-satunya keadaan yang memotong nama.
- `qty` ditampilkan tanpa desimal bila bulat (`3`), dengan koma bila pecahan (`1,5`).
- Tanda kali ditulis sebagai huruf **`x` biasa**, bukan simbol `×`. Banyak printer thermal murah tidak memiliki karakter itu pada code page bawaannya dan akan mencetak sampah.
- "Rp" hanya muncul pada blok TOTAL, tidak pada baris item.
- Baris **Bayar** dan **Kembali** hanya dicetak bila kasir mengisinya.
- **Invarian:** tidak ada baris keluaran yang boleh melebihi `W` karakter.

Pratinjau di layar, gambar PNG untuk WhatsApp, dan PDF memakai susunan yang sama persis, sehingga struk di HP pembeli identik dengan struk di kertas.

---

## 7. Penanganan kesalahan

Setiap pesan memakai bahasa sehari-hari dan selalu menawarkan jalan keluar. Tidak ada kode error atau istilah teknis.

### Bluetooth & printer

| Kondisi | Perilaku |
|---|---|
| Izin Bluetooth belum diberikan | Penjelasan singkat, tombol "Izinkan". Bila ditolak permanen, tombol "Buka Pengaturan HP" |
| Bluetooth HP mati | Banner "Bluetooth belum menyala" + tombol "Nyalakan" |
| Printer belum pernah dipilih | Tombol Cetak langsung membuka daftar printer |
| Printer tidak menyahut (batas 8 detik) | "Printer tidak terhubung. Sudah menyala? Kertasnya ada?" + tombol **Coba Lagi** dan **Kirim WA Saja** |
| Cetak putus di tengah | Dianggap gagal cetak, tetapi transaksi sudah tersimpan dan bisa dicetak ulang dari Riwayat |

Izin: `BLUETOOTH_CONNECT` dan `BLUETOOTH_SCAN` untuk Android 12+; `BLUETOOTH`, `BLUETOOTH_ADMIN`, dan `ACCESS_FINE_LOCATION` untuk Android 11 ke bawah. Alasan izin lokasi dijelaskan ke pengguna agar tidak menimbulkan kecurigaan.

**Aturan yang tidak bisa ditawar: transaksi disimpan ke database sebelum perintah cetak dikirim.** Urutan terbalik berarti satu kegagalan Bluetooth menghapus penjualan yang sudah terjadi.

### Isian

Kesalahan dicegah, bukan ditegur. Tombol "+ Tambah" nonaktif selama nama bahan kosong. Harga di atas Rp 999.999.999 ditolak saat diketik. Jumlah harus lebih besar dari nol. Harga Rp 0 **diizinkan** karena barang bonus itu nyata dan tetap perlu tercatat di struk sebagai bukti serah terima.

### Lain-lain

- WhatsApp tidak terpasang: tombol Kirim WA menjelaskan keadaannya dan menawarkan berbagi lewat aplikasi lain.
- Database gagal dibuka: pesan jelas disertai tawaran memulihkan dari backup.
- Berkas backup rusak atau bukan milik aplikasi ini: ditolak pada tahap validasi, data lama tetap utuh.

---

## 8. Pengujian

### Uji unit murni (`dart test`, tanpa emulator, tanpa printer)

- **`kolom.dart`** — nama pendek satu baris; nama tepat di batas; nama 40 karakter yang harus dibungkus; kata tunggal lebih panjang dari `W`; nominal `15.000.000` dengan qty dua digit; lebar 48 untuk kertas 80mm. Invarian "tidak ada baris melebihi `W`" diperiksa pada setiap kasus.
- **`uang.dart`** — format `65000 -> "65.000"`, parse balik, penolakan nominal di atas batas.
- **`receipt_builder.dart`** — dibandingkan dengan struk harapan yang ditulis lengkap sebagai teks.
- Kalkulasi subtotal, total, dan kembalian, termasuk pembulatan qty pecahan.

### Uji repository (`sqflite_common_ffi`, in-memory)

Nomor nota tidak pernah terpakai dua kali; rekap harian memotong tanggal dengan benar; `jumlah_pakai` favorit naik setelah transaksi tersimpan; ekspor lalu impor menghasilkan data identik; berkas backup cacat ditolak tanpa merusak data lama.

### Uji widget

Menambah item memperbarui total; tombol "+ Tambah" nonaktif saat nama kosong; menghapus item meminta konfirmasi; draf keranjang pulih setelah aplikasi dimatikan.

### Uji golden

`ReceiptWidget` dikunci dengan golden test. Karena widget yang sama menghasilkan PNG WhatsApp, satu golden ini sekaligus menjaga kesamaan struk digital dan struk kertas.

### Checklist manual sebelum rilis

Cetak sungguhan ke printer 58mm; alur izin Bluetooth di Android 12+ dan Android 11; berbagi ke WhatsApp; pulihkan dari backup; **pengujian dengan ukuran font Android disetel paling besar** — pengguna lansia umumnya sudah memperbesar font sistem, dan tata letak yang rapi pada setelan normal bisa pecah di sana.

### Uji lapangan

Tiga pemilik toko berusia 50+ mencoba tanpa didampingi, dengan waktu diukur.

---

## 9. Dependensi

| Paket | Kegunaan |
|---|---|
| `shared_preferences` | Profil toko, draf keranjang, penanda backup |
| `sqflite` | Transaksi, item, favorit, meta |
| `sqflite_common_ffi` | Uji repository di komputer (dev only) |
| `print_bluetooth_thermal` | Koneksi dan pengiriman ke printer Bluetooth |
| `esc_pos_utils_plus` | Penyusunan perintah ESC/POS. Fork yang dirawat; `esc_pos_utils` asli sudah tidak diperbarui |
| `pdf` | PDF opsional |
| `share_plus` | Share sheet untuk PNG, PDF, dan berkas backup |
| `file_picker` | Memilih berkas saat memulihkan data |
| `provider` | Pengelolaan state |
| `intl` | Format tanggal |

Versi mengikuti rilis terbaru yang kompatibel saat implementasi dimulai; versi yang tercantum di PRD v1.0 sudah usang dan API `share_plus` telah berubah.

PNG dihasilkan dengan `RepaintBoundary` bawaan Flutter, tanpa paket tambahan.

**Paket `printing` dari PRD digugurkan.** Paket itu mencetak lewat layanan cetak sistem operasi, bukan ke printer Bluetooth thermal, sehingga tidak bisa memenuhi FT-05.

---

## 10. Kriteria keberhasilan

- Pengguna berusia 50+ menyelesaikan struk 3 item dalam **kurang dari 45 detik** tanpa didampingi.
- Seluruh fungsi pembuatan dan pencetakan struk berjalan **tanpa koneksi internet**; aplikasi tidak memiliki izin `INTERNET`.
- Tidak ada keluhan ukuran font dari pengguna uji coba, termasuk saat font sistem diperbesar.
- Pencetakan thermal tidak pernah menghasilkan baris yang melebihi lebar kertas.
- Transaksi tidak pernah hilang akibat kegagalan cetak atau aplikasi tertutup.

---

## 11. Perbedaan dari PRD v1.0

| Hal | PRD v1.0 | Desain ini | Alasan |
|---|---|---|---|
| Platform | Android & iOS | Android saja | Bluetooth Classic SPP tertutup di iOS |
| Tipe harga | `double` | `int` rupiah | Galat pembulatan floating point |
| Kuantitas | Tidak ada | Ada, termasuk pecahan | Toko bangunan menjual per sak, kubik, batang |
| Paket cetak | `printing` atau `blue_thermal_printer` | `print_bluetooth_thermal` + `esc_pos_utils_plus` | `printing` tidak menjangkau printer Bluetooth thermal |
| Kirim WA | "langsung ke nomor pembeli" | Share sheet, PNG utama | Android tidak mengizinkan lampiran berkas ke nomor tertentu dalam satu langkah |
| Penyimpanan | Hanya `shared_preferences` | Ditambah `sqflite` | Riwayat memerlukan query per tanggal |
| Riwayat | Tidak ada | Ada, beserta rekap harian | Pertanyaan pertama pemilik toko adalah omzet hari ini |
| Favorit | Tidak ada | Ada | Tanpa ini, KPI 45 detik tidak tercapai |
| Backup | Tidak ada | Ada, beserta pengingat | Data lokal hilang saat ganti HP |
| Uang bayar & kembalian | Tidak ada | Ada | Menghapus beban hitung manual |
| Nomor nota | Tidak ada | Ada | Rujukan saat komplain atau retur |
| Versi dependensi | Ditetapkan | Mengikuti rilis terbaru | Versi di PRD sudah usang |

---

## 12. Rencana setelah v1

Ditinjau ulang setelah ada pengguna nyata: kasbon/hutang pelanggan, diskon per item dan per nota, harga eceran versus grosir, ekspor laporan, dan dukungan iOS bila muncul kebutuhan printer bersertifikat MFi.
