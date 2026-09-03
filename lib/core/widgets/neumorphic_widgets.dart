import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Tactile elevated neumorphic container/card
class NeumorphicCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? color;
  final VoidCallback? onTap;
  final bool isPressed;
  final Border? border;

  const NeumorphicCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.borderRadius = 20,
    this.color,
    this.onTap,
    this.isPressed = false,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = color ?? AppTheme.surface;

    final decoration = BoxDecoration(
      color: cardColor,
      borderRadius: BorderRadius.circular(borderRadius),
      border: border,
      boxShadow: isPressed
          ? [
              const BoxShadow(
                color: AppTheme.shadowDark,
                offset: Offset(2, 2),
                blurRadius: 4,
              ),
              const BoxShadow(
                color: AppTheme.shadowLight,
                offset: Offset(-2, -2),
                blurRadius: 4,
              ),
            ]
          : AppTheme.neumorphicShadowElevated,
    );

    Widget content = Container(
      padding: padding,
      margin: margin,
      decoration: decoration,
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: content,
      );
    }

    return content;
  }
}

/// Tactile interactive neumorphic button with state animation
class NeumorphicButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Color? textColor;
  final bool isPrimary;
  final IconData? icon;

  const NeumorphicButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.borderRadius = 16,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    this.backgroundColor,
    this.textColor,
    this.isPrimary = false,
    this.icon,
  });

  @override
  State<NeumorphicButton> createState() => _NeumorphicButtonState();
}

class _NeumorphicButtonState extends State<NeumorphicButton> {
  bool _isDown = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null;
    final baseColor = widget.backgroundColor ??
        (widget.isPrimary ? AppTheme.primary : AppTheme.surface);

    return GestureDetector(
      onTapDown: isEnabled ? (_) => setState(() => _isDown = true) : null,
      onTapUp: isEnabled ? (_) => setState(() => _isDown = false) : null,
      onTapCancel: isEnabled ? () => setState(() => _isDown = false) : null,
      onTap: widget.onPressed,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: widget.padding,
        decoration: BoxDecoration(
          color: isEnabled ? baseColor : AppTheme.surfaceSunken,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          boxShadow: !isEnabled
              ? []
              : (_isDown
                  ? [
                      const BoxShadow(
                        color: AppTheme.shadowDark,
                        offset: Offset(2, 2),
                        blurRadius: 4,
                      ),
                      const BoxShadow(
                        color: AppTheme.shadowLight,
                        offset: Offset(-2, -2),
                        blurRadius: 4,
                      ),
                    ]
                  : AppTheme.neumorphicShadowElevated),
        ),
        child: DefaultTextStyle(
          style: TextStyle(
            color: widget.textColor ??
                (widget.isPrimary ? Colors.white : AppTheme.textPrimary),
            fontWeight: FontWeight.w700,
            fontSize: 15,
            letterSpacing: 0.3,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  size: 20,
                  color: widget.textColor ??
                      (widget.isPrimary ? Colors.white : AppTheme.textPrimary),
                ),
                const SizedBox(width: 8),
              ],
              widget.child,
            ],
          ),
        ),
      ),
    );
  }
}

/// Round neumorphic icon button (e.g. for back button, settings, refresh)
class NeumorphicIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final Color? iconColor;
  final Color? backgroundColor;
  final String? tooltip;

  const NeumorphicIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 48,
    this.iconColor,
    this.backgroundColor,
    this.tooltip,
  });

  @override
  State<NeumorphicIconButton> createState() => _NeumorphicIconButtonState();
}

class _NeumorphicIconButtonState extends State<NeumorphicIconButton> {
  bool _isDown = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null;

    Widget btn = GestureDetector(
      onTapDown: isEnabled ? (_) => setState(() => _isDown = true) : null,
      onTapUp: isEnabled ? (_) => setState(() => _isDown = false) : null,
      onTapCancel: isEnabled ? () => setState(() => _isDown = false) : null,
      onTap: widget.onPressed,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: widget.backgroundColor ?? AppTheme.surface,
          shape: BoxShape.circle,
          boxShadow: !isEnabled
              ? []
              : (_isDown
                  ? [
                      const BoxShadow(
                        color: AppTheme.shadowDark,
                        offset: Offset(2, 2),
                        blurRadius: 4,
                      ),
                      const BoxShadow(
                        color: AppTheme.shadowLight,
                        offset: Offset(-2, -2),
                        blurRadius: 4,
                      ),
                    ]
                  : AppTheme.neumorphicShadowElevated),
        ),
        child: Center(
          child: Icon(
            widget.icon,
            size: widget.size * 0.48,
            color: widget.iconColor ?? AppTheme.textPrimary,
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(message: widget.tooltip!, child: btn);
    }
    return btn;
  }
}

/// Status / Telemetry badge with soft neumorphic styling
class NeumorphicBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final Color? textColor;

  const NeumorphicBadge({
    super.key,
    required this.label,
    this.icon,
    this.color = AppTheme.primary,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textColor ?? color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
