import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iq_otomobil/core/services/app_runtime_controls_service.dart';
import 'package:iq_otomobil/core/theme/app_colors.dart';
import 'package:iq_otomobil/core/utils/product_deep_link.dart';
import 'package:iq_otomobil/features/splash/presentation/widgets/splash_visuals.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    this.title = 'IQ OTOMBIL',
    this.nextRoute = '/',
    this.logoAssetPath = 'assets/icon/app_icon.png',
    this.backgroundColor = AppColors.background,
    this.accentColor = AppColors.primary,
    this.showTitle = true,
  });

  final String title;
  final String nextRoute;
  final String logoAssetPath;
  final Color backgroundColor;
  final Color accentColor;
  final bool showTitle;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final AnimationController _ambientController;
  late final AnimationController _breathController;
  late final AnimationController _exitController;

  late final Animation<double> _logoEntrance;
  late final Animation<double> _titleProgress;
  late final SplashPalette _palette;

  bool _navigating = false;
  bool _iconPrecached = false;

  @override
  void initState() {
    super.initState();

    _palette = _resolvePalette();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    );
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8000),
    )..repeat();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );

    _logoEntrance = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.35, curve: Curves.easeOutCubic),
    );
    _titleProgress = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.28, 1.0, curve: Curves.linear),
    );

    _entranceController.addStatusListener((status) {
      if (status != AnimationStatus.completed || !mounted || _navigating) {
        return;
      }
      Future<void>.delayed(const Duration(milliseconds: 380), () {
        if (!mounted || _navigating) return;
        _beginExitAndNavigate();
      });
    });

    _entranceController.forward();
  }

  SplashPalette _resolvePalette() {
    final isDark = widget.backgroundColor.computeLuminance() < 0.25;
    if (isDark) {
      return SplashPalette.dark(
        background: widget.backgroundColor,
        accent: widget.accentColor,
      );
    }
    return SplashPalette.light(
      background: widget.backgroundColor,
      primary: widget.accentColor,
      accent: AppColors.accent,
    );
  }

  Future<void> _beginExitAndNavigate() async {
    if (_navigating) return;
    _navigating = true;
    await _exitController.forward();
    if (!mounted) return;
    await _navigateAfterSplash();
  }

  Future<void> _navigateAfterSplash() async {
    final deepLinkPath = ProductDeepLinkBootstrap.initialProductPath;
    if (deepLinkPath != null) {
      ProductDeepLinkBootstrap.clearInitial();
      if (mounted) context.go(deepLinkPath);
      return;
    }

    if (widget.nextRoute != '/') {
      if (mounted) context.go(widget.nextRoute);
      return;
    }
    try {
      final controls = await const AppRuntimeControlsService().fetch();
      if (!mounted) return;
      if (controls.maintenanceMode) {
        context.go('/maintenance');
        return;
      }
      if (controls.forceUpdateEnabled) {
        final info = await PackageInfo.fromPlatform();
        if (!mounted) return;
        final currentBuild = int.tryParse(info.buildNumber) ?? 0;
        if (currentBuild < controls.minSupportedBuild) {
          context.go('/force-update');
          return;
        }
      }
      if (!mounted) return;
      context.go(widget.nextRoute);
    } catch (_) {
      if (mounted) context.go(widget.nextRoute);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_iconPrecached) return;
    _iconPrecached = true;
    precacheImage(AssetImage(widget.logoAssetPath), context);
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _ambientController.dispose();
    _breathController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exitFade = 1 - Curves.easeInCubic.transform(_exitController.value);
    final logoSize = _logoSizeFor(context);
    final titleSize = _titleSizeFor(context);

    return Scaffold(
      backgroundColor: _palette.backgroundTop,
      body: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _ambientController,
              builder: (context, _) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    SplashGradientBackground(palette: _palette),
                    SplashAmbientLayer(
                      palette: _palette,
                      drift: _ambientController.value,
                    ),
                    SplashAutomotiveLayer(
                      palette: _palette,
                      drift: _ambientController.value,
                    ),
                  ],
                );
              },
            ),
          ),
          SafeArea(
            child: AnimatedBuilder(
              animation: Listenable.merge([
                _entranceController,
                _breathController,
                _exitController,
              ]),
              builder: (context, _) {
                return Opacity(
                  opacity: exitFade.clamp(0.0, 1.0),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SplashAnimatedLogo(
                            assetPath: widget.logoAssetPath,
                            palette: _palette,
                            entrance: _logoEntrance.value,
                            breath: _breathController.value,
                            shimmer: _breathController.value,
                            size: logoSize,
                          ),
                          if (widget.showTitle &&
                              widget.title.trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 32),
                              child: SplashCinematicTitle(
                                text: widget.title,
                                progress: _titleProgress.value,
                                palette: _palette,
                                fontSize: titleSize,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  double _logoSizeFor(BuildContext context) {
    final shortest = MediaQuery.sizeOf(context).shortestSide;
    if (shortest < 340) return 92;
    if (shortest < 400) return 104;
    return 116;
  }

  double _titleSizeFor(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 340) return 16;
    if (width < 400) return 18;
    return 20;
  }
}
