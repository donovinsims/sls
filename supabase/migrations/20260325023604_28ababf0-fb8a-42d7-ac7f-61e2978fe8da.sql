ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS stripe_session_id text;
ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS fulfillment_status text NOT NULL DEFAULT 'none';
ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS amount_paid integer;
ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS plan_type text;