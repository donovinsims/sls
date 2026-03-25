CREATE EXTENSION IF NOT EXISTS pgcrypto;

ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS stripe_session_id text;
ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS fulfillment_status text NOT NULL DEFAULT 'none';
ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS amount_paid integer;
ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS plan_type text;
ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS confirmation_email_sent_at timestamptz;
ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS admin_notified_at timestamptz;
ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS last_email_error text;

UPDATE public.customers
SET
  stripe_session_id = COALESCE(stripe_session_id, stripe_checkout_session_id),
  fulfillment_status = COALESCE(
    NULLIF(fulfillment_status, ''),
    CASE
      WHEN course_access THEN 'fulfilled'
      ELSE 'none'
    END
  )
WHERE
  stripe_session_id IS DISTINCT FROM COALESCE(stripe_session_id, stripe_checkout_session_id)
  OR fulfillment_status IS NULL
  OR fulfillment_status = '';

CREATE TABLE IF NOT EXISTS public.purchases (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  stripe_session_id text NOT NULL UNIQUE,
  stripe_customer_id text,
  customer_id uuid REFERENCES public.customers(id) ON DELETE SET NULL,
  email text NOT NULL,
  course_key text NOT NULL DEFAULT 'sls-vault',
  stripe_price_id text,
  stripe_product_id text,
  amount_paid integer,
  currency text,
  payment_status text NOT NULL DEFAULT 'pending',
  fulfillment_status text NOT NULL DEFAULT 'pending',
  session_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  processed_at timestamptz,
  buyer_confirmation_sent_at timestamptz,
  buyer_access_sent_at timestamptz,
  admin_notified_at timestamptz,
  manual_review_reason text,
  last_error text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.course_access_grants (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  customer_id uuid NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
  course_key text NOT NULL,
  source_purchase_id uuid REFERENCES public.purchases(id) ON DELETE SET NULL,
  granted_at timestamptz NOT NULL DEFAULT now(),
  revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT course_access_grants_customer_course_unique UNIQUE (customer_id, course_key)
);

ALTER TABLE public.purchases ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.course_access_grants ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'purchases'
      AND policyname = 'Service role full access purchases'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "Service role full access purchases"
      ON public.purchases
      FOR ALL
      USING (auth.role() = 'service_role')
    $policy$;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'course_access_grants'
      AND policyname = 'Service role full access course_access_grants'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "Service role full access course_access_grants"
      ON public.course_access_grants
      FOR ALL
      USING (auth.role() = 'service_role')
    $policy$;
  END IF;
END
$$;
