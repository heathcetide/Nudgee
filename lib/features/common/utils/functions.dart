import 'dart:typed_data';

import 'package:nudgee/core/di/injector.dart';
import 'package:nudgee/core/services/file_storage_service.dart';
import 'package:nudgee/features/common/utils/consts.dart';
import 'package:dio/dio.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

DateTime getZeroOclockOfDay(DateTime dateTime) {
  return DateTime(dateTime.year, dateTime.month, dateTime.day);
}

String padLeft(int num, [int length = 2, String fill = '0']) {
  return num.toString().padLeft(length, fill);
}

String getChineseStringByDatetime(DateTime dateTime, [DateTime? now]) {
  now ??= DateTime.now();
  if (dateTime.year == now.year && dateTime.month == now.month && dateTime.day == now.day) {
    // 同一天
    int min = now.hour * 60 + now.minute - dateTime.hour * 60 - dateTime.minute;
    if (min <= 1) return '刚刚';
    if (min < 60) return '$min分钟前';
    return '${now.hour - dateTime.hour}小时前';
  }
  // 不同天
  int day = getZeroOclockOfDay(now).difference(getZeroOclockOfDay(dateTime)).inDays;
  if (day <= 0) return '未来(请检查本机系统时间)';
  if (day == 1) return '昨天${padLeft(dateTime.hour)}:${padLeft(dateTime.minute)}';
  if (day == 2) return '前天';
  if (day <= 7) {
    return '$day天前';
  }
  if (dateTime.year == now.year) {
    return '${padLeft(dateTime.month)}-${padLeft(dateTime.day)}';
  }
  return '${dateTime.year}-${padLeft(dateTime.month)}-${padLeft(dateTime.day)}';
}

Future<void> saveNetworkImage(String imageUrl, context) async {
  try {
    // Download the image from the network
    var response = await dio.get(imageUrl, options: Options(responseType: ResponseType.bytes));
    Uint8List imageData = Uint8List.fromList(response.data);

    // Save to app-private storage via FileStorageService (no permission needed)
    final fileName = imageUrl.split('/').last.split('?').first;
    final saved = await sl<FileStorageService>().saveBytes(
      FileStorageService.dirDownloads,
      fileName.isEmpty ? 'image_${DateTime.now().millisecondsSinceEpoch}.jpg' : fileName,
      imageData,
    );
    if (saved != null) {
      SmartDialog.showNotify(msg: '已保存图片', notifyType: NotifyType.success);
    } else {
      SmartDialog.showNotify(msg: '保存失败', notifyType: NotifyType.failure);
    }
  } catch (e) {
    SmartDialog.showNotify(msg: '保存错误：$e', notifyType: NotifyType.error);
  }
}

Future<Uint8List> getCompressedImage(Uint8List image,
    {minHeight = 1920, minWidth = 1920, quality = 88}) async {
  var result = await FlutterImageCompress.compressWithList(
    image,
    minHeight: minHeight,
    minWidth: minWidth,
    quality: quality,
  );
  return result;
}
