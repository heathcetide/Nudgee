import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'package:nudgee/core/services/permission_service.dart';

/// Centralized file / media picking service.
///
/// Wraps [image_picker] and [file_picker] behind a uniform API and ensures
/// the appropriate permissions are requested before invoking the native
/// picker. Registered in `get_it` so any feature can resolve it via
/// `sl<FilePickerService>()`.
class FilePickerService {
  FilePickerService();

  final ImagePicker _imagePicker = ImagePicker();

  // ── Images ───────────────────────────────────────────────────────────

  /// Pick a single image from [source] (gallery by default).
  ///
  /// Returns `null` if the user cancels the picker or permission is denied.
  Future<XFile?> pickImage({
    ImageSource source = ImageSource.gallery,
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
  }) async {
    final granted = await PermissionService.requestPhotos();
    if (!granted) return null;
    try {
      return await _imagePicker.pickImage(
        source: source,
        maxWidth: maxWidth?.toDouble(),
        maxHeight: maxHeight?.toDouble(),
        imageQuality: imageQuality,
      );
    } catch (e) {
      debugPrint('FilePickerService.pickImage failed: $e');
      return null;
    }
  }

  /// Pick multiple images from the gallery.
  ///
  /// Returns an empty list if the user cancels or permission is denied.
  Future<List<XFile>> pickMultiImage({
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
  }) async {
    final granted = await PermissionService.requestPhotos();
    if (!granted) return const [];
    try {
      return await _imagePicker.pickMultiImage(
        maxWidth: maxWidth?.toDouble(),
        maxHeight: maxHeight?.toDouble(),
        imageQuality: imageQuality,
      );
    } catch (e) {
      debugPrint('FilePickerService.pickMultiImage failed: $e');
      return const [];
    }
  }

  // ── Videos ───────────────────────────────────────────────────────────

  /// Pick a single video from [source] (gallery by default).
  ///
  /// [maxDuration] limits the recording length when [source] is camera.
  Future<XFile?> pickVideo({
    ImageSource source = ImageSource.gallery,
    Duration? maxDuration,
  }) async {
    final granted = await PermissionService.requestPhotos();
    if (!granted) return null;
    try {
      return await _imagePicker.pickVideo(
        source: source,
        maxDuration: maxDuration,
      );
    } catch (e) {
      debugPrint('FilePickerService.pickVideo failed: $e');
      return null;
    }
  }

  // ── Media (image or video) ───────────────────────────────────────────

  /// Pick one or more media files (images / videos) via [file_picker].
  Future<List<XFile>?> pickMedia({bool allowMultiple = false}) async {
    final granted = await PermissionService.requestStorage();
    if (!granted) return null;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.media,
        allowMultiple: allowMultiple,
      );
      return result?.xFiles;
    } catch (e) {
      debugPrint('FilePickerService.pickMedia failed: $e');
      return null;
    }
  }

  // ── Generic files ────────────────────────────────────────────────────

  /// Pick one or more generic files.
  ///
  /// Use [allowedExtensions] to restrict to specific file types (only valid
  /// when [type] is [FileType.custom]). Returns `null` if the user cancels
  /// or permission is denied.
  Future<List<XFile>?> pickFile({
    List<String>? allowedExtensions,
    FileType type = FileType.any,
    bool allowMultiple = false,
  }) async {
    final granted = await PermissionService.requestStorage();
    if (!granted) return null;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: type,
        allowedExtensions: allowedExtensions,
        allowMultiple: allowMultiple,
      );
      return result?.xFiles;
    } catch (e) {
      debugPrint('FilePickerService.pickFile failed: $e');
      return null;
    }
  }
}
