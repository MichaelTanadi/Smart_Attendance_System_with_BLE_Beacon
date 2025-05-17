import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: BleScannerScreen(),
    );
  }
}

class BleScannerScreen extends StatefulWidget {
  const BleScannerScreen({super.key});

  @override
  State<BleScannerScreen> createState() => _BleScannerScreenState();
}

class _BleScannerScreenState extends State<BleScannerScreen> {
  final flutterReactiveBle = FlutterReactiveBle();
  final List<DiscoveredDevice> _foundDevices = [];
  late StreamSubscription<DiscoveredDevice> _scanStream;


Future<void> _startScan() async {
  // Request location permission first
  final status = await Permission.locationWhenInUse.request();

  if (status.isGranted) {
    _foundDevices.clear();
    _scanStream = flutterReactiveBle
        .scanForDevices(
          withServices: [],
          scanMode: ScanMode.lowLatency,
        )
        .listen((device) {
      final knownDevice = _foundDevices.any((d) => d.id == device.id);
      if (!knownDevice) {
        setState(() {
          _foundDevices.add(device);
        });
      }
    }, onError: (error) {
      debugPrint('Scan error: $error');
    });
  } else {
    debugPrint('Location permission not granted');
    // You can show a dialog or a snackbar to inform the user
  }
}



  void _stopScan() {
    _scanStream.cancel();
  }

  @override
  void dispose() {
    _stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BLE Scanner')),
      body: Column(
        children: [
          ElevatedButton(onPressed: _startScan, child: const Text("Start Scan")),
          ElevatedButton(onPressed: _stopScan, child: const Text("Stop Scan")),
          Expanded(
            child: ListView.builder(
              itemCount: _foundDevices.length,
              itemBuilder: (context, index) {
                final device = _foundDevices[index];
                return ListTile(
                  title: Text(device.name.isNotEmpty ? device.name : "Unknown"),
                  subtitle: Text("ID: ${device.id}"),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
