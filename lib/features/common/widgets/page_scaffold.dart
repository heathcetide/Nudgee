import 'package:flutter/material.dart';

class PageScaffold extends StatefulWidget {
  final Widget title;
  final Widget child;
  final List<Map<String, dynamic>> actions;
  final List<Widget>? customActions;
  final Widget? leading;
  final Function? callback;
  const PageScaffold(
      {super.key,
      this.title = const Text('Untitled'),
      this.child = const Placeholder(),
      this.actions = const [],
      this.customActions = null,
      this.leading,
      this.callback});

  @override
  State<PageScaffold> createState() => _PageScaffoldState();
}

class _PageScaffoldState extends State<PageScaffold> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    List<Widget> actions = [];
    for (var element in widget.actions) {
      List<PopupMenuItem<String>> itemList = [];
      element['buttonList'].forEach((button) {
        itemList.add(PopupMenuItem<String>(
          value: button['key'],
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              if (button['icon'] != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: button['icon'],
                ),
              Text(button['text'])
            ],
          ),
        ));
      });
      actions.add(PopupMenuButton<String>(
        position: PopupMenuPosition.under,
        icon: Icon(
          Icons.more_vert,
          color: isDark ? Colors.white.withAlpha(222) : Colors.black.withAlpha(222),
        ),
        onSelected: (value) {
          if (widget.callback == null) return;
          widget.callback!(element['actionKey'], value);
        },
        itemBuilder: (context) {
          return itemList;
        },
      ));
    }
    return Scaffold(
      appBar: AppBar(
          leading: widget.leading,
          automaticallyImplyLeading: false,
          backgroundColor: isDark
              ? Theme.of(context).colorScheme.surface
              : Theme.of(context).colorScheme.inversePrimary,
          title: widget.title,
          elevation: 3,
          shadowColor: isDark ? Colors.black : Colors.black26,
          actions: widget.customActions == null ? actions : widget.customActions!),
      body: widget.child,
    );
  }
}

Widget getPopLeading(context) {
  return IconButton(
      onPressed: () {
        Navigator.maybePop(context);
      },
      icon: const Icon(Icons.arrow_back_ios_new));
}
