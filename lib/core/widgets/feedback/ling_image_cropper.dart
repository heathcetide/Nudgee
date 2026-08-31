import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Aspect ratio presets for image cropping.
enum LingCropAspectRatio {
  free,
  square(1.0),
  ratio3_4(3.0 / 4.0),
  ratio4_3(4.0 / 3.0),
  ratio9_16(9.0 / 16.0),
  ratio16_9(16.0 / 9.0);

  final double? value;
  const LingCropAspectRatio([this.value]);
}

/// Result of an image crop operation.
class LingCropResult {
  final Uint8List bytes;
  final int width;
  final int height;

  const LingCropResult({required this.bytes, required this.width, required this.height});
}

/// An interactive image cropping widget.
///
/// Shows an image with a draggable/resizable crop rectangle overlay.
/// The user can adjust the crop area and confirm to get the cropped image.
///
/// Usage:
/// ```dart
/// final result = await Navigator.push(
///   context,
///   MaterialPageRoute(
///     builder: (_) => LingImageCropper(imageBytes: myImageBytes),
///   ),
/// );
/// if (result != null) {
///   // result is LingCropResult
/// }
/// ```
class LingImageCropper extends StatefulWidget {
  final Uint8List imageBytes;
  final LingCropAspectRatio aspectRatio;
  final String? title;

  const LingImageCropper({
    super.key,
    required this.imageBytes,
    this.aspectRatio = LingCropAspectRatio.square,
    this.title,
  });

  @override
  State<LingImageCropper> createState() => _LingImageCropperState();
}

class _LingImageCropperState extends State<LingImageCropper> {
  ui.Image? _image;
  bool _isLoading = true;
  Rect? _imageRect;

