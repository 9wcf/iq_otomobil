import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const PLAY_STORE =
  "https://play.google.com/store/apps/details?id=iq.iqotomobil";
const APP_STORE = "https://apps.apple.com/search?term=IQ+OTOMBIL";
const CUSTOM_SCHEME = "iqotomobil";
const ANDROID_PACKAGE = "iq.iqotomobil";

function sanitizeProductId(raw: string): string {
  return raw.replace(/[<>&"'`\s]/g, "").trim();
}

function androidIntentUrl(productId: string): string {
  const encoded = encodeURIComponent(productId);
  return (
    `intent://product/${encoded}` +
    `#Intent;scheme=${CUSTOM_SCHEME};package=${ANDROID_PACKAGE}` +
    `;S.browser_fallback_url=${encodeURIComponent(PLAY_STORE)};end`
  );
}

function iosDeepLink(productId: string): string {
  return `${CUSTOM_SCHEME}://product/${encodeURIComponent(productId)}`;
}

Deno.serve((req: Request) => {
  const url = new URL(req.url);
  const productId = sanitizeProductId(url.searchParams.get("id") ?? "");

  if (!productId) {
    return new Response("Missing ?id=PRODUCT_ID", { status: 400 });
  }

  const ua = req.headers.get("user-agent") ?? "";

  // Supabase Edge Functions لا تدعم عرض HTML (Content-Type يُجبر على text/plain).
  // الحل: إعادة توجيه مباشرة — يفتح التطبيق أو المتجر بدون صفحة وسيطة.
  if (/android/i.test(ua)) {
    return Response.redirect(androidIntentUrl(productId), 302);
  }

  if (/iphone|ipad|ipod/i.test(ua)) {
    return Response.redirect(iosDeepLink(productId), 302);
  }

  return Response.redirect(PLAY_STORE, 302);
});
