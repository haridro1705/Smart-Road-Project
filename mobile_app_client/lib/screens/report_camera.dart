import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:convert';

class ReportCameraScreen extends StatefulWidget {
  const ReportCameraScreen({super.key});

  @override
  State<ReportCameraScreen> createState() => _ReportCameraScreenState();
}

class _ReportCameraScreenState extends State<ReportCameraScreen> {
  CameraController? _controller;
  bool _isCameraInitialized = false;
  bool _isDetecting = false;
  List<dynamic> _detections = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      _controller = CameraController(
        cameras[0],
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint("Camera Error: $e");
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _captureAndDetect() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isDetecting)
      return;
    setState(() {
      _isDetecting = true;
    });

    try {
      final XFile imageFile = await _controller!.takePicture();
      await _sendToBackend(imageFile.path);
    } catch (e) {
      _showError('❌ Camera Capture Failed.');
      setState(() {
        _isDetecting = false;
      });
    }
  }

  Future<void> _pickImageAndDetect() async {
    if (_isDetecting) return;

    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      setState(() {
        _isDetecting = true;
      });
      await _sendToBackend(image.path);
    } catch (e) {
      _showError('❌ Gallery Error.');
      setState(() {
        _isDetecting = false;
      });
    }
  }

  Future<void> _sendToBackend(String imagePath) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://10.0.2.2:8000/detect-image'),
      );
      request.files.add(await http.MultipartFile.fromPath('file', imagePath));
      var response = await request.send();
      var responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        var jsonResult = jsonDecode(responseData);
        setState(() {
          _detections = jsonResult['detections'];
        });
        _showResultDialog();
      } else {
        _showError('❌ Server Error! ${response.statusCode}');
      }
    } catch (e) {
      _showError('❌ Connection Failed. Backend Run aagutha nu check pannunga!');
    } finally {
      setState(() {
        _isDetecting = false;
      });
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _showResultDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Veliya click panna close aagakudathu
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Row(
            children: [
              Icon(Icons.analytics, color: Colors.blue),
              SizedBox(width: 10),
              Text('YOLOv8 Results'),
            ],
          ),
          content: _detections.isEmpty
              ? const Text('No objects detected in this image.')
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _detections.map((d) {
                    return ListTile(
                      leading: const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                      ),
                      title: Text(
                        d['class_name'].toString().toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text('Accuracy: ${d['confidence']}%'),
                    );
                  }).toList(),
                ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Dialog-ah close pannum

                // --- MAGIC CODE STARTS HERE ---
                // Pothole iruntha, 'true' nu signal-oda map-ku po, illana summaa po
                if (_detections.isNotEmpty) {
                  Navigator.pop(context, true);
                }
                // --- MAGIC CODE ENDS HERE ---
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: const Text('OK', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Live AI Scanner',
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          if (_isCameraInitialized)
            SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: CameraPreview(_controller!),
            )
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          if (_isDetecting)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.orange),
                    SizedBox(height: 15),
                    Text(
                      'YOLOv8 is analyzing...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            FloatingActionButton.extended(
              heroTag: 'camera_btn',
              onPressed: _isDetecting ? null : _captureAndDetect,
              backgroundColor: _isDetecting ? Colors.grey : Colors.orange,
              icon: Icon(
                _isDetecting ? Icons.hourglass_top : Icons.camera_alt,
                color: Colors.white,
              ),
              label: Text(
                _isDetecting ? 'Scanning...' : 'Scan Now',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            FloatingActionButton.extended(
              heroTag: 'gallery_btn',
              onPressed: _isDetecting ? null : _pickImageAndDetect,
              backgroundColor: _isDetecting ? Colors.grey : Colors.blue,
              icon: Icon(
                _isDetecting ? Icons.hourglass_top : Icons.photo_library,
                color: Colors.white,
              ),
              label: const Text(
                'Gallery',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
