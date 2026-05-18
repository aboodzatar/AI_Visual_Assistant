import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image/image.dart' as img;

class CameraService {
  CameraController? _controller;
  late CameraDescription _camera;

  bool get isInitialized => _controller?.value.isInitialized == true;
  bool get isCapturing => _controller?.value.isTakingPicture == true;

  Future<bool> requestPermissions() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  Future<void> initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) throw Exception('No cameras available');

    // Prefer back camera, fallback to first available
    _camera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      _camera,
      ResolutionPreset.high, // 1080p: better quality for visual recognition
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await _controller!.initialize();
    if (!_controller!.value.isInitialized) {
      throw Exception('Camera failed to initialize');
    }
  }

  Widget buildPreview() {
    if (!isInitialized) return const SizedBox.shrink();
    return CameraPreview(_controller!);
  }

  Future<Uint8List?> captureAndCompressImage() async {
    if (!isInitialized || isCapturing) return null;

    try {
      final XFile photo = await _controller!.takePicture();
      final bytes = await photo.readAsBytes();

      // OPTIMIZATION: Resize to max 800px width + 75% JPEG quality for faster upload
      final original = img.decodeImage(bytes);
      if (original == null) return bytes;

      // Maintain aspect ratio, limit to 800px max dimension
      final ratio =
          original.width > original.height
              ? 800 / original.width
              : 800 / original.height;
      final newWidth = (original.width * ratio).round();
      final newHeight = (original.height * ratio).round();

      final resized = img.copyResize(
        original,
        width: newWidth,
        height: newHeight,
      );
      final compressed = img.encodeJpg(
        resized,
        quality: 75,
      ); // 75% quality = ~60% size reduction

      return Uint8List.fromList(compressed);
    } catch (e) {
      throw Exception('Capture failed: $e');
    }
  }

  void dispose() {
    _controller?.dispose();
    _controller = null;
  }
}
