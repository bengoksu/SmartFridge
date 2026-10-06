import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class ReceiptCameraPage extends StatefulWidget {
  const ReceiptCameraPage({
    super.key,
    this.title = 'Fiş Fotoğrafı Çek',
    this.instructions = 'Fişin tamamını kadraja alın ve sabit tutun.',
    this.permissionMessage =
        'Fiş fotoğrafı çekmek için kamera izni vermelisiniz.',
  });

  final String title;
  final String instructions;
  final String permissionMessage;

  @override
  State<ReceiptCameraPage> createState() => _ReceiptCameraPageState();
}

class _ReceiptCameraPageState extends State<ReceiptCameraPage>
    with WidgetsBindingObserver {
  CameraController? _controller;
  CameraDescription? _selectedCamera;
  bool _isInitializing = true;
  bool _isTakingPicture = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (mounted) {
      setState(() {
        _isInitializing = true;
        _errorMessage = null;
      });
    }

    try {
      final cameras = await availableCameras();
      debugPrint(
        'Receipt camera: availableCameras() -> ${cameras.length} kamera',
      );
      for (final camera in cameras) {
        debugPrint(
          'Receipt camera: name=${camera.name}, '
          'lensDirection=${camera.lensDirection}',
        );
      }
      if (cameras.isEmpty) {
        throw CameraException(
          'NoCamera',
          'Bu cihazda kullanılabilir kamera bulunamadı.',
        );
      }

      _selectedCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      debugPrint(
        'Receipt camera: selected name=${_selectedCamera!.name}, '
        'lensDirection=${_selectedCamera!.lensDirection}',
      );

      final controller = CameraController(
        _selectedCamera!,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      _controller = controller;
      try {
        await controller.initialize();
        debugPrint('Receipt camera: CameraController.initialize() succeeded');
      } catch (error, stackTrace) {
        debugPrint(
          'Receipt camera: CameraController.initialize() failed: $error',
        );
        debugPrintStack(
          label: 'Receipt camera initialize stack trace',
          stackTrace: stackTrace,
        );
        rethrow;
      }

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() => _isInitializing = false);
    } on CameraException catch (error, stackTrace) {
      debugPrint(
        'Receipt camera CameraException: '
        'code=${error.code}, description=${error.description}',
      );
      debugPrintStack(
        label: 'Receipt camera CameraException stack trace',
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _errorMessage =
            '${error.code}: ${error.description ?? error.toString()}';
      });
    } catch (error, stackTrace) {
      debugPrint('Receipt camera unexpected error: $error');
      debugPrintStack(
        label: 'Receipt camera unexpected error stack trace',
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _errorMessage = error.toString();
      });
    }
  }

  String _cameraErrorMessage(CameraException error) {
    switch (error.code) {
      case 'CameraAccessDenied':
      case 'CameraAccessDeniedWithoutPrompt':
      case 'CameraAccessRestricted':
        return widget.permissionMessage;
      default:
        return error.description ??
            'Kamera başlatılamadı. Lütfen tekrar deneyin.';
    }
  }

  Future<void> _takePicture() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture ||
        _isTakingPicture) {
      return;
    }

    setState(() => _isTakingPicture = true);
    try {
      final image = await controller.takePicture();
      if (!mounted) return;
      Navigator.of(context).pop(image);
    } on CameraException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_cameraErrorMessage(error))));
      setState(() => _isTakingPicture = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      controller.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title),
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    final controller = _controller;
    if (_isInitializing) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null ||
        controller == null ||
        !controller.value.isInitialized) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.no_photography_outlined,
                color: Colors.white70,
                size: 56,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage ?? 'Kamera kullanılamıyor.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _initializeCamera,
                icon: const Icon(Icons.refresh),
                label: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: CameraPreview(controller),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: Column(
            children: [
              Text(
                widget.instructions,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              Semantics(
                button: true,
                label: 'Fotoğraf çek',
                child: IconButton.filled(
                  onPressed: _isTakingPicture ? null : _takePicture,
                  iconSize: 38,
                  padding: const EdgeInsets.all(18),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF22C55E),
                    foregroundColor: Colors.white,
                  ),
                  icon: _isTakingPicture
                      ? const SizedBox(
                          width: 38,
                          height: 38,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : const Icon(Icons.camera_alt_rounded),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
