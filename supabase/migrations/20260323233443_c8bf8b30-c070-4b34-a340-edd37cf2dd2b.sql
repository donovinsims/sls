
DROP FUNCTION IF EXISTS public.get_course_videos();

CREATE OR REPLACE FUNCTION public.get_course_videos()
RETURNS TABLE (
  id UUID,
  title TEXT,
  description TEXT,
  sort_order INT,
  module TEXT,
  summary TEXT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT v.id, v.title, v.description, v.sort_order, v.module, v.summary
  FROM public.videos v
  ORDER BY v.sort_order ASC;
$$;
