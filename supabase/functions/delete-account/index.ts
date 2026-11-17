// Edge Function: حذف حساب المستخدم نهائياً
// النشر: من لوحة Supabase > Edge Functions > Create new function > delete-account
// ثم الصق هذا الكود، أو عبر CLI:
//   supabase functions deploy delete-account
//
// المتطلبات في Supabase:
// 1) جدولان موجودان: orders, reviews (عدّل الأسماء حسب مشروعك إن اختلفت)
// 2) المتغير البياني SERVICE_ROLE_KEY متوفر تلقائياً داخل Edge Functions

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

Deno.serve(async (req) => {
  try {
    const authHeader = req.headers.get('Authorization')!
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } }
    )

    const admin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    // هوية المستخدم من التوكن
    const { data: { user }, error: userError } = await supabase.auth.getUser()
    if (userError || !user) {
      return new Response(JSON.stringify({ error: 'غير مسجل الدخول' }), {
        status: 401,
        headers: { 'Content-Type': 'application/json' },
      })
    }

    // حذف بيانات المستخدم (عدّل الأسماء حسب جداولك الفعلية)
    await admin.from('reviews').delete().eq('user_id', user.id)
    await admin.from('orders').delete().eq('user_id', user.id)
    // إن كان عندك جدول profiles أو cart:
    // await admin.from('profiles').delete().eq('id', user.id)
    // await admin.from('cart').delete().eq('user_id', user.id)

    // حذف المستخدم نفسه من نظام المصادقة
    const { error: deleteError } = await admin.auth.admin.deleteUser(user.id)
    if (deleteError) throw deleteError

    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})
