-- Customers: users can read their own row
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own customer row"
ON public.customers FOR SELECT
TO authenticated
USING (email = lower(auth.jwt() ->> 'email'));

-- Videos: RLS enabled, no direct access needed (use RPC)
ALTER TABLE public.videos ENABLE ROW LEVEL SECURITY;

-- Video sessions: service role only
ALTER TABLE public.video_sessions ENABLE ROW LEVEL SECURITY;

-- Activity log: service role only
ALTER TABLE public.activity_log ENABLE ROW LEVEL SECURITY;