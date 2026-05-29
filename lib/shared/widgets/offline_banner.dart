import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_text_styles.dart';

class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _slideAnim;
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _isOffline = false;
  bool _showBackOnline = false;
  Timer? _backOnlineTimer;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);

    _sub = Connectivity().onConnectivityChanged.listen(_onChanged);
    Connectivity().checkConnectivity().then(_onChanged);
  }

  void _onChanged(List<ConnectivityResult> results) {
    final offline = results.every((r) => r == ConnectivityResult.none);
    if (offline == _isOffline) return;

    final wasOffline = _isOffline;
    setState(() => _isOffline = offline);

    if (offline) {
      _backOnlineTimer?.cancel();
      setState(() => _showBackOnline = false);
      _animCtrl.forward();
    } else {
      // Coming back online after being offline
      if (wasOffline) {
        setState(() => _showBackOnline = true);
        _backOnlineTimer?.cancel();
        _backOnlineTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) {
            _animCtrl.reverse();
            // Reset back-online state after animation completes
            Future.delayed(const Duration(milliseconds: 350), () {
              if (mounted) setState(() => _showBackOnline = false);
            });
          }
        });
      } else {
        _animCtrl.reverse();
      }
    }
  }

  @override
  void dispose() {
    _backOnlineTimer?.cancel();
    _sub?.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final IconData icon;
    final String text;

    if (_isOffline) {
      bgColor = const Color(0xFFF59E0B); // Yellow/amber
      icon = Icons.wifi_off_rounded;
      text = 'offlineWarning'.tr();
    } else if (_showBackOnline) {
      bgColor = const Color(0xFF22C55E); // Green
      icon = Icons.wifi_rounded;
      text = 'backOnline'.tr();
    } else {
      bgColor = const Color(0xFFF59E0B);
      icon = Icons.wifi_off_rounded;
      text = 'offlineWarning'.tr();
    }

    return SizeTransition(
      sizeFactor: _slideAnim,
      axisAlignment: -1,
      child: Material(
        color: bgColor,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(
                  text,
                  style: AppTextStyles.bodyBoldSm
                      .copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
