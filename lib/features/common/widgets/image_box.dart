import 'dart:math';

import 'package:nudgee/features/common/widgets/image_view.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

class ImageBox extends StatelessWidget {
  final String url; // 当前缩略图url
  final String? tag; // 当前缩略图Hero tag
  final int? index; // 当前图片下标
  final BoxFit fit; // 当前图片fit
  final List<Map<String, String>>? images; // 图片列表[{'tag': 'xxx', 'url': 'xxx'},{},]
  final BoxDecoration? decoration;
  const ImageBox(this.url,
      {super.key, this.decoration, this.images, this.index, this.tag, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    void onTap() {
      Navigator.of(context).push(PageRouteBuilder(
          pageBuilder: (
            BuildContext context,
            animation,
            secondaryAnimation,
          ) {
            return FadeTransition(
              opacity: animation,
              child: ImageView(
                loadingImage: url,
                images: images ??
                    [
                      {'url': url, 'tag': url}
                    ],
                index: index ?? 0,
              ),
            );
          },
          opaque: false));
    }

    Map fit_alignmentMap = {
      BoxFit.contain: Alignment.center,
      BoxFit.fitHeight: Alignment.topLeft,
      BoxFit.fitWidth: Alignment.topLeft,
      BoxFit.fill: Alignment.center,
      BoxFit.cover: Alignment.center,
    };
    return Container(
      decoration: decoration ?? const BoxDecoration(),
      clipBehavior: Clip.antiAlias,
      child: GestureDetector(
        onTap: onTap,
        child: FittedBox(
          alignment: fit_alignmentMap[fit],
          fit: fit,
          clipBehavior: Clip.antiAlias,
          child: Hero(
            tag: tag ?? url,
            child: ExtendedImage.network(
              url,
              cache: true,
            ),
          ),
        ),
      ),
    );
  }
}
