import 'dart:convert';
import 'dart:math';

import 'package:adaptive_action_sheet/adaptive_action_sheet.dart';
import 'package:nudgee/core/extensions/context_extensions.dart';
import 'package:nudgee/features/common/utils/consts.dart';
import 'package:nudgee/features/common/utils/functions.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:share_plus/share_plus.dart';

class ImageView extends StatefulWidget {
  final int index; // 初始图片下标
  final String? loadingImage; // 初始图片下标
  final List<Map<String, String>> images; // 图片列表[{'tag': 'xxx', 'url': 'xxx'},{},]
  const ImageView({super.key, required this.images, required this.index, this.loadingImage});

  @override
  State<ImageView> createState() => _ImageViewState();
}

class _ImageViewState extends State<ImageView> {
  int index = 0;

  @override
  void initState() {
    index = widget.index;
    super.initState();
  }

  void onPageChanged(int index) {
    setState(() {
      this.index = index;
    });
  }

  PhotoViewGalleryPageOptions _buildItem(BuildContext context, int index) {
    return PhotoViewGalleryPageOptions.customChild(
      child: ExtendedImage.network(
        widget.images[index]['url']!,
        cache: true,
        loadStateChanged: (ExtendedImageState state) {
          if (state.extendedImageLoadState == LoadState.loading) {
            if (index == widget.index) {
              return Container(
                width: 100,
                height: 100,
                constraints: BoxConstraints.expand(),
                child: ExtendedImage.network(
                  fit: BoxFit.contain,
                  widget.loadingImage!,
                  cache: true,
                ),
              );
            }
            return Center(
              child: CircularProgressIndicator(),
            );
          }

          return ExtendedRawImage(
            fit: BoxFit.contain,
            image: state.extendedImageInfo?.image,
          );
        },
      ),
      initialScale: PhotoViewComputedScale.contained,
      minScale: PhotoViewComputedScale.contained,
      maxScale: PhotoViewComputedScale.covered * 12,
      heroAttributes: PhotoViewHeroAttributes(
          tag: widget.images[this.index]['tag'] ?? widget.images[this.index]['url']!),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () {
          Navigator.of(context).maybePop();
        },
        child: Container(
          constraints: BoxConstraints.expand(
            height: MediaQuery.of(context).size.height,
          ),
          child: Stack(
            children: [
              GestureDetector(
                onLongPress: () {
                  showAdaptiveActionSheet(
                    context: context,
                    androidBorderRadius: 30,
                    actions: <BottomSheetAction>[
                      BottomSheetAction(
                          title: Text(context.l10n.imageSaveImage),
                          onPressed: (context) async {
                            SmartDialog.showLoading(msg: context.l10n.imageSaving);
                            await saveNetworkImage(widget.images[index]['url']!, context);
                            SmartDialog.dismiss();
                          }),
                      BottomSheetAction(
                          title: Text(context.l10n.imageShareImage),
                          onPressed: (context) async {
                            SmartDialog.showLoading(msg: '请稍后...');
                            var response = await dio.get(widget.images[index]['url']!,
                                options: Options(responseType: ResponseType.bytes));
                            Uint8List imageData = Uint8List.fromList(response.data);
                            SmartDialog.dismiss();
                            final result = await Share.shareXFiles([
                              XFile.fromData(imageData)
                            ], fileNameOverrides: [
                              'Nudgee_${md5.convert(utf8.encode(widget.images[index]['url']!))}.jpg'
                            ]);
                          }),
                    ],
                    // onPressed parameter is optional by default will dismiss the ActionSheet
                  );
                },
                child: PhotoViewGallery.builder(
                    scrollPhysics: const BouncingScrollPhysics(),
                    builder: _buildItem,
                    itemCount: widget.images.length,
                    onPageChanged: onPageChanged,
                    scrollDirection: Axis.horizontal,
                    pageController: PageController(initialPage: index)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
