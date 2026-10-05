-- =============================================================================
-- BEEF — Migration 0006: Seed interests
-- Idempotent (ON CONFLICT DO NOTHING).
--
-- A small starting set of interest slugs for interest-led discovery ("The
-- Menu"). Kept deliberately brand-safe and non-explicit.
--
-- NOTE: synthetic demo PROFILES are seeded in a later phase with an `is_demo`
-- flag on users.signup_source, and stripped before store review. We never
-- fabricate real users. This file seeds taxonomy only.
-- =============================================================================

INSERT INTO interests (slug, label) VALUES
  ('gym-bros',      'Gym bros'),
  ('coffee-dates',  'Coffee dates'),
  ('hiking',        'Hiking'),
  ('brunch',        'Brunch'),
  ('film-buffs',    'Film buffs'),
  ('live-music',    'Live music'),
  ('gamers',        'Gamers'),
  ('art-galleries', 'Art galleries'),
  ('drag-shows',    'Drag shows'),
  ('dogs',          'Dog people'),
  ('travel',        'Travel'),
  ('foodies',       'Foodies'),
  ('book-club',     'Book club'),
  ('running',       'Running'),
  ('climbing',      'Climbing'),
  ('photography',   'Photography')
ON CONFLICT (slug) DO NOTHING;
