import 'package:flutter/widgets.dart';

/// Extensions on [Widget] for convenient layout modifiers.
extension WidgetExtensions on Widget {
  /// Add padding around the widget.
  Widget paddingAll(double value) => Padding(padding: EdgeInsets.all(value), child: this);

  Widget paddingSymmetric({double horizontal = 0, double vertical = 0}) =>
      Padding(padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical), child: this);

  Widget paddingOnly({double left = 0, double top = 0, double right = 0, double bottom = 0}) =>
      Padding(padding: EdgeInsets.only(left: left, top: top, right: right, bottom: bottom), child: this);

  /// Add margin around the widget.
  Widget marginAll(double value) => Container(margin: EdgeInsets.all(value), child: this);

  Widget marginSymmetric({double horizontal = 0, double vertical = 0}) =>
      Container(margin: EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical), child: this);

  /// Center the widget.
  Widget centered() => Center(child: this);

  /// Expand the widget.
  Widget expanded({int flex = 1}) => Expanded(flex: flex, child: this);

  /// Make the widget flexible.
  Widget flexible({int flex = 1, FlexFit fit = FlexFit.loose}) =>
      Flexible(flex: flex, fit: fit, child: this);

  /// Clip with rounded corners.
  Widget clipRRect(double radius) => ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: this,
      );

  /// Clip to circle.
  Widget clipCircle() => ClipOval(child: this);

  /// Add a visible border.
  Widget withBorder({Color color = const Color(0xFFE2E8F0), double width = 1}) => Container(
        decoration: BoxDecoration(
          border: Border.all(color: color, width: width),
        ),
        child: this,
      );
}
