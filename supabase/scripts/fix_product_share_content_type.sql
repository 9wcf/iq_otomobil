-- ═══════════════════════════════════════════════════════════════
-- إصلاح: المتصفح يعرض HTML كنص (Content-Type: text/plain)
-- نفّذ في Supabase Dashboard → SQL Editor → Run
-- ═══════════════════════════════════════════════════════════════

UPDATE storage.objects
SET metadata = jsonb_set(
  COALESCE(metadata, '{}'::jsonb),
  '{mimetype}',
  '"text/html"'::jsonb
)
WHERE bucket_id = 'app-links'
  AND name = 'product-share.html';

-- تحقق بعد التنفيذ (يجب أن يظهر mimetype = text/html):
SELECT name, metadata->>'mimetype' AS mimetype
FROM storage.objects
WHERE bucket_id = 'app-links'
  AND name = 'product-share.html';