  // Crop overlay state
  double _cropX = 0;
  double _cropY = 0;
  double _cropW = 0;
  double _cropH = 0;
  double _viewW = 0;
  double _viewH = 0;
  double _imgScale = 1.0;
  double _imgOffsetX = 0;
  double _imgOffsetY = 0;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final codec = await ui.instantiateImageCodec(widget.imageBytes);
    final frame = await codec.getNextFrame();
    setState(() {
      _image = frame.image;
      _isLoading = false;
    });
    _initCropRect();
  }

  void _initCropRect() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_image == null || !mounted) return;
      final imgW = _image!.width.toDouble();
      final imgH = _image!.height.toDouble();

      // Fit image into view
      final screenSize = MediaQuery.of(context).size;
      _viewW = screenSize.width;
      _viewH = screenSize.height * 0.6;

      _imgScale = _viewW / imgW < _viewH / imgH ? _viewW / imgW : _viewH / imgH;
      final dispW = imgW * _imgScale;
      final dispH = imgH * _imgScale;
      _imgOffsetX = (_viewW - dispW) / 2;
      _imgOffsetY = (_viewH - dispH) / 2;

      // Initial crop rect — centered, 80% of image
      final ar = widget.aspectRatio.value;
      if (ar != null) {
        final baseW = dispW * 0.8;
        final baseH = baseW / ar;
        _cropW = baseH > dispH * 0.8 ? dispH * 0.8 * ar : baseW;
        _cropH = _cropW / ar;
      } else {
        _cropW = dispW * 0.8;
        _cropH = dispH * 0.8;
      }
      _cropX = _imgOffsetX + (dispW - _cropW) / 2;
      _cropY = _imgOffsetY + (dispH - _cropH) / 2;

      _imageRect = Rect.fromLTWH(_imgOffsetX, _imgOffsetY, dispW, dispH);
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title ?? '裁剪图片'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _onConfirm,
            child: const Text('确定', style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _buildCropView(),
    );
  }

  Widget _buildCropView() {
    return Stack(
      children: [
        // Image
        Positioned.fill(
          child: Center(
            child: SizedBox(
              width: _viewW,
              height: _viewH,
              child: Stack(
                children: [
                  if (_image != null)
                    Positioned(
                      left: _imgOffsetX,
                      top: _imgOffsetY,
                      child: RawImage(
                        image: _image,
                        scale: 1.0 / _imgScale,
                        fit: BoxFit.none,
                      ),
                    ),
                  // Dark overlay with hole
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _CropOverlayPainter(
                        cropRect: Rect.fromLTWH(_cropX, _cropY, _cropW, _cropH),
                      ),
                    ),
                  ),
                  // Crop handles
                  _buildCropHandles(),
                ],
              ),
            ),
          ),
        ),
        // Aspect ratio options
        Positioned(
          bottom: 20,
          left: 0,
          right: 0,
          child: Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: LingCropAspectRatio.values.map((ar) {
                  final selected = ar == widget.aspectRatio;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(_arLabel(ar)),
                      selected: selected,
                      onSelected: (_) {},
                      selectedColor: Colors.white,
                      labelStyle: TextStyle(
                        color: selected ? Colors.black : Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCropHandles() {
    return Positioned(
      left: _cropX,
      top: _cropY,
      width: _cropW,
      height: _cropH,
      child: GestureDetector(
        onPanUpdate: _onDragCrop,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Stack(
            children: [
              // Corner handles
              _cornerHandle(Alignment.topLeft),
              _cornerHandle(Alignment.topRight),
              _cornerHandle(Alignment.bottomLeft),
              _cornerHandle(Alignment.bottomRight),
              // Edge handles
              _edgeHandle(Alignment.topCenter, Axis.horizontal),
              _edgeHandle(Alignment.bottomCenter, Axis.horizontal),
              _edgeHandle(Alignment.centerLeft, Axis.vertical),
              _edgeHandle(Alignment.centerRight, Axis.vertical),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cornerHandle(Alignment alignment) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.blue, width: 2),
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _edgeHandle(Alignment alignment, Axis axis) {
    return Align(
      alignment: alignment,
      child: Container(
        width: axis == Axis.horizontal ? 32 : 4,
        height: axis == Axis.horizontal ? 4 : 32,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  void _onDragCrop(DragUpdateDetails details) {
    setState(() {
      var newX = _cropX + details.delta.dx;
      var newY = _cropY + details.delta.dy;
      // Clamp to image bounds
      if (_imageRect != null) {
        newX = newX.clamp(_imageRect!.left, _imageRect!.right - _cropW);
        newY = newY.clamp(_imageRect!.top, _imageRect!.bottom - _cropH);
      }
      _cropX = newX;
      _cropY = newY;
    });
  }

  Future<void> _onConfirm() async {
    if (_image == null || _imageRect == null) return;

    // Convert crop rect from display coords to image coords
    final imgX = (_cropX - _imgOffsetX) / _imgScale;
    final imgY = (_cropY - _imgOffsetY) / _imgScale;
    final imgW = _cropW / _imgScale;
    final imgH = _cropH / _imgScale;

    final cropRect = Rect.fromLTWH(imgX, imgY, imgW, imgH);

    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    canvas.drawImageRect(
      _image!,
      cropRect,
      Rect.fromLTWH(0, 0, imgW, imgH),
      Paint(),
    );
    final picture = pictureRecorder.endRecording();
    final croppedImage = await picture.toImage(imgW.toInt(), imgH.toInt());
    final byteData = await croppedImage.toByteData(format: ui.ImageByteFormat.png);

    if (byteData != null && mounted) {
      Navigator.pop(
        context,
        LingCropResult(
          bytes: byteData.buffer.asUint8List(),
          width: imgW.toInt(),
          height: imgH.toInt(),
        ),
      );
    }
  }

  String _arLabel(LingCropAspectRatio ar) {
    switch (ar) {
      case LingCropAspectRatio.free:
        return '自由';
      case LingCropAspectRatio.square:
        return '1:1';
      case LingCropAspectRatio.ratio3_4:
        return '3:4';
      case LingCropAspectRatio.ratio4_3:
        return '4:3';
      case LingCropAspectRatio.ratio9_16:
        return '9:16';
      case LingCropAspectRatio.ratio16_9:
        return '16:9';
    }
  }
}

/// Painter for the dark overlay with a transparent hole for the crop area.
class _CropOverlayPainter extends CustomPainter {
  final Rect cropRect;

  _CropOverlayPainter({required this.cropRect});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black54;
    final outerPath = Path()..addRect(Offset.zero & size);
    final innerPath = Path()..addRect(cropRect);
    final combinedPath = Path.combine(PathOperation.difference, outerPath, innerPath);
    canvas.drawPath(combinedPath, paint);

    // Grid lines inside crop area
    final gridPaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1;
    // Vertical lines (thirds)
    for (int i = 1; i < 3; i++) {
      final x = cropRect.left + cropRect.width * i / 3;
      canvas.drawLine(Offset(x, cropRect.top), Offset(x, cropRect.bottom), gridPaint);
    }
    // Horizontal lines (thirds)
    for (int i = 1; i < 3; i++) {
      final y = cropRect.top + cropRect.height * i / 3;
      canvas.drawLine(Offset(cropRect.left, y), Offset(cropRect.right, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter oldDelegate) =>
      cropRect != oldDelegate.cropRect;
}
