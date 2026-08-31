import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// An OTP (one-time password) / verification code input.
///
/// Displays [length] individual boxes that auto-advance as the user types.
class LingOtpInput extends StatefulWidget {
  final int length;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onCompleted;
  final double boxSize;
  final double spacing;
  final bool obscureText;
  final TextInputType keyboardType;
  final Color? activeBorderColor;
  final Color? filledBorderColor;

  const LingOtpInput({
    super.key,
    this.length = 6,
    required this.onChanged,
    this.onCompleted,
    this.boxSize = 48,
    this.spacing = 12,
    this.obscureText = false,
    this.keyboardType = TextInputType.number,
    this.activeBorderColor,
    this.filledBorderColor,
  });

  @override
  State<LingOtpInput> createState() => _LingOtpInputState();
}

class _LingOtpInputState extends State<LingOtpInput> {
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;
  late List<String> _values;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) => FocusNode());
    _values = List.generate(widget.length, (_) => '');
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _onChanged(int index, String value) {
    if (value.length > 1) {
      // Paste handling — distribute characters across boxes
      final chars = value.split('');
      for (int i = 0; i < widget.length && i < chars.length; i++) {
        _values[i] = chars[i];
        _controllers[i].text = chars[i];
      }
      final nextEmpty = _values.indexWhere((v) => v.isEmpty);
      if (nextEmpty != -1) {
        _focusNodes[nextEmpty].requestFocus();
      } else {
        _focusNodes.last.unfocus();
      }
      _notifyChanged();
      return;
    }

    _values[index] = value;
    if (value.isNotEmpty && index < widget.length - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    _notifyChanged();
  }

  void _onKey(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
      _values[index - 1] = '';
      _controllers[index - 1].clear();
      _notifyChanged();
    }
  }

  void _notifyChanged() {
    final code = _values.join();
    widget.onChanged(code);
    if (code.length == widget.length && !code.contains('')) {
      widget.onCompleted?.call(code);
    }
  }

  void clear() {
    for (int i = 0; i < widget.length; i++) {
      _values[i] = '';
      _controllers[i].clear();
    }
    _focusNodes.first.requestFocus();
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate box size to fit available width
        final maxBoxSize = (constraints.maxWidth - (widget.length - 1) * widget.spacing) / widget.length;
        final boxSize = widget.boxSize < maxBoxSize ? widget.boxSize : maxBoxSize.clamp(32.0, 56.0);

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.length, (index) {
            return Container(
              width: boxSize,
              height: boxSize,
              margin: EdgeInsets.only(right: index < widget.length - 1 ? widget.spacing : 0),
          child: Focus(
            focusNode: _focusNodes[index],
            onKeyEvent: (node, event) {
              _onKey(index, event);
              return KeyEventResult.ignored;
            },
            child: TextField(
              controller: _controllers[index],
              textAlign: TextAlign.center,
              keyboardType: widget.keyboardType,
              maxLength: 1,
              obscureText: widget.obscureText,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                counterText: '',
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _values[index].isNotEmpty
                        ? widget.filledBorderColor ?? theme.colorScheme.primary
                        : theme.colorScheme.outlineVariant,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: widget.activeBorderColor ?? theme.colorScheme.primary,
                    width: 2,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _values[index].isNotEmpty
                        ? widget.filledBorderColor ?? theme.colorScheme.primary.withOpacity(0.5)
                        : theme.colorScheme.outlineVariant,
                  ),
                ),
              ),
              onChanged: (v) => _onChanged(index, v),
            ),
          ),
        );
      }),
        );
      },
    );
  }
}
