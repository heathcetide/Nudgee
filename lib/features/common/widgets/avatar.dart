import 'dart:math';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:nudgee/features/common/widgets/image_box.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';

List<Color> colors = [
  Colors.purple,
  Colors.deepPurple,
  Colors.indigo,
  Colors.blue,
  Colors.lightBlue,
  Colors.cyan,
  Colors.teal,
  Colors.green,
  Colors.orange,
  Colors.deepOrange,
];

Color getDeeperColor(Color color) {
  return Color.fromARGB(
      color.alpha, max(color.red - 22, 0), max(color.green - 22, 0), max(color.blue - 22, 0));
}

Gradient getRandomGradient(String seed) {
  int random = Random(seed.hashCode).nextInt(colors.length);
  return LinearGradient(
    colors: [colors[random], getDeeperColor(colors[random])],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class Avatar extends StatelessWidget {
  final String? url;
  final String? name;
  final Function? onTap;
  const Avatar(this.url, {super.key, this.name, this.onTap});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      Widget content;
      if (url == null || url!.isEmpty) {
        content = Container(
          decoration: BoxDecoration(
              gradient: getRandomGradient(name ?? ''),
              borderRadius:
                  BorderRadius.circular(min(constraints.maxHeight, constraints.maxWidth) * 0.16)),
          child: LayoutBuilder(builder: (context, BoxConstraints constraints) {
            return Center(
                child: Padding(
              padding: EdgeInsets.all(constraints.maxHeight * 0.12),
              child: AutoSizeText(
                maxLines: 1,
                minFontSize: 0,
                maxFontSize: 666,
                name == null
                    ? ''
                    : name!.length > 2
                        ? name!.substring(name!.length - 2, name!.length)
                        : name!,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  height: 1,
                  fontSize: constraints.maxWidth * 0.5,
                  color: Colors.white,
                ),
              ),
            ));
          }),
        );
      } else {
        final urlStr = url!;
        if (onTap != null) {
          // With onTap — used as tappable avatar (e.g. in profile), no detail view.
          content = Container(
              child: ExtendedImage.network(
                urlStr,
                cacheWidth: 256,
                clearMemoryCacheWhenDispose: true,
              ),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius:
                    BorderRadius.circular(min(constraints.maxHeight, constraints.maxWidth) * 0.16),
              ));
        } else {
          // Tappable avatar with detail view — use the same URL for detail.
          // The URL already has a cache-busting ?t=timestamp param,
          // so it will load the latest image. No need to derive an "original" URL
          // (which may not exist or may hit stale cache).
          content = ImageBox(urlStr,
              images: [
                {'url': urlStr, 'tag': urlStr}
              ],
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(min(constraints.maxHeight, constraints.maxWidth) * 0.16),
              ));
        }
      }
      return onTap == null
          ? content
          : GestureDetector(
              child: content,
              onTap: () {
                onTap!();
              },
            );
    });
  }
}
