-- Shift all existing video sort_orders up by 1 to make room for the new video
UPDATE public.videos SET sort_order = sort_order + 1 WHERE sort_order >= 1;

-- Rename old "Welcome & Course Overview" (now sort_order 2) to "Course Overview"
UPDATE public.videos SET title = 'Course Overview' WHERE sort_order = 2 AND title = 'Welcome & Course Overview';

-- Insert the new "START HERE!" video at sort_order 1
INSERT INTO public.videos (sort_order, title, module, youtube_id, description, summary, transcript)
VALUES (
  1,
  'START HERE!',
  'Foundations',
  'rfO1GFfeYRE',
  'Your first step into the SLS Trading course. Watch this before anything else.',
  'This is your starting point. Before you dive into charts, setups, or strategies, this video sets the stage for everything that follows. You will learn how to get the most out of this course, what to expect from each module, and the right mindset to bring to your first lesson. Think of this as your orientation — a few minutes that will save you hours of confusion later.',
  ''
);