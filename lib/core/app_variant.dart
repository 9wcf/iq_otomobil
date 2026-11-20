import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppVariant { user, promoter, admin }

extension AppVariantX on AppVariant {
  String get flavorName => switch (this) {
        AppVariant.user => 'user',
        AppVariant.promoter => 'promoter',
        AppVariant.admin => 'admin',
      };

  String get appTitle => switch (this) {
        AppVariant.user => 'IQ OTOMBIL',
        AppVariant.promoter => 'IQ OTOMBIL - تاجر',
        AppVariant.admin => 'IQ OTOMBIL - أدمن',
      };
}

AppVariant appVariantFromFlavor(String value) => switch (value.trim()) {
      'user' => AppVariant.user,
      'promoter' => AppVariant.promoter,
      'admin' => AppVariant.admin,
      _ => AppVariant.user,
    };

/// Must be overridden from each entrypoint (`main_*.dart`).
final appVariantProvider = Provider<AppVariant>((_) {
  throw StateError(
    'appVariantProvider must be overridden. Use main_user.dart / main_promoter.dart / main_admin.dart',
  );
});

