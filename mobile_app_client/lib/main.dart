import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart'; // Pudhusa add pannirukkom
import 'screens/report_camera.dart';

void main() {
  runApp(const SmartRoadApp());
}

class SmartRoadApp extends StatelessWidget {
  const SmartRoadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const MapDashboardScreen(),
    );
  }
}

class MapDashboardScreen extends StatefulWidget {
  const MapDashboardScreen({super.key});

  @override
  State<MapDashboardScreen> createState() => _MapDashboardScreenState();
}

class _MapDashboardScreenState extends State<MapDashboardScreen> {
  LatLng? currentLocation;
  final MapController _mapController = MapController();
  StreamSubscription<Position>? _positionStream;

  bool isAlertEnabled = true;
  bool isCooldown = false;

  // Tamil Nadu Main Cities - Real Traffic Hotspots
  List<LatLng> dangerPotholes = [
    const LatLng(13.0645, 80.1654),
    const LatLng(13.1550, 80.3080),
    const LatLng(13.0366, 80.1593),
    const LatLng(10.9925, 76.9613),
    const LatLng(11.0255, 77.0145),
    const LatLng(9.9320, 78.1325),
    const LatLng(10.8140, 78.7100),
    const LatLng(11.6660, 78.1450),
    const LatLng(8.7180, 77.7420),
  ];

  @override
  void initState() {
    super.initState();
    _startLiveTracking();
  }

  Future<void> _startLiveTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0, 
    );

    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            if (mounted) {
              setState(() {
                currentLocation = LatLng(position.latitude, position.longitude);
              });
              _checkProximity(position);
            }
          },
        );
  }

  void _checkProximity(Position currentPos) {
    if (!isAlertEnabled || isCooldown) return;

    for (var pothole in dangerPotholes) {
      double distance = Geolocator.distanceBetween(
        currentPos.latitude,
        currentPos.longitude,
        pothole.latitude,
        pothole.longitude,
      );
      if (distance <= 800) {
        _triggerAlert(distance);
        break;
      }
    }
  }

  void _triggerAlert(double distance) {
    isCooldown = true;
    SystemSound.play(SystemSoundType.alert);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 30),
            const SizedBox(width: 10),
            Text(
              '⚠️ DANGER AHEAD!\nPothole near ${distance.toInt()} meters!',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 5),
      ),
    );

    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        isCooldown = false;
      }
    });
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Road Damage Map'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: Icon(
              isAlertEnabled ? Icons.notifications_active : Icons.notifications_off,
              color: isAlertEnabled ? Colors.greenAccent : Colors.grey,
            ),
            onPressed: () {
              setState(() {
                isAlertEnabled = !isAlertEnabled;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isAlertEnabled ? '🔔 Voice Alerts ON' : '🔕 Voice Alerts OFF',
                  ),
                  backgroundColor: isAlertEnabled ? Colors.green : Colors.grey,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: currentLocation == null
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: currentLocation!,
                initialZoom: 7.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.mobile_app_client',
                ),
                MarkerLayer(
                  markers: [
                    Marker(                      
                      point: currentLocation!,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.my_location, color: Colors.blue, size: 30),
                    ),
                    ...dangerPotholes.map(
                      (potholeLatLng) => Marker(
                        point: potholeLatLng,
                        width: 40,
                        height: 40,
                        child: const Icon(Icons.warning_rounded, color: Colors.red, size: 40),
                      ),
                    ),
                  ],
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final bool? isPotholeDetected = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ReportCameraScreen()),
          );

          if (isPotholeDetected == true && currentLocation != null) {
            setState(() {
              dangerPotholes.add(currentLocation!);
            });

            // User-oda Gmail App open pandra pudhu logic
            final double lat = currentLocation!.latitude;
            final double lng = currentLocation!.longitude;
            final String mapLink = "https://maps.google.com/?q=$lat,$lng";
            
            final Uri emailLaunchUri = Uri(
              scheme: 'mailto',
              path: 'nhai_complaints_demo@gmail.com', 
              queryParameters: {
                'subject': '⚠️ Alert: Road Damage Detected',
                'body': 'Urgent: New road damage detected.\n\nLocation: Latitude $lat, Longitude $lng\nMap Link: $mapLink\n\nPlease take immediate action.',
              },
            );

            try {
              if (await canLaunchUrl(emailLaunchUri)) {
                await launchUrl(emailLaunchUri);
              } else {
                print("Could not launch email app");
              }
            } catch (e) {
              print("Error opening email: $e");
            }
          }
        },
        backgroundColor: Colors.orange,
        icon: const Icon(Icons.camera_alt, color: Colors.white),
        label: const Text(
          'Scan Road',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}