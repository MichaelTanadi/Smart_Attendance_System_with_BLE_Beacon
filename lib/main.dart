import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Attendance',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const BleScannerScreen(),
    );
  }
}

class BleScannerScreen extends StatefulWidget {
  const BleScannerScreen({super.key});

  @override
  State<BleScannerScreen> createState() => _BleScannerScreenState();
}

class _BleScannerScreenState extends State<BleScannerScreen> {
  final FlutterReactiveBle _ble = FlutterReactiveBle();
  final List<DiscoveredDevice> _devices = [];

  bool _isScanning = false;

  void _startScan() {
    _devices.clear();
    setState(() {
      _isScanning = true;
    });

    _ble.scanForDevices(
      withServices: [], // Empty means scan for all BLE devices
      scanMode: ScanMode.lowLatency,
    ).listen((device) {
      final alreadyAdded = _devices.any((d) => d.id == device.id);
      if (!alreadyAdded) {
        setState(() {
          _devices.add(device);
        });
      }
    }, onError: (e) {
      setState(() {
        _isScanning = false;
      });
      print('Scan error: $e');
    });
  }

  Widget _buildDeviceList() {
    if (_devices.isEmpty) {
      return const Center(child: Text("No devices found yet."));
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: _devices.length,
      itemBuilder: (context, index) {
        final device = _devices[index];
        return ListTile(
          title: Text(device.name.isNotEmpty ? device.name : "(Unnamed device)"),
          subtitle: Text("ID: ${device.id} • RSSI: ${device.rssi}"),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Attendance System'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: _isScanning ? null : _startScan,
              icon: const Icon(Icons.bluetooth_searching),
              label: const Text("Scan"),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey),
                ),
                child: _buildDeviceList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
