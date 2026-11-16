import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// Guided native-resolution medicine capture with focus and exposure controls.
class GuidedCameraScreen extends StatefulWidget {
  const GuidedCameraScreen({super.key});
  @override
  State<GuidedCameraScreen> createState() => _GuidedCameraScreenState();
}

class _GuidedCameraScreenState extends State<GuidedCameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  bool _loading = true;
  bool _capturing = false;
  String? _error;
  double _exposure = 0;
  double _minExposure = 0;
  double _maxExposure = 0;
  bool _hasExposure = false;

  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); _initialize(); }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _controller = null;
      if (controller != null) unawaited(controller.dispose());
    } else if (state == AppLifecycleState.resumed && mounted && !_loading) {
      setState(() { _loading = true; _error = null; });
      _initialize();
    }
  }

  Future<void> _initialize() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw CameraException('NoCamera', 'No camera is available.');
      final selected = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cameras.first);
      final controller = CameraController(selected, ResolutionPreset.max, enableAudio: false, imageFormatGroup: ImageFormatGroup.jpeg);
      _controller = controller;
      await controller.initialize();
      try { await controller.setFocusMode(FocusMode.auto); } catch (_) {}
      try {
        await controller.setExposureMode(ExposureMode.auto);
        _minExposure = await controller.getMinExposureOffset();
        _maxExposure = await controller.getMaxExposureOffset();
        _hasExposure = _maxExposure > _minExposure;
        _exposure = 0.clamp(_minExposure, _maxExposure).toDouble();
      } catch (_) { _hasExposure = false; }
      if (mounted) setState(() => _loading = false);
    } on CameraException catch (e) {
      if (mounted) setState(() { _error = e.description ?? e.code; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Unable to start camera: $e'; _loading = false; });
    }
  }

  Future<void> _focus(Offset position, Size size) async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final point = Offset((position.dx / size.width).clamp(0.0, 1.0), (position.dy / size.height).clamp(0.0, 1.0));
    try { await c.setFocusMode(FocusMode.auto); await c.setFocusPoint(point); await c.setExposurePoint(point); } catch (_) {}
  }

  Future<void> _changeExposure(double value) async {
    final c = _controller;
    if (c == null) return;
    setState(() => _exposure = value);
    try { await c.setExposureOffset(value); } catch (_) {}
  }

  Future<void> _capture() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _capturing) return;
    setState(() => _capturing = true);
    try {
      final image = await c.takePicture();
      if (mounted) Navigator.of(context).pop(image);
    } on CameraException catch (e) {
      if (mounted) setState(() { _capturing = false; _error = 'Capture failed: ${e.description ?? e.code}'; });
    }
  }

  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); final c = _controller; _controller = null; if (c != null) unawaited(c.dispose()); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: const Text('Medicine camera')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && (c == null || !c.value.isInitialized)
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.camera_alt_outlined, color: Colors.white70, size: 42),
                  const SizedBox(height: 12), Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
                  const SizedBox(height: 16), FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Go back')),
                ])))
              : Column(children: [
                  Expanded(child: LayoutBuilder(builder: (context, constraints) {
                    final size = Size(constraints.maxWidth, constraints.maxHeight);
                    return GestureDetector(behavior: HitTestBehavior.opaque, onTapDown: (d) => _focus(d.localPosition, size), child: Stack(fit: StackFit.expand, children: [
                      CameraPreview(c!),
                      IgnorePointer(child: Center(child: FractionallySizedBox(widthFactor: 0.82, heightFactor: 0.58, child: DecoratedBox(
                        decoration: BoxDecoration(border: Border.all(color: Colors.tealAccent, width: 2), borderRadius: BorderRadius.circular(14)),
                        child: const Center(child: Text('Fit the medicine pack inside\nTap the text to focus', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 12, shadows: [Shadow(blurRadius: 5, color: Colors.black)]))),
                      )))),
                      if (_capturing) const Center(child: CircularProgressIndicator()),
                    ]));
                  })),
                  Container(width: double.infinity, color: const Color(0xFF101820), padding: const EdgeInsets.fromLTRB(20, 12, 20, 22), child: Column(children: [
                    const Text('Hold steady • Avoid glare • Tap the medicine text to focus', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 12)),
                    if (_hasExposure) ...[
                      const SizedBox(height: 8),
                      Row(children: [const Icon(Icons.exposure, color: Colors.white70, size: 18), Expanded(child: Slider(value: _exposure.clamp(_minExposure, _maxExposure), min: _minExposure, max: _maxExposure, onChanged: _capturing ? null : _changeExposure)), Text(_exposure.toStringAsFixed(1), style: const TextStyle(color: Colors.white70, fontSize: 11))]),
                    ],
                    const SizedBox(height: 8),
                    SizedBox(width: 68, height: 68, child: FloatingActionButton(heroTag: 'guided_camera_capture', onPressed: _capturing ? null : _capture, backgroundColor: Colors.white, foregroundColor: Colors.black, child: const Icon(Icons.camera_alt, size: 30))),
                  ])),
                ]),
    );
  }
}