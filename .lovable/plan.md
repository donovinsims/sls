

# Workaround: Launch Without Stripe Secret Key

## The Problem
The `verify-purchase` Edge Function needs `STRIPE_SECRET_KEY` to call the Stripe API and confirm payment. Without it, the automated flow (pay → verify → grant access → send login link) is broken.

## Proposed Workaround: Manual Access Grant + Self-Service Success Page

Instead of automated server-side verification, we split the flow:

1. **Success page** — stops trying to verify with Stripe. Instead, it collects the customer's email and saves it to the `customers` table with `course_access = false` (a "pending" state), then shows a friendly message: *"Payment received! You'll get your login link within a few minutes."*

2. **Admin panel** — a simple `/admin` page (protected to your two admin emails only) where you can see pending customers and click "Grant Access" to flip `course_access = true` and trigger the magic link email. This takes ~5 seconds per customer.

3. **Later, when you have your Stripe key** — we add it and re-enable the fully automated flow. Zero code changes needed on the frontend; we just update the Edge Function.

## Additional Changes in This Plan

- **Add pricing to landing page**: Display "$149 (limited time)" with a note about the April 1 increase to $199
- **Fix Google OAuth redirect**: Change redirect to `/portal` instead of `/`
- **Sync landing page curriculum**: Pull modules from the database via `get_course_videos` RPC instead of hardcoded list
- **Fix YouTube ID exposure**: Stop returning raw `youtube_id` in the `get-video` JSON response — construct the embed URL server-side and return only the full embed URL (the ID is still technically in the URL, but we can obfuscate it further or proxy it later)
- **Style the 404 page** to match the design system

## Files to Create/Modify

| File | Change |
|------|--------|
| `src/pages/Success.tsx` | Replace Stripe verification with email collection form + pending customer insert |
| `src/pages/Admin.tsx` | New admin page — list pending customers, grant access button |
| `src/App.tsx` | Add `/admin` route |
| `src/pages/Index.tsx` | Add pricing section ($149 limited / $199 after April 1), fetch curriculum from DB |
| `src/pages/Login.tsx` | Fix OAuth redirect to `/portal` |
| `supabase/functions/get-video/index.ts` | Remove `youtube_id` from response, return only constructed embed URL |
| `src/pages/NotFound.tsx` | Match cream/gold design system |
| `supabase/functions/grant-access/index.ts` | New Edge Function — sets `course_access = true` and sends magic link (admin-only) |

## How It Works Day-to-Day (Until Stripe Key Is Added)

1. Customer clicks "Get Instant Access" → Stripe checkout
2. After paying, Stripe redirects to `/success` → customer enters their email → saved as pending
3. You get a Stripe payment notification (email/app) → open `/admin` → click "Grant Access"
4. Customer gets magic link email → logs in → watches videos

Total manual effort: ~10 seconds per sale.

