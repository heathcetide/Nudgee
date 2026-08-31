import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Image processing utilities — cropping, resizing, compression.
///
/// Uses `dart:ui` for pixel-level manipulation without external dependencies.
class LingImageUtils {
  LingImageUtils._();

  /// Crop an image to the specified [rect] region.
  ///
  /// [rect] is in source image pixel coordinates.
  static Future<ui.Image> crop({
    required ui.Image source,
    required Rect rect,
  }) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);

    canvas.drawImageRect(
      source,
      rect,
      Rect.fromLTWH(0, 0, rect.width, rect.height),
      Paint(),
    );

    final picture = pictureRecorder.endRecording();
    return picture.toImage(rect.width.toInt(), rect.height.toInt());
  }

  /// Resize an image to a maximum dimension while maintaining aspect ratio.
  ///
  /// If the image is smaller than [maxDimension], it is returned as-is.
  static Future<ui.Image> resize({
    required ui.Image source,
    required double maxDimension,
  }) async {
    final width = source.width.toDouble();
    final height = source.height.toDouble();
    final scale = maxDimension / (width > height ? width : height);

    if (scale >= 1) return source;

    final newWidth = (width * scale).round();
    final newHeight = (height * scale).round();

    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);

    canvas.drawImageRect(
      source,
      Rect.fromLTWH(0, 0, width, height),
      Rect.fromLTWH(0, 0, newWidth.toDouble(), newHeight.toDouble()),
      Paint()..filterQuality = FilterQuality.medium,
    );

    final picture = pictureRecorder.endRecording();
    return picture.toImage(newWidth, newHeight);
  }

  /// Convert a [ui.Image] to PNG [Uint8List].
  static Future<Uint8List> toPngBytes(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// Convert a [ui.Image] to raw RGBA [Uint8List].
  static Future<Uint8List> toRawRgbaBytes(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return byteData!.buffer.asUint8List();
  }

  /// Capture a widget as a [ui.Image] by rendering it to a boundary.
  ///
  /// The widget must be wrapped in a [RepaintBoundary].
  static Future<ui.Image> captureWidget(GlobalKey boundaryKey) async {
    final boundary = boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    return boundary.toImage(pixelRatio: 2.0);
  }

  /// Capture a widget and return PNG bytes.
  static Future<Uint8List> captureWidgetAsPng(GlobalKey boundaryKey) async {
    final image = await captureWidget(boundaryKey);
    return toPngBytes(image);
  }

  /// Load a [ui.Image] from a [File].
  static Future<ui.Image> fromFile(File file) async {
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  /// Load a [ui.Image] from [Uint8List].
  static Future<ui.Image> fromBytes(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  /// Get image dimensions from a file without fully decoding.
  static Future<Size> getImageDimensions(File file) async {
    final image = await fromFile(file);
    return Size(image.width.toDouble(), image.height.toDouble());
  }
}
