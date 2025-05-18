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

  // Added variables for dynamic service/characteristic discovery and read value
  List<DiscoveredService> _services = [];
  Uuid? _selectedServiceUuid;
  Uuid? _selectedCharacteristicUuid;
  String _readValue = "";

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
            _discoverServices(); // Discover services once connected
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

  Future<void> _discoverServices() async {
    try {
      final services = await flutterReactiveBle.discoverServices(widget.device.id);
      setState(() {
        _services = services;
        if (_services.isNotEmpty) {
          _selectedServiceUuid = _services[0].serviceId;
          if (_services[0].characteristics.isNotEmpty) {
            _selectedCharacteristicUuid = _services[0].characteristics[0].characteristicId;

          }
        }
      });
    } catch (e) {
      setState(() {
        _readValue = "Service discovery error: $e";
      });
    }
  }

  Future<void> _readCharacteristic() async {
    if (_selectedServiceUuid == null || _selectedCharacteristicUuid == null) {
      setState(() {
        _readValue = "No service or characteristic selected";
      });
      return;
    }

    try {
      final characteristic = QualifiedCharacteristic(
        serviceId: _selectedServiceUuid!,
        characteristicId: _selectedCharacteristicUuid!,
        deviceId: widget.device.id,
      );
      final response = await flutterReactiveBle.readCharacteristic(characteristic);

      setState(() {
        _readValue = response.isNotEmpty ? response.toString() : "Empty response";
      });
    } catch (e) {
      setState(() {
        _readValue = "Read error: $e";
      });
    }
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

            // Display discovered service and characteristic UUIDs if available
            if (_selectedServiceUuid != null && _selectedCharacteristicUuid != null) ...[
              const SizedBox(height: 16),
              Text("Service UUID: $_selectedServiceUuid"),
              Text("Characteristic UUID: $_selectedCharacteristicUuid"),
            ],

            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _connectionStatus == "Connected" ? _readCharacteristic : null,
              child: const Text("Read Characteristic"),
            ),
            const SizedBox(height: 16),
            Text("Read Value: $_readValue", style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
