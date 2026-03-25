DELETE FROM public.videos
WHERE sort_order = 0;

INSERT INTO public.videos (sort_order, title, module, youtube_id)
VALUES
  (1, 'START HERE!', 'Foundations', 'rfO1GFfeYRE'),
  (2, 'Course Overview', 'Foundations', 'e4vjMbwydN8'),
  (3, 'The Day Trader''s Mindset', 'Foundations', 'XbnxvNIzXos'),
  (4, 'Charts, Timeframes & Tools', 'Foundations', 'CsqWSTEDBss'),
  (5, 'Understanding Market Structure', 'Foundations', 'DtKYGHp0rbY'),
  (6, 'Support & Resistance Mastery', 'Market Structure', 'NGndbpyLVbE'),
  (7, 'S&R In Practice', 'Market Structure', 'FGri77Yq3tU'),
  (8, 'M''s & W''s / Chart Patterns', 'Market Structure', '54JAceqXhuM'),
  (9, 'BOS vs CHOC', 'Market Structure', '5Bn1H-fpmPY'),
  (10, 'High-Probability Entries', 'Entries & Setups', 'QPPtkoxELyQ'),
  (11, 'EMA Crossings & Signals', 'Entries & Setups', 'adVDa-wZoZg'),
  (12, 'Fair Value Gaps', 'Entries & Setups', 'e8OX64J0XW8'),
  (13, 'Confluence vs Strategy', 'Entries & Setups', '3Qxq1hGdASE'),
  (14, 'Managing Risk & Securing Profits', 'Risk Management', 'IQ1I4KTfMjs'),
  (15, 'Taking Profit Options', 'Risk Management', 'w3puLc0Ku38'),
  (16, 'Liquidity & Stop Placement', 'Risk Management', 'Ld9ex3dT4P8'),
  (17, 'Payout & Capital Protection', 'Risk Management', 'StAiMkpJgCo'),
  (18, 'Trading Continuation & Trend', 'Advanced Strategies', 'HkR7qQBXmig'),
  (19, 'Lock and Reload', 'Advanced Strategies', '7kjf4V0qFNw'),
  (20, 'Live Trade Walkthrough', 'Advanced Strategies', 'M0b_9EzBs-A'),
  (21, 'Prop Firms: Pros & Cons', 'Advanced Strategies', 'plLAKHHYgS4'),
  (22, 'Eliminate Burnout', 'Psychology & Review', '0vYM1-RyLjE'),
  (23, 'Eliminating Stress & Anxiety', 'Psychology & Review', 'qfYVtM8IKqc'),
  (24, 'Q&A Session 1', 'Psychology & Review', 'QJB-FS89g5Y'),
  (25, 'Q&A Session 2', 'Psychology & Review', 'eGxtA8SCPPQ')
ON CONFLICT (sort_order) DO UPDATE
SET
  title = EXCLUDED.title,
  module = EXCLUDED.module,
  youtube_id = EXCLUDED.youtube_id;
