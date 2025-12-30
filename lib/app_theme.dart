import 'package:flutter/material.dart';

class AppTheme {
  // Colori moderni con gradient
  static const primaryColor = Color(0xFF6C5DD3);
  static const secondaryColor = Color(0xFF7F56D9);
  static const accentColor = Color(0xFFFF6B9D);
  static const backgroundColor = Color(0xFF0F0F1E);
  static const surfaceColor = Color(0xFF1A1A2E);
  static const cardColor = Color(0xFF16213E);

  // Gradienti
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6C5DD3), Color(0xFF7F56D9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFFFF6B9D), Color(0xFFFF8E53)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [Color(0xFF0F0F1E), Color(0xFF1A1A2E)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Tema scuro moderno
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: backgroundColor,
    colorScheme: const ColorScheme.dark(
      primary: primaryColor,
      secondary: secondaryColor,
      surface: surfaceColor,
      background: backgroundColor,
    ),
    cardTheme: CardThemeData(
      color: cardColor,
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 8,
        shadowColor: primaryColor.withOpacity(0.5),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      titleMedium: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: Colors.white,
      ),
      bodyLarge: TextStyle(fontSize: 16, color: Colors.white70),
      bodyMedium: TextStyle(fontSize: 14, color: Colors.white60),
    ),
  );

  // Animazioni
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration longAnimationDuration = Duration(milliseconds: 500);

  static const Curve animationCurve = Curves.easeInOut;
  static const Curve springCurve = Curves.easeOutBack;
}

// Widget per effetti shimmer/loading
class ShimmerLoading extends StatefulWidget {
  final Widget child;

  const ShimmerLoading({Key? key, required this.child}) : super(key: key);

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(
      begin: -2,
      end: 2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: const [Colors.grey, Colors.white, Colors.grey],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment(_animation.value, 0),
              end: Alignment(_animation.value + 2, 0),
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

// Widget per card con effetto hover
class AnimatedCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;

  const AnimatedCard({Key? key, required this.child, this.onTap, this.margin})
    : super(key: key);

  @override
  State<AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<AnimatedCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: AppTheme.animationDuration,
        curve: AppTheme.springCurve,
        child: AnimatedContainer(
          duration: AppTheme.animationDuration,
          curve: AppTheme.animationCurve,
          margin: widget.margin,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(
                  _isPressed ? 0.2 : 0.3,
                ),
                blurRadius: _isPressed ? 10 : 20,
                offset: Offset(0, _isPressed ? 2 : 8),
              ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

// Widget per gradient button
class GradientButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final Gradient gradient;
  final double? width;
  final IconData? icon;

  const GradientButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.gradient = AppTheme.primaryGradient,
    this.width,
    this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 56,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white),
                  const SizedBox(width: 12),
                ],
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
