# صفحة مشاركة المنتجات — IQ OTOMBIL

انشر محتويات هذا المجلد على الدومين:

`https://link.iqotomobil.com`

## ماذا تفعل الصفحة؟

1. المستخدم يضغط رابط المنتج على واتساب.
2. إذا **التطبيق مثبّت** → يفتح مباشرة على صفحة المنتج.
3. إذا **غير مثبّت** → يحوّل تلقائياً إلى **Google Play** أو **App Store**.

## خطوات النشر

1. اربط الدومين `link.iqotomobil.com` باستضافة (Vercel / Netlify / Cloudflare Pages).
2. ارفع كل الملفات بما فيها مجلد `.well-known`.
3. حدّث `share_landing/index.html`:
   - `APP_STORE` برابط App Store الحقيقي.
4. حدّث `share_landing/.well-known/assetlinks.json`:
   - ضع بصمة SHA-256 لتوقيع التطبيق (Release).
   - الأمر: `keytool -list -v -keystore your-release.keystore`
5. حدّث `share_landing/.well-known/apple-app-site-association`:
   - استبدل `TEAMID` بمعرّف فريق Apple (مثل `N6S7Z2YLW9`).
6. في Apple Developer فعّل Associated Domains للتطبيق.

## اختبار

- رابط مشاركة: `https://link.iqotomobil.com/product/PRODUCT_ID`
- بدون تطبيق: يجب أن يفتح المتجر خلال ~2 ثانية.
- مع التطبيق: يفتح `ProductDetailScreen` مباشرة.

## تغيير الدومين

إذا استخدمت دوميناً آخر، عدّل:

- `lib/core/config/product_share_config.dart` → `shareHost`
- `android/app/src/main/AndroidManifest.xml` → `android:host`
- `ios/Runner/Runner.entitlements` → `applinks:YOUR_DOMAIN`
