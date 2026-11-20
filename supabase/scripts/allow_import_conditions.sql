-- ═══════════════════════════════════════════════════════════════
-- إضافة حالتي "وارد امريكي" و"وارد كوري" إلى قيد products.condition
-- نفّذ في Supabase Dashboard → SQL Editor → Run
-- (تم تنفيذه فعلاً على قاعدة الإنتاج — هذا الملف للتوثيق والتزامن مع أي بيئة أخرى)
-- ═══════════════════════════════════════════════════════════════

ALTER TABLE products DROP CONSTRAINT products_condition_check;

ALTER TABLE products ADD CONSTRAINT products_condition_check
  CHECK (condition = ANY (ARRAY[
    'new'::text,
    'used'::text,
    'refurbished'::text,
    'american_import'::text,
    'korean_import'::text
  ]));

-- تحقق بعد التنفيذ:
SELECT conname, pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conname = 'products_condition_check';
