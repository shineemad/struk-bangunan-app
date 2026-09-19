"""Membuat ikon peluncur Notaku dari bentuk dasar, tanpa aset biner di repo.

Dijalankan sekali; hasilnya ditulis ke android/app/src/main/res/.
Palet mengikuti design-system/strukbangunan/MASTER.md: aksen #2563EB, kertas putih.
"""

from pathlib import Path

from PIL import Image, ImageDraw

AKSEN = (0x25, 0x63, 0xEB, 255)
PUTIH = (255, 255, 255, 255)
RES = Path(__file__).resolve().parents[1] / "android/app/src/main/res"

# Kepadatan layar Android: nama folder -> pengali terhadap mdpi.
KEPADATAN = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}


def gambar_struk(d: ImageDraw.ImageDraw, kotak, warna):
    """Selembar struk dengan tepi bawah bergerigi dan beberapa baris teks."""
    x0, y0, x1, y1 = kotak
    lebar = x1 - x0
    tinggi = y1 - y0
    gerigi = tinggi * 0.09
    badan = y1 - gerigi

    d.rounded_rectangle([x0, y0, x1, badan], radius=lebar * 0.06, fill=warna)

    # Gerigi bawah: segitiga berulang, meniru struk yang disobek.
    gigi = 6
    langkah = lebar / gigi
    titik = [(x0, badan)]
    for i in range(gigi):
        titik.append((x0 + langkah * (i + 0.5), y1))
        titik.append((x0 + langkah * (i + 1), badan))
    titik.append((x1, badan))
    d.polygon(titik, fill=warna)


def gambar_baris(d: ImageDraw.ImageDraw, kotak, warna):
    """Baris-baris 'teks' di atas struk, dipotong agar terbaca sebagai nota."""
    x0, y0, x1, y1 = kotak
    lebar = x1 - x0
    tinggi = (y1 - y0) * 0.91
    tebal = max(2, round(tinggi * 0.07))
    kiri = x0 + lebar * 0.18
    for i, rasio in enumerate([0.64, 0.64, 0.44]):
        atas = y0 + tinggi * (0.30 + i * 0.20)
        d.rounded_rectangle(
            [kiri, atas, kiri + lebar * rasio, atas + tebal],
            radius=tebal / 2,
            fill=warna,
        )


def ikon_penuh(sisi: int) -> Image.Image:
    """Ikon lawas: latar biru membulat dengan struk putih di atasnya."""
    img = Image.new("RGBA", (sisi, sisi), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, sisi - 1, sisi - 1], radius=sisi * 0.22, fill=AKSEN)
    p = sisi * 0.26
    kotak = (p, sisi * 0.22, sisi - p, sisi * 0.80)
    gambar_struk(d, kotak, PUTIH)
    gambar_baris(d, kotak, AKSEN)
    return img


def ikon_depan(sisi: int) -> Image.Image:
    """Lapisan depan ikon adaptif: hanya struk, di dalam zona aman 66%."""
    img = Image.new("RGBA", (sisi, sisi), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    p = sisi * 0.34
    kotak = (p, sisi * 0.30, sisi - p, sisi * 0.72)
    gambar_struk(d, kotak, PUTIH)
    gambar_baris(d, kotak, AKSEN)
    return img


def main() -> None:
    for nama, kali in KEPADATAN.items():
        folder = RES / f"mipmap-{nama}"
        folder.mkdir(parents=True, exist_ok=True)
        ikon_penuh(round(48 * kali)).save(folder / "ic_launcher.png")
        ikon_depan(round(108 * kali)).save(folder / "ic_launcher_foreground.png")
        print(f"{folder.name}: ic_launcher {round(48 * kali)}px, "
              f"foreground {round(108 * kali)}px")


if __name__ == "__main__":
    main()
