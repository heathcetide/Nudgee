import 'package:nudgee/features/common/widgets/image_box.dart';
import 'package:flutter/material.dart';

final Map<int, Map<String, int>> layouts = {
  1: {
    'rows': 1,
    'cols': 1,
  },
  2: {
    'rows': 1,
    'cols': 2,
  },
  3: {
    'rows': 1,
    'cols': 3,
  },
  4: {
    'rows': 2,
    'cols': 2,
  },
  5: {
    'rows': 2,
    'cols': 3,
  },
  6: {
    'rows': 2,
    'cols': 3,
  },
  7: {
    'rows': 3,
    'cols': 3,
  },
  8: {
    'rows': 3,
    'cols': 3,
  },
  9: {
    'rows': 3,
    'cols': 3,
  },
};

class NineSliceLayout extends StatefulWidget {
  final List<String>? urls;

  const NineSliceLayout({super.key, this.urls});

  @override
  State<NineSliceLayout> createState() => _NineSliceLayoutState();
}

class _NineSliceLayoutState extends State<NineSliceLayout> {
  @override
  Widget build(BuildContext context) {
    if (widget.urls!.length == 1) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return SizedBox(
            height: constraints.maxWidth * 0.66,
            width: constraints.maxWidth * 0.88,
            child: ImageBox(
              widget.urls![0],
              tag: widget.urls![0],
              fit: BoxFit.fitHeight,
              images: [
                {"url": widget.urls![0], 'tag': widget.urls![0]}
              ],
            ),
          );
        },
      );
    }
    return LayoutBuilder(builder: (context, BoxConstraints constraints) {
      return Column(
        children: [
          for (var i = 0; i < layouts[widget.urls!.length]!['rows']!; i++)
            Row(children: [
              for (var j = 0; j < layouts[widget.urls!.length]!['cols']!; j++)
                SizedBox(
                    width: constraints.maxWidth / 3,
                    height: constraints.maxWidth / 3,
                    child: i * layouts[widget.urls!.length]!['cols']! + j >= widget.urls!.length
                        ? SizedBox()
                        : Padding(
                            padding: const EdgeInsets.only(right: 3, bottom: 3),
                            child: ImageBox(
                              widget.urls![i * layouts[widget.urls!.length]!['cols']! + j],
                              index: i * layouts[widget.urls!.length]!['cols']! + j,
                              images: widget.urls!.map(
                                (e) {
                                  return {"url": e, "tag": e};
                                },
                              ).toList(),
                            ),
                          )),
            ])
        ],
      );
    });
  }
}
