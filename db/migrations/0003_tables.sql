-- =============================================================================
-- BEEF — Migration 0003: Tables
-- Idempotent (CREATE TABLE IF NOT EXISTS). Depends on 0001 (extensions) and
-- 0002 (enums). Column comments encode the privacy-first invariants.
--
-- Privacy-first rules baked into the schema:
--   * users.birthdate is stored but NEVER selected into any API payload that
--     another user can read (enforced in application code).
--   * locations.precise_lat/lng/geog are server-side only: used for distance
--     computation, never exported. Grid queries run against coarse_geog.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Identity / auth
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  -- citext => case-insensitive uniqueness (and lookup) for email.
  email            citext NOT NULL UNIQUE,
  -- bcrypt/argon2 hash only — never plaintext. The application owns hashing.
  password_hash    text   NOT NULL
                   CONSTRAINT users_password_hash_not_empty CHECK (password_hash <> ''),
  -- Mandatory 18+ gate. Stored server-side; never returned to other users.
  birthdate        date   NOT NULL,
  -- Set once the user (re)confirms they are 18+ (onboarding gate).
  age_verified_at  timestamptz,
  status           user_status NOT NULL DEFAULT 'active',
  -- 'direct' | 'waitlist_import' | 'synthetic_demo' (demo profiles are flagged
  -- and stripped before store review — never fabricated as real users).
  signup_source    text   NOT NULL DEFAULT 'direct',
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Profiles (1:1 with users)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS profiles (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id                  uuid NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  display_name             text,
  bio                      text,
  -- The differentiator: "here for friends·chat·date·hookup".
  intent_tags              intent_tag[] NOT NULL DEFAULT '{}',
  -- "Certified Cut" badge state (selfie/KYC verification).
  photo_verification_status verification_status NOT NULL DEFAULT 'unverified',
  -- Coarse location mode chosen by the user: exact | city | region.
  coarse_location          coarse_location_mode NOT NULL DEFAULT 'city',
  -- hide_distance => distance shown as "nearby" only.
  hide_distance            boolean NOT NULL DEFAULT false,
  moderation_status        moderation_status NOT NULL DEFAULT 'pending',
  created_at               timestamptz NOT NULL DEFAULT now(),
  updated_at               timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Photos (UGC — start "pending" until the Sauce Check approves)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS profile_photos (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id       uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  -- Object-storage key. The URL is resolved by the server; never expose the
  -- raw bucket path to clients.
  storage_key      text NOT NULL,
  position         integer NOT NULL DEFAULT 0,
  is_primary       boolean NOT NULL DEFAULT false,
  status           photo_status NOT NULL DEFAULT 'pending',
  -- Optional moderation score from the cloud vision classifier (for review).
  moderation_score numeric,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Interests + join table (interest-led discovery)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS interests (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug       text NOT NULL UNIQUE,
  label      text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS profile_interests (
  profile_id  uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  interest_id uuid NOT NULL REFERENCES interests(id) ON DELETE CASCADE,
  created_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (profile_id, interest_id)
);

-- ---------------------------------------------------------------------------
-- Locations — the anti-Grindr architecture.
-- precise_* = server-side only (distance math), coarse_* = what the grid sees,
-- travel_*  = user-set travel point (server ignores live GPS when travel_mode).
-- The geography columns are kept in sync by triggers (0005) from the plain
-- lat/lng doubles so the application has one source of truth.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS locations (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  -- SERVER-SIDE ONLY. Never exported to ad SDKs or returned to other users.
  precise_lat  double precision,
  precise_lng  double precision,
  precise_geog geography(Point, 4326),
  -- Coarse centroid (city/region center) — the only thing the grid queries.
  coarse_lat   double precision,
  coarse_lng   double precision,
  coarse_geog  geography(Point, 4326),
  coarse_mode  coarse_location_mode NOT NULL DEFAULT 'city',
  travel_mode  boolean NOT NULL DEFAULT false,
  travel_lat   double precision,
  travel_lng   double precision,
  travel_geog  geography(Point, 4326),
  updated_at   timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Chat
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS chat_threads (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  last_message_at timestamptz
);

-- 1:1 thread dedupe: participant_low/high hold the sorted pair (least, greatest)
-- so the UNIQUE constraint collapses (A,B) and (B,A) into the same thread.
CREATE TABLE IF NOT EXISTS thread_participants (
  thread_id        uuid NOT NULL REFERENCES chat_threads(id) ON DELETE CASCADE,
  user_id          uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  participant_low  uuid NOT NULL,
  participant_high uuid NOT NULL,
  joined_at        timestamptz NOT NULL DEFAULT now(),
  last_read_at     timestamptz,
  PRIMARY KEY (thread_id, user_id),
  CONSTRAINT thread_participants_sorted_pair UNIQUE (participant_low, participant_high),
  CONSTRAINT thread_participants_pair_ordered CHECK (participant_low < participant_high)
);

-- client_message_id => idempotent send (retries don't duplicate).
CREATE TABLE IF NOT EXISTS chat_messages (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  thread_id         uuid NOT NULL REFERENCES chat_threads(id) ON DELETE CASCADE,
  sender_id         uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  client_message_id text NOT NULL,
  body              text NOT NULL CONSTRAINT chat_messages_body_not_empty CHECK (body <> ''),
  created_at        timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT chat_messages_idempotent UNIQUE (sender_id, client_message_id)
);

-- ---------------------------------------------------------------------------
-- Safety
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS blocks (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  blocker_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  blocked_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT blocks_uniq UNIQUE (blocker_id, blocked_id),
  CONSTRAINT blocks_no_self CHECK (blocker_id <> blocked_id)
);

CREATE TABLE IF NOT EXISTS reports (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reported_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  thread_id        uuid REFERENCES chat_threads(id) ON DELETE SET NULL,
  message_id       uuid REFERENCES chat_messages(id) ON DELETE SET NULL,
  report_type      report_type NOT NULL,
  reason           text,
  -- NCMEC CyberTipline: when is_csam is true, preserve evidence, disable the
  -- account, and submit; record the report id + status for the audit trail.
  is_csam          boolean NOT NULL DEFAULT false,
  ncmec_status     ncmec_status,
  ncmec_report_id  text,
  status           report_status NOT NULL DEFAULT 'open',
  created_at       timestamptz NOT NULL DEFAULT now(),
  resolved_at      timestamptz
);

CREATE TABLE IF NOT EXISTS moderation_queue (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  target_type         moderation_target NOT NULL,
  target_id           uuid NOT NULL,
  source              moderation_source NOT NULL DEFAULT 'auto',
  reason              text,
  status              moderation_queue_status NOT NULL DEFAULT 'pending',
  assigned_reviewer_id uuid REFERENCES users(id) ON DELETE SET NULL,
  created_at          timestamptz NOT NULL DEFAULT now(),
  reviewed_at         timestamptz
);

-- ---------------------------------------------------------------------------
-- Waitlist → user import target
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS waitlist_emails (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email       citext NOT NULL UNIQUE,
  source      text NOT NULL DEFAULT 'landing_page',
  -- Original submission timestamp from .run/waitlist.jsonl (preserved on import).
  original_ts timestamptz,
  imported_at timestamptz,
  -- pending | imported | invited. Import RESERVES the email for invite
  -- priority; it NEVER creates a pre-authenticated account (no password).
  status      text NOT NULL DEFAULT 'pending',
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Ads — v1 server-served native/direct + house only (no programmatic SDK).
-- Region-scoped server-side; the ad SDK never receives any location.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ad_inventory (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  advertiser_name       text NOT NULL,
  title                 text NOT NULL,
  body                  text,
  image_url             text,
  click_url             text,
  placement             ad_placement NOT NULL DEFAULT 'grid',
  kind                  ad_kind NOT NULL DEFAULT 'house',
  target_regions        text[] NOT NULL DEFAULT '{}',
  target_country_codes  text[] NOT NULL DEFAULT '{}',
  starts_at             timestamptz,
  ends_at               timestamptz,
  active                boolean NOT NULL DEFAULT false,
  created_at            timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Push (FCM/APNs via Firebase — wired in a later phase; table reserved now)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS push_tokens (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token        text NOT NULL,
  platform     push_platform NOT NULL DEFAULT 'android',
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  last_used_at timestamptz,
  CONSTRAINT push_tokens_uniq UNIQUE (user_id, token)
);
