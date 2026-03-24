
CREATE TABLE public.video_progress (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id uuid NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
  video_id uuid NOT NULL REFERENCES public.videos(id) ON DELETE CASCADE,
  completed boolean NOT NULL DEFAULT false,
  last_watched_at timestamp with time zone NOT NULL DEFAULT now(),
  UNIQUE (customer_id, video_id)
);

ALTER TABLE public.video_progress ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Service role full access video_progress"
  ON public.video_progress
  FOR ALL
  TO public
  USING (auth.role() = 'service_role');

CREATE POLICY "Authenticated users can read own progress"
  ON public.video_progress
  FOR SELECT
  TO authenticated
  USING (
    customer_id IN (
      SELECT id FROM public.customers WHERE email = lower(auth.jwt() ->> 'email')
    )
  );

CREATE POLICY "Authenticated users can upsert own progress"
  ON public.video_progress
  FOR INSERT
  TO authenticated
  WITH CHECK (
    customer_id IN (
      SELECT id FROM public.customers WHERE email = lower(auth.jwt() ->> 'email')
    )
  );

CREATE POLICY "Authenticated users can update own progress"
  ON public.video_progress
  FOR UPDATE
  TO authenticated
  USING (
    customer_id IN (
      SELECT id FROM public.customers WHERE email = lower(auth.jwt() ->> 'email')
    )
  );
