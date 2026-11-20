# روابط مشاركة المنتجات

## لماذا كان يظهر كود HTML؟

Supabase Edge Functions **تجبر** الاستجابة على:
```
Content-Type: text/plain
Content-Security-Policy: sandbox
```
لذلك المتصفح **لا يعرض HTML** — يظهر الكود كنص. هذا قيد من Supabase وليس من التطبيق.

## الحل الحالي: إعادة توجيه (302) ✅

Edge Function **لا ترسل HTML** — ترسل redirect مباشر:

| الجهاز | ماذا يحدث |
|--------|-----------|
| **أندرويد + التطبيق مثبّت** | يفتح التطبيق → صفحة المنتج |
| **أندرويد + غير مثبّت** | يحوّل لـ Google Play |
| **آيفون + مثبّت** | يفتح التطبيق |
| **آيفون + غير مثبّت** | يحاول فتح التطبيق (قد يفشل → App Store يدوياً) |

## تحديث Edge Function

1. **Edge Functions** → **product-share** → **Code**
2. الصق كود: `supabase/functions/product-share/index.ts`
3. **Deploy updates**
4. **Settings** → JWT = **OFF**

## اختبار

### على الكمبيوتر (redirect):
```
https://hnndxfgfvrwfccxeywel.supabase.co/functions/v1/product-share?id=TEST
```
→ يحوّل لـ Google Play (طبيعي على PC)

### على أندرويد:
- **مثبّت:** يفتح التطبيق مباشرة
- **غير مثبّت:** Google Play

### adb (اختبار التطبيق):
```bash
adb shell am start -a android.intent.action.VIEW -d "https://hnndxfgfvrwfccxeywel.supabase.co/functions/v1/product-share?id=PRODUCT_ID"
```

## Storage (app-links)

لم يعد مطلوباً — يمكن حذف bucket `app-links`.
