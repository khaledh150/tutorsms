import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';

class GummyButton extends StatefulWidget {
  const GummyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = AppColors.primary,
    this.textColor = Colors.white,
    this.large = false,
    this.haptic = true,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;
  final Color textColor;
  final bool large;
  final bool haptic;
  final bool loading;

  @override
  State<GummyButton> createState() => _GummyButtonState();
}

class _GummyButtonState extends State<GummyButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 200),
      lowerBound: 0,
      upperBound: 1,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _ctrl.forward();

  void _onTapUp(TapUpDetails _) {
    _ctrl.reverse();
    if (widget.haptic) HapticFeedback.lightImpact();
    widget.onPressed?.call();
  }

  void _onTapCancel() => _ctrl.reverse();

  @override
  Widget build(BuildContext context) {
    final height = widget.large ? AppTheme.touchLarge : AppTheme.touchMin;
    final textStyle = widget.large
        ? AppTextStyles.buttonLg
        : AppTextStyles.buttonMd;

    return AnimatedBuilder(
      animation: _scale,
      builder: (context, child) => Transform.scale(
        scale: _scale.value,
        child: child,
      ),
      child: GestureDetector(
        onTapDown: widget.onPressed == null ? null : _onTapDown,
        onTapUp: widget.onPressed == null ? null : _onTapUp,
        onTapCancel: _onTapCancel,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: height,
          decoration: BoxDecoration(
            color: widget.onPressed == null
                ? widget.color.withValues(alpha: 0.5)
                : widget.color,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
          alignment: Alignment.center,
          child: widget.loading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: widget.textColor,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon,
                          color: widget.textColor, size: 20),
                      const SizedBox(width: 8),
                    ],
                    Text(widget.label,
                        style: textStyle.copyWith(
                            color: widget.textColor)),
                  ],
                ),
        ),
      ),
    );
  }
}
