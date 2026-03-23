-- Create customers table
CREATE TABLE public.customers (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  email TEXT NOT NULL UNIQUE,
  stripe_customer_id TEXT UNIQUE,
  course_access BOOLEAN NOT NULL DEFAULT false,
  purchased_at TIMESTAMP WITH TIME ZONE,
  access_expires_at TIMESTAMP WITH TIME ZONE
);

ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Customers can read own row" ON public.customers
  FOR SELECT USING (auth.jwt() ->> 'email' = email);

CREATE POLICY "Service role full access customers" ON public.customers
  FOR ALL USING (auth.role() = 'service_role');

-- Create videos table
CREATE TABLE public.videos (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  youtube_id TEXT NOT NULL,
  sort_order INT NOT NULL,
  module TEXT NOT NULL
);

ALTER TABLE public.videos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "No direct video access" ON public.videos
  FOR SELECT USING (false);

CREATE POLICY "Service role full access videos" ON public.videos
  FOR ALL USING (auth.role() = 'service_role');

-- Create video_sessions table
CREATE TABLE public.video_sessions (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  customer_id UUID NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
  video_id UUID NOT NULL REFERENCES public.videos(id) ON DELETE CASCADE,
  session_token TEXT NOT NULL UNIQUE,
  ip_address TEXT,
  device_fingerprint TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
  used BOOLEAN NOT NULL DEFAULT false
);

ALTER TABLE public.video_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Service role full access video_sessions" ON public.video_sessions
  FOR ALL USING (auth.role() = 'service_role');

-- Create activity_log table
CREATE TABLE public.activity_log (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  customer_id UUID NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
  video_id UUID NOT NULL REFERENCES public.videos(id) ON DELETE CASCADE,
  ip_address TEXT,
  event_type TEXT NOT NULL,
  watched_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

ALTER TABLE public.activity_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Service role full access activity_log" ON public.activity_log
  FOR ALL USING (auth.role() = 'service_role');

-- Create a secure RPC to list videos WITHOUT youtube_id
CREATE OR REPLACE FUNCTION public.get_course_videos()
RETURNS TABLE (
  id UUID,
  title TEXT,
  description TEXT,
  sort_order INT,
  module TEXT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT v.id, v.title, v.description, v.sort_order, v.module
  FROM public.videos v
  ORDER BY v.sort_order ASC;
$$;