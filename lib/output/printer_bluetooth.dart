import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

/// Printer yang sudah dipasangkan lewat pengaturan Bluetooth HP.
class PrinterTerdeteksi {
  final String nama;
  final String mac;

  const PrinterTerdeteksi({required this.nama, required this.mac});
}

/// Permukaan perangkat keras yang dipakai [PrinterService].
///
/// Antarmuka ini ada karena `PrintBluetoothThermal` seluruhnya statis dan
/// tidak bisa dipalsukan. Tanpa ia, tidak satu pun keputusan cetak bisa diuji
/// tanpa printer sungguhan.
abstract interface class PrinterBluetooth {
  Future<bool> izinDiberikan();
  Future<bool> bluetoothMenyala();
  Future<List<PrinterTerdeteksi>> daftarTerpasang();
  Future<bool> sudahTersambung();
  Future<bool> sambung(String mac);
  Future<bool> kirim(List<int> bytes);
  Future<void> putus();
}

/// Satu-satunya berkas yang boleh menyentuh plugin printer.
class PrinterBluetoothAsli implements PrinterBluetooth {
  const PrinterBluetoothAsli();

  @override
  Future<bool> izinDiberikan() =>
      PrintBluetoothThermal.isPermissionBluetoothGranted;

  @override
  Future<bool> bluetoothMenyala() => PrintBluetoothThermal.bluetoothEnabled;

  @override
  Future<List<PrinterTerdeteksi>> daftarTerpasang() async {
    final daftar = await PrintBluetoothThermal.pairedBluetooths;
    // `macAdress` memang salah eja di dalam paketnya. Salah eja itu berhenti
    // di baris ini dan tidak pernah masuk ke kode kita.
    return [
      for (final p in daftar) PrinterTerdeteksi(nama: p.name, mac: p.macAdress),
    ];
  }

  @override
  Future<bool> sudahTersambung() => PrintBluetoothThermal.connectionStatus;

  @override
  Future<bool> sambung(String mac) =>
      PrintBluetoothThermal.connect(macPrinterAddress: mac);

  @override
  Future<bool> kirim(List<int> bytes) =>
      PrintBluetoothThermal.writeBytes(bytes);

  @override
  Future<void> putus() => PrintBluetoothThermal.disconnect;
}
