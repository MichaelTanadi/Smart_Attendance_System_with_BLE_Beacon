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
  StreamSubscription<DiscoveredDevice>? _scanStream;

  Future<void> _startScan() async {
  // Request location permission before starting scan
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
    // Optionally show a dialog/snackbar to the user here
  }
}


  void _stopScan() {
    _scanStream?.cancel();
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
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DeviceDetailScreen(device: device),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class DeviceDetailScreen extends StatefulWidget {
  final DiscoveredDevice device;

  const DeviceDetailScreen({super.key, required this.device});

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  final flutterReactiveBle = FlutterReactiveBle();
  late StreamSubscription<ConnectionStateUpdate> _connectionStream;
  String _connectionStatus = "Connecting...";

  @override
  void initState() {
    super.initState();
    _connectToDevice();
    requestPermissions();
  }

  Future<void> requestPermissions() async {
  var status = await Permission.locationWhenInUse.status;
  if (!status.isGranted) {
    await Permission.locationWhenInUse.request();
  }
}

  void _connectToDevice() {
    _connectionStream = flutterReactiveBle.connectToDevice(
  id: widget.device.id,
  connectionTimeout: const Duration(seconds: 10),
).listen((connectionState) {
  setState(() {
    switch (connectionState.connectionState) {
      case DeviceConnectionState.connecting:
        _connectionStatus = "Connecting...";
        break;
      case DeviceConnectionState.connected:
        _connectionStatus = "Connected";
        break;
      case DeviceConnectionState.disconnecting:
        _connectionStatus = "Disconnecting...";
        break;
      case DeviceConnectionState.disconnected:
        _connectionStatus = "Disconnected";
        break;
    }
  });
}, onError: (error) {
  setState(() {
    _connectionStatus = "Failed to connect: $error";
  });
});
  }

  @override
  void dispose() {
    _connectionStream.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.device.name.isNotEmpty ? widget.device.name : "Unknown Device")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Device ID: ${widget.device.id}", style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            Text("Connection Status: $_connectionStatus", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}