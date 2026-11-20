import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iq_otomobil/core/app_variant.dart';
import 'package:iq_otomobil/features/auth/presentation/providers/auth_provider.dart';
import 'package:iq_otomobil/core/theme/app_colors.dart';

enum _AuthTab { login, register, forgot }

/// شاشة موحّدة: دخول (هاتف + مرور) / حساب جديد / نسيت كلمة المرور — بدون مسار OTP القديم.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmNewPassCtrl = TextEditingController();

  _AuthTab _tab = _AuthTab.login;
  bool _otpPhase = false;
  late AnimationController _fadeCtrl;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: 300.ms);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _nameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPassCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmNewPassCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  String _normalizePhone(String raw) {
    var s = raw.trim().replaceAll(' ', '').replaceAll('-', '');
    if (s.startsWith('00')) s = '+${s.substring(2)}';
    if (s.startsWith('+')) return s;
    if (s.startsWith('0')) s = s.substring(1);
    return '+964$s';
  }

  String _targetRoute(AppVariant variant) => switch (variant) {
        AppVariant.admin => '/admin',
        AppVariant.promoter => '/promoter',
        AppVariant.user => '/',
      };

  void _resetOtpPhase() {
    setState(() {
      _otpPhase = false;
      _otpCtrl.clear();
    });
  }

  void _onTabChanged(_AuthTab t) {
    setState(() {
      _tab = t;
      _otpPhase = false;
      _otpCtrl.clear();
      if (t != _AuthTab.forgot) {
        _newPasswordCtrl.clear();
        _confirmNewPassCtrl.clear();
      }
    });
  }

  String _humanizeAuthError(Object? err) {
    if (err is OtpResendCooldownException) {
      final totalSeconds = err.remaining.inSeconds;
      final minutes = totalSeconds ~/ 60;
      final seconds = totalSeconds % 60;
      if (minutes > 0) {
        return 'تم إرسال رمز مسبقاً. يمكنك طلب رمز جديد بعد $minutes دقيقة'
            '${seconds > 0 ? ' و$seconds ثانية' : ''}.';
      }
      return 'تم إرسال رمز مسبقاً. يمكنك طلب رمز جديد بعد $seconds ثانية.';
    }

    final s = (err ?? 'حدث خطأ').toString();
    final l = s.toLowerCase();

    // Supabase / Auth common messages
    if (l.contains('invalid login credentials') ||
        l.contains('invalid_credentials') ||
        l.contains('wrong password') ||
        l.contains('invalid password') ||
        l.contains('not authorized') ||
        l.contains('invalid_grant')) {
      return 'رقم الهاتف أو كلمة المرور غير صحيحة.';
    }

    if (l.contains('already registered') ||
        l.contains('user already') ||
        l.contains('this number is already') ||
        l.contains('phone already') ||
        l.contains('registered') && l.contains('phone')) {
      return 'رقم الهاتف مستخدم مسبقاً. استخدم «تسجيل الدخول».';
    }

    if (l.contains('otp') && (l.contains('invalid') || l.contains('expired'))) {
      return 'رمز التحقق غير صحيح أو انتهت صلاحيته. أعد الإرسال وحاول مرة أخرى.';
    }

    if (l.contains('network') ||
        l.contains('socket') ||
        l.contains('timeout')) {
      return 'تعذر الاتصال بالشبكة. تأكد من الإنترنت ثم أعد المحاولة.';
    }

    // Preserve explicit Arabic app messages (StateError etc.)
    return s.replaceAll('Exception: ', '').replaceAll('StateError: ', '');
  }

  Future<void> _showErrorDialog(Object? err) async {
    if (!mounted) return;
    final msg = _humanizeAuthError(err);
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: cs.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.error.withValues(alpha: 0.25)),
                ),
                child: Icon(Icons.error_outline_rounded, color: cs.error),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'تعذر إتمام العملية',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          content: Text(
            msg,
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant, height: 1.45),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: cs.error,
                foregroundColor: cs.onError,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('حسناً'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitFlow() async {
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(authActionProvider.notifier);
    final variant = ref.read(appVariantProvider);
    final merchantLoginOnly = variant == AppVariant.promoter;
    final phone = _normalizePhone(_phoneCtrl.text);

    if (_tab == _AuthTab.login) {
      await notifier.loginWithPhonePassword(
        phone: phone,
        password: _passwordCtrl.text,
      );
      if (!mounted) return;
      final s = ref.read(authActionProvider);
      if (s is AsyncData) {
        context.go(_targetRoute(variant));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم تسجيل الدخول'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (s is AsyncError) {
        await _showErrorDialog(s.error);
      }
      return;
    }

    if (!_otpPhase) {
      if (merchantLoginOnly && _tab == _AuthTab.register) {
        throw StateError('إنشاء حساب غير متاح في تطبيق التاجر');
      }
      if (_tab == _AuthTab.register) {
        if (_passwordCtrl.text != _confirmPassCtrl.text) {
          await _showErrorDialog('كلمتا المرور غير متطابقتين');
          return;
        }
      }
      await notifier.requestOtp(
        phone: phone,
        fullName: _tab == _AuthTab.register ? _nameCtrl.text.trim() : null,
        intent: _tab == _AuthTab.register
            ? OtpIntent.registration
            : OtpIntent.passwordRecovery,
      );
      if (!mounted) return;
      final s = ref.read(authActionProvider);
      if (s is AsyncData) {
        setState(() => _otpPhase = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم إرسال كود التحقق'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (s is AsyncError) {
        await _showErrorDialog(s.error);
      }
      return;
    }

    if (_tab == _AuthTab.register) {
      if (_passwordCtrl.text != _confirmPassCtrl.text) return;
      await notifier.verifyOtp(
        phone: phone,
        token: _otpCtrl.text.trim(),
        intent: OtpIntent.registration,
        fullName: _nameCtrl.text.trim(),
        newPassword: _passwordCtrl.text,
      );
    } else if (_tab == _AuthTab.forgot) {
      if (_newPasswordCtrl.text != _confirmNewPassCtrl.text) {
        await _showErrorDialog('كلمتا المرور الجديدة غير متطابقتين');
        return;
      }
      await notifier.verifyOtp(
        phone: phone,
        token: _otpCtrl.text.trim(),
        intent: OtpIntent.passwordRecovery,
        newPassword: _newPasswordCtrl.text,
      );
    }

    if (!mounted) return;
    final state = ref.read(authActionProvider);

    if (state is AsyncData) {
      context.go(_targetRoute(variant));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (state is AsyncError) {
      final err = state.error;
      if (err is PendingMerchantSignup) {
        _resetOtpPhase();
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text(
              'تم إنشاء الحساب',
              textAlign: TextAlign.center,
            ),
            content: Text(
              err.message,
              textAlign: TextAlign.center,
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('حسناً'),
              ),
            ],
          ),
        );
        return;
      }
      await _showErrorDialog(err);
    }
  }

  String _titleText() {
    if (_otpPhase) {
      if (_tab == _AuthTab.forgot) return 'كلمة مرور جديدة';
      return 'أدخل رمز التحقق';
    }
    return switch (_tab) {
      _AuthTab.login => 'تسجيل الدخول',
      _AuthTab.register => 'إنشاء حساب',
      _AuthTab.forgot => 'استعادة كلمة المرور',
    };
  }

  String _subtitleText() {
    if (_otpPhase) {
      return 'أدخل الرمز المرسل ثم أكمل الخطوة';
    }
    return switch (_tab) {
      _AuthTab.login => 'رقم الهاتف وكلمة المرور',
      _AuthTab.register => 'الاسم ورقم الهاتف وكلمة المرور، ثم رمز التحقق',
      _AuthTab.forgot => 'سنرسل رمز تحقق ثم تضع كلمة مرور جديدة',
    };
  }

  String _primaryButtonLabel() {
    if (_tab == _AuthTab.login) return 'دخول';
    if (!_otpPhase) return 'إرسال رمز التحقق';
    return _tab == _AuthTab.forgot ? 'حفظ كلمة المرور' : 'إنشاء الحساب';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authActionProvider);
    final isLoading = state.isLoading;
    final theme = Theme.of(context);
    final variant = ref.watch(appVariantProvider);
    final merchantLoginOnly = variant == AppVariant.promoter;
    final allowName =
        variant == AppVariant.user || variant == AppVariant.promoter;

    if (merchantLoginOnly && _tab == _AuthTab.register) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onTabChanged(_AuthTab.login);
      });
    }

    final accent = theme.colorScheme.secondary;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: FadeTransition(
                opacity: _fadeCtrl,
                child: Form(
                  key: _formKey,
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 26, 22, 26),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!merchantLoginOnly &&
                              _tab != _AuthTab.forgot) ...[
                            SizedBox(
                              width: double.infinity,
                              child: SegmentedButton<_AuthTab>(
                                style: SegmentedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF1F5F9),
                                  selectedForegroundColor: Colors.white,
                                  selectedBackgroundColor: accent,
                                  foregroundColor: const Color(0xFF475569),
                                  side: BorderSide.none,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                    horizontal: 4,
                                  ),
                                ),
                                showSelectedIcon: false,
                                segments: const [
                                  ButtonSegment(
                                    value: _AuthTab.login,
                                    label: Text('دخول'),
                                    icon: Icon(Icons.login_rounded, size: 18),
                                  ),
                                  ButtonSegment(
                                    value: _AuthTab.register,
                                    label: Text('حساب جديد'),
                                    icon: Icon(Icons.person_add_alt_rounded,
                                        size: 18),
                                  ),
                                ],
                                selected: {_tab},
                                onSelectionChanged: (s) {
                                  _onTabChanged(s.first);
                                },
                              ),
                            ),
                            const SizedBox(height: 22),
                          ] else ...[
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: TextButton.icon(
                                onPressed: isLoading
                                    ? null
                                    : () => _onTabChanged(_AuthTab.login),
                                icon: Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  size: 16,
                                  color: accent,
                                ),
                                label: Text(
                                  'العودة لتسجيل الدخول',
                                  style: TextStyle(
                                    color: accent,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          Text(
                            _titleText(),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _subtitleText(),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF64748B),
                              height: 1.35,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 26),
                          if (_tab == _AuthTab.register &&
                              !_otpPhase &&
                              allowName) ...[
                            TextFormField(
                              controller: _nameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'الاسم',
                                prefixIcon: Icon(Icons.person_outline_rounded),
                              ),
                              validator: (v) =>
                                  (v == null || v.trim().length < 2)
                                      ? 'أدخل الاسم'
                                      : null,
                            ),
                            const SizedBox(height: 12),
                          ],
                          TextFormField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            enabled: !_otpPhase,
                            decoration: const InputDecoration(
                              labelText: 'رقم الهاتف',
                              hintText: 'مثال: 0770xxxxxxx أو +964770xxxxxxx',
                              prefixIcon: Icon(Icons.smartphone_rounded),
                            ),
                            validator: (v) => (v == null || v.trim().length < 8)
                                ? 'أدخل رقم صحيح'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          if (_tab == _AuthTab.login) ...[
                            TextFormField(
                              controller: _passwordCtrl,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'كلمة المرور',
                                prefixIcon: Icon(Icons.lock_outline_rounded),
                              ),
                              validator: (v) => (v == null || v.length < 6)
                                  ? 'ست أحرف على الأقل'
                                  : null,
                            ),
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: TextButton(
                                onPressed: isLoading
                                    ? null
                                    : () => _onTabChanged(_AuthTab.forgot),
                                style: TextButton.styleFrom(
                                  foregroundColor: accent,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'نسيت كلمة المرور؟',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: accent,
                                    fontWeight: FontWeight.w700,
                                    decoration: TextDecoration.underline,
                                    decorationColor:
                                        accent.withValues(alpha: 0.45),
                                  ),
                                ),
                              ),
                            ),
                          ],
                          if (_tab == _AuthTab.register && !_otpPhase) ...[
                            TextFormField(
                              controller: _passwordCtrl,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'كلمة المرور',
                                prefixIcon: Icon(Icons.lock_outline_rounded),
                              ),
                              validator: (v) => (v == null || v.length < 6)
                                  ? 'ست أحرف على الأقل'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _confirmPassCtrl,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'تأكيد كلمة المرور',
                                prefixIcon: Icon(Icons.verified_user_outlined),
                              ),
                              validator: (v) =>
                                  (v == null || v != _passwordCtrl.text)
                                      ? 'غير متطابقة'
                                      : null,
                            ),
                          ],
                          if (_tab == _AuthTab.forgot && _otpPhase) ...[
                            TextFormField(
                              controller: _otpCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'رمز التحقق',
                                prefixIcon: Icon(Icons.sms_outlined),
                              ),
                              validator: (v) =>
                                  (v == null || v.trim().length < 4)
                                      ? 'أدخل الرمز'
                                      : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _newPasswordCtrl,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'كلمة المرور الجديدة',
                                prefixIcon: Icon(Icons.lock_outline),
                              ),
                              validator: (v) => (v == null || v.length < 6)
                                  ? 'ست أحرف على الأقل'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _confirmNewPassCtrl,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'تأكيد كلمة المرور',
                                prefixIcon: Icon(Icons.lock_person_outlined),
                              ),
                              validator: (v) =>
                                  (v == null || v != _newPasswordCtrl.text)
                                      ? 'غير متطابقة'
                                      : null,
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                onPressed: isLoading
                                    ? null
                                    : () async {
                                        final p =
                                            _normalizePhone(_phoneCtrl.text);
                                        await ref
                                            .read(authActionProvider.notifier)
                                            .requestOtp(
                                              phone: p,
                                              intent:
                                                  OtpIntent.passwordRecovery,
                                            );
                                        if (!mounted) return;
                                        final r = ref.read(authActionProvider);
                                        if (r is AsyncData) {
                                          ScaffoldMessenger.of(this.context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  '✅ تم إعادة إرسال الكود'),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        } else if (r is AsyncError) {
                                          await _showErrorDialog(r.error);
                                        }
                                      },
                                child: const Text('إعادة إرسال الكود'),
                              ),
                            ),
                          ],
                          if (_tab == _AuthTab.register && _otpPhase) ...[
                            TextFormField(
                              controller: _otpCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'رمز التحقق',
                                prefixIcon: Icon(Icons.sms_outlined),
                              ),
                              validator: (v) =>
                                  (v == null || v.trim().length < 4)
                                      ? 'أدخل الرمز'
                                      : null,
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                onPressed: isLoading
                                    ? null
                                    : () async {
                                        final p =
                                            _normalizePhone(_phoneCtrl.text);
                                        await ref
                                            .read(authActionProvider.notifier)
                                            .requestOtp(
                                              phone: p,
                                              fullName: _nameCtrl.text.trim(),
                                              intent: OtpIntent.registration,
                                            );
                                        if (!mounted) return;
                                        final r = ref.read(authActionProvider);
                                        if (r is AsyncData) {
                                          ScaffoldMessenger.of(this.context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  '✅ تم إعادة إرسال الكود'),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        } else if (r is AsyncError) {
                                          await _showErrorDialog(r.error);
                                        }
                                      },
                                child: const Text('إعادة إرسال الكود'),
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: isLoading ? null : _submitFlow,
                              style: ElevatedButton.styleFrom(
                                elevation: 0,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(_primaryButtonLabel()),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_otpPhase)
                            TextButton(
                              onPressed: isLoading ? null : _resetOtpPhase,
                              child: const Text('تعديل الرقم أو الرجوع'),
                            ),
                        ],
                      ),
                    ),
                  )
                      .animate()
                      .slideY(begin: 0.2, end: 0, duration: 400.ms)
                      .fade(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
