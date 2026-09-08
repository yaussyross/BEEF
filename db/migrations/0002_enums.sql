-- =============================================================================
-- BEEF — Migration 0002: Enum types
-- Idempotent: CREATE TYPE has no IF NOT EXISTS, so each enum is created inside
-- a DO block that no-ops when the type already exists.
-- =============================================================================

DO $$ BEGIN
  CREATE TYPE user_status AS ENUM ('active', 'deleted', 'suspended', 'banned');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  -- "here for ..." tags. The product differentiator: friends|chat|date|hookup.
  CREATE TYPE intent_tag AS ENUM ('friends', 'chat', 'date', 'hookup');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  -- Coarse location mode. Grid always queries the coarse centroid; the precise
  -- point stays server-side (locations.precise_*).
  CREATE TYPE coarse_location_mode AS ENUM ('exact', 'city', 'region');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  -- Selfie/KYC badge state ("Certified Cut").
  CREATE TYPE verification_status AS ENUM ('unverified', 'pending', 'verified', 'rejected');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  -- Profile-level moderation state.
  CREATE TYPE moderation_status AS ENUM ('pending', 'approved', 'rejected', 'suspended', 'banned');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  -- UGC photo lifecycle. Photos start "pending" until screened (Sauce Check).
  CREATE TYPE photo_status AS ENUM ('pending', 'approved', 'rejected');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  -- Reports in-flow (from chat/profile). report_type is generic enough to cover
  -- harassment, impersonation, commercial solicitation (FOSTA), CSAM, etc.
  CREATE TYPE report_type AS ENUM (
    'harassment', 'impersonation', 'underage', 'commercial_solicitation',
    'explicit_content', 'csam', 'other'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE report_status AS ENUM ('open', 'reviewed', 'escalated', 'closed');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  -- NCMEC CyberTipline flow (live before launch): is_csam -> preserve evidence,
  -- disable account, submit, record the report id/status.
  CREATE TYPE ncmec_status AS ENUM ('none', 'pending_submission', 'submitted', 'acknowledged', 'failed');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  -- Moderation queue targets.
  CREATE TYPE moderation_target AS ENUM ('profile', 'photo', 'message');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  -- How an item entered the queue: automated classifier/keyword filter or a
  -- user report.
  CREATE TYPE moderation_source AS ENUM ('auto', 'user_report');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE moderation_queue_status AS ENUM ('pending', 'in_review', 'approved', 'rejected');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  -- v1 is server-served native/direct + house ads only (no programmatic SDK,
  -- no location leaves the server). Region-scoped on the server.
  CREATE TYPE ad_placement AS ENUM ('grid', 'profile', 'chat');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE ad_kind AS ENUM ('house', 'direct');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE push_platform AS ENUM ('android', 'ios');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
