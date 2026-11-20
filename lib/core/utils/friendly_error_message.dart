String friendlyErrorMessage(Object error) {
  final msg = error.toString();
  final lower = msg.toLowerCase();

  final isNetwork = lower.contains('socketexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('network is unreachable') ||
      lower.contains('connection failed') ||
      lower.contains('connection refused') ||
      lower.contains('timed out') ||
      lower.contains('timeout') ||
      lower.contains('clientexception');

  if (isNetwork) {
    return 'فشل الاتصال. تأكد من الإنترنت ثم أعد المحاولة.';
  }

  // Supabase auth refresh / session issues (common on unstable networks).
  if (msg.contains('AuthRetryableFetchException') ||
      lower.contains('refresh token') ||
      lower.contains('invalid refresh token') ||
      lower.contains('jwt')) {
    return 'تعذر إكمال العملية. يرجى إعادة تسجيل الدخول والمحاولة مرة أخرى.';
  }

  // Generic fallback without leaking raw stack/exception text.
  return 'حدث خطأ غير متوقع. حاول مرة أخرى.';
}

