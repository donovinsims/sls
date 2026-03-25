CREATE TABLE public.purchases (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  stripe_session_id TEXT NOT NULL UNIQUE,
  stripe_customer_id TEXT,
  customer_id UUID REFERENCES public.customers(id) ON DELETE SET NULL,
  email TEXT NOT NULL,
  course_key TEXT NOT NULL DEFAULT 'sls-vault',
  stripe_price_id TEXT,
  stripe_product_id TEXT,
  amount_paid INTEGER,
  currency TEXT,
  payment_status TEXT NOT NULL DEFAULT 'pending',
  fulfillment_status TEXT NOT NULL DEFAULT 'pending',
  session_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  processed_at TIMESTAMPTZ,
  buyer_confirmation_sent_at TIMESTAMPTZ,
  buyer_access_sent_at TIMESTAMPTZ,
  admin_notified_at TIMESTAMPTZ,
  manual_review_reason TEXT,
  last_error TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.purchases ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Service role full access purchases"
  ON public.purchases
  FOR ALL
  USING (auth.role() = 'service_role');

CREATE TABLE public.course_access_grants (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  customer_id UUID NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
  course_key TEXT NOT NULL,
  source_purchase_id UUID REFERENCES public.purchases(id) ON DELETE SET NULL,
  granted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  revoked_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT course_access_grants_customer_course_unique UNIQUE (customer_id, course_key)
);

ALTER TABLE public.course_access_grants ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Service role full access course_access_grants"
  ON public.course_access_grants
  FOR ALL
  USING (auth.role() = 'service_role');

UPDATE public.videos
SET sort_order = sort_order + 100
WHERE sort_order >= 1;

UPDATE public.videos
SET
  sort_order = 1,
  title = 'START HERE!',
  module = 'Foundations',
  youtube_id = 'rfO1GFfeYRE'
WHERE sort_order = 0;

UPDATE public.videos
SET sort_order = sort_order - 99
WHERE sort_order >= 101;
