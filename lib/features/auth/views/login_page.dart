import 'dart:math' as math;
import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _loading = false;
  String? _error;
  int _failedAttempts = 0;
  DateTime? _lockoutUntil;

  late final AnimationController _blobController;

  @override
  void initState() {
    super.initState();
    _blobController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _blobController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_loading) return;

    // Input validation
    if (_emailController.text.trim().isEmpty) {
      setState(() => _error = 'emailRequired'.tr());
      return;
    }
    if (_passwordController.text.trim().isEmpty) {
      setState(() => _error = 'passwordRequired'.tr());
      return;
    }

    // Rate limiting
    final now = DateTime.now();
    if (_lockoutUntil != null && now.isBefore(_lockoutUntil!)) {
      final remaining = _lockoutUntil!.difference(now).inSeconds;
      setState(() => _error = 'tooManyAttempts'.tr(namedArgs: {'seconds': '$remaining'}));
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref
          .read(authProvider.notifier)
          .signIn(_emailController.text, _passwordController.text);
      _failedAttempts = 0;
      _lockoutUntil = null;
    } catch (e) {
      if (!mounted) return;
      _failedAttempts++;
      if (_failedAttempts >= 5) {
        _lockoutUntil = DateTime.now().add(const Duration(seconds: 30));
        _failedAttempts = 0;
      }
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggleLanguage() {
    final current = context.locale;
    if (current.languageCode == 'en') {
      context.setLocale(const Locale('th'));
    } else {
      context.setLocale(const Locale('en'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.bgBody,
      body: Stack(
        children: [
          // Floating background blobs
          _buildBlobs(size),

          // Language switcher
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            right: 16,
            child: _LanguageChip(onTap: _toggleLanguage),
          ),

          // Main content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(24, 0, 24, bottom + 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 16),
                      _buildLogo(),
                      const SizedBox(height: 24),
                      _buildCard(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlobs(Size size) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _blobController,
        builder: (context, _) {
          final t = _blobController.value;
          return Stack(
            children: [
              // Top Left Blob (Lavender Blue)
              Positioned(
                top: -size.height * 0.15 + (size.height * 0.08) * math.sin(t * 2 * math.pi),
                left: -size.width * 0.15 + (size.width * 0.1) * math.cos(t * 4 * math.pi),
                child: _Blob(
                  size: size.width * 0.7,
                  color: const Color(0x44A8C0FF),
                ),
              ),
              // Bottom Right Blob (Cotton Candy Pink)
              Positioned(
                bottom: -size.height * 0.2 + (size.height * 0.1) * math.cos(t * 2 * math.pi + 1.0),
                right: -size.width * 0.2 + (size.width * 0.08) * math.sin(t * 3 * math.pi),
                child: _Blob(
                  size: size.width * 0.85,
                  color: const Color(0x44FFD1E1),
                ),
              ),
              // Middle Soft Glow Blob (Warm Purple/Peach mix)
              Positioned(
                top: size.height * 0.3 + (size.height * 0.05) * math.sin(t * 3 * math.pi + 2.0),
                left: size.width * 0.2 + (size.width * 0.06) * math.cos(t * 2 * math.pi + 0.5),
                child: _Blob(
                  size: size.width * 0.6,
                  color: const Color(0x22D6BCFA),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                offset: const Offset(0, 12),
                blurRadius: 32,
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/logo.webp',
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Wonder Kids',
          style: AppTextStyles.displayLg.copyWith(
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'schoolTagline'.tr(),
          style: AppTextStyles.bodySm.copyWith(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radius2xl),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppColors.glassCardWhite,
            borderRadius: BorderRadius.circular(AppTheme.radius2xl),
            border: Border.all(color: AppColors.glassBorder),
            boxShadow: const [
              BoxShadow(
                offset: Offset(0, 20),
                blurRadius: 40,
                color: Color(0x146C5CE7),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                'signIn'.tr(),
                style: AppTextStyles.displayMd,
              ),
              const SizedBox(height: 28),
              _buildInput(
                controller: _emailController,
                focusNode: _emailFocus,
                label: 'username'.tr(),
                placeholder: 'usernamePlaceholder'.tr(),
                nextFocus: _passwordFocus,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 18),
              _buildInput(
                controller: _passwordController,
                focusNode: _passwordFocus,
                label: 'password'.tr(),
                placeholder: '••••••••',
                obscure: true,
                onSubmit: _handleLogin,
                textInputAction: TextInputAction.go,
              ),
              const SizedBox(height: 28),
              _buildSubmitButton(),
              if (_error != null) ...[
                const SizedBox(height: 16),
                _buildError(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String placeholder,
    bool obscure = false,
    FocusNode? nextFocus,
    VoidCallback? onSubmit,
    TextInputAction textInputAction = TextInputAction.done,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12, bottom: 6),
          child: Text(
            label,
            style: AppTextStyles.bodySm.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        _GummyTextField(
          controller: controller,
          focusNode: focusNode,
          placeholder: placeholder,
          obscure: obscure,
          textInputAction: textInputAction,
          onSubmitted: onSubmit != null
              ? (_) => onSubmit()
              : nextFocus != null
                  ? (_) => nextFocus.requestFocus()
                  : null,
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: AppTheme.touchComfortable,
      child: _GummyButton(
        onPressed: _loading ? null : _handleLogin,
        child: _loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.textOnPrimary,
                ),
              )
            : Text('signInBtn'.tr(), style: AppTextStyles.buttonLg),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.dangerLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Text(
        _error!,
        style: AppTextStyles.bodySm.copyWith(
          color: AppColors.danger,
          fontWeight: FontWeight.w700,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// --- Private widgets ---

class _GummyTextField extends StatefulWidget {
  const _GummyTextField({
    required this.controller,
    required this.focusNode,
    required this.placeholder,
    this.obscure = false,
    this.textInputAction = TextInputAction.done,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String placeholder;
  final bool obscure;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  State<_GummyTextField> createState() => _GummyTextFieldState();
}

class _GummyTextFieldState extends State<_GummyTextField>
    with TickerProviderStateMixin {
  bool _focused = false;
  late bool _obscureText;
  late final AnimationController _eyeController;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.obscure;
    widget.focusNode.addListener(_onFocusChange);
    _eyeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    if (!_obscureText) {
      _eyeController.value = 1.0;
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    _eyeController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() => _focused = widget.focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _focused ? 1.02 : 1.0,
      duration: const Duration(milliseconds: 300),
      curve: const Cubic(0.34, 1.56, 0.64, 1.0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: _focused ? AppColors.bgCard : const Color(0xFFF8F9FC),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
            color: _focused ? AppColors.primary : Colors.transparent,
            width: 3,
          ),
          boxShadow: _focused
              ? [
                  BoxShadow(
                    offset: const Offset(0, 8),
                    blurRadius: 16,
                    color: AppColors.primary.withValues(alpha: 0.12),
                  ),
                ]
              : const [],
        ),
        child: TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          obscureText: _obscureText,
          textInputAction: widget.textInputAction,
          onSubmitted: widget.onSubmitted,
          style: AppTextStyles.bodyBase.copyWith(fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            hintText: widget.placeholder,
            hintStyle:
                AppTextStyles.bodyBase.copyWith(color: AppColors.textMuted),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            isCollapsed: true,
            suffixIcon: widget.obscure
                ? GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _obscureText = !_obscureText;
                        if (_obscureText) {
                          _eyeController.reverse();
                        } else {
                          _eyeController.forward();
                        }
                      });
                    },
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.9, end: 1.1).animate(
                        CurvedAnimation(parent: _eyeController, curve: Curves.bounceOut),
                      ),
                      child: Icon(
                        _obscureText
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: _focused ? AppColors.primary : AppColors.textMuted,
                        size: 20,
                      ),
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

class _GummyButton extends StatefulWidget {
  const _GummyButton({
    required this.onPressed,
    required this.child,
  });

  final VoidCallback? onPressed;
  final Widget child;

  @override
  State<_GummyButton> createState() => _GummyButtonState();
}

class _GummyButtonState extends State<_GummyButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        if (widget.onPressed != null) setState(() => _pressed = true);
      },
      onTapUp: (_) {
        if (widget.onPressed != null) {
          setState(() => _pressed = false);
          HapticFeedback.lightImpact();
          widget.onPressed!.call();
        }
      },
      onTapCancel: () {
        setState(() => _pressed = false);
      },
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: const Cubic(0.34, 1.56, 0.64, 1),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: const Cubic(0.34, 1.56, 0.64, 1),
          height: AppTheme.touchComfortable,
          transform: Matrix4.translationValues(0, _pressed ? 4.0 : 0.0, 0),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            boxShadow: _pressed
                ? const [
                    BoxShadow(
                      offset: Offset(0, 2),
                      blurRadius: 4,
                      color: Color(0x1A000000),
                    ),
                  ]
                : [
                    BoxShadow(
                      offset: const Offset(0, 12),
                      blurRadius: 24,
                      color: AppColors.primary.withValues(alpha: 0.24),
                    ),
                  ],
          ),
          alignment: Alignment.center,
          child: widget.child,
        ),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
          stops: const [0.0, 0.7],
        ),
      ),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode.toUpperCase();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.glassCardWhite,
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language, size: 16, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(
              lang,
              style: AppTextStyles.bodySm.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

