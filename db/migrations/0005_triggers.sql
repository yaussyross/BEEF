-- =============================================================================
-- BEEF — Migration 0005: Triggers & functions
-- Idempotent: functions use CREATE OR REPLACE; triggers use
-- DROP TRIGGER IF EXISTS + CREATE TRIGGER (Postgres has no CREATE OR REPLACE
-- TRIGGER until PG 14; we support older by dropping first).
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 18+ gate, enforced at the database layer on every insert/update.
-- The application rejects under-18 registrations too; this is the backstop so
-- no code path can ever persist a minor's birthdate on an active account.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION users_assert_adult() RETURNS trigger AS $$
BEGIN
  IF NEW.birthdate IS NULL THEN
    RAISE EXCEPTION 'birthdate is required';
  END IF;
  IF NEW.birthdate > (CURRENT_DATE - INTERVAL '18 years') THEN
    RAISE EXCEPTION 'user must be at least 18 years old';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_users_assert_adult ON users;
CREATE TRIGGER trg_users_assert_adult
  BEFORE INSERT OR UPDATE OF birthdate ON users
  FOR EACH ROW EXECUTE FUNCTION users_assert_adult();

-- ---------------------------------------------------------------------------
-- Keep the PostGIS geography columns in sync from the plain lat/lng doubles.
-- The application writes ONLY precise_lat/precise_lng / coarse_lat/coarse_lng /
-- travel_lat/travel_lng; the geography columns (used by ST_DWithin) follow.
-- ST_MakePoint(lng, lat) — note the (lng, lat) argument order.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION locations_sync_geog() RETURNS trigger AS $$
BEGIN
  IF NEW.precise_lat IS NOT NULL AND NEW.precise_lng IS NOT NULL THEN
    NEW.precise_geog := ST_SetSRID(ST_MakePoint(NEW.precise_lng, NEW.precise_lat), 4326)::geography;
  ELSE
    NEW.precise_geog := NULL;
  END IF;

  IF NEW.coarse_lat IS NOT NULL AND NEW.coarse_lng IS NOT NULL THEN
    NEW.coarse_geog := ST_SetSRID(ST_MakePoint(NEW.coarse_lng, NEW.coarse_lat), 4326)::geography;
  ELSE
    NEW.coarse_geog := NULL;
  END IF;

  IF NEW.travel_lat IS NOT NULL AND NEW.travel_lng IS NOT NULL THEN
    NEW.travel_geog := ST_SetSRID(ST_MakePoint(NEW.travel_lng, NEW.travel_lat), 4326)::geography;
  ELSE
    NEW.travel_geog := NULL;
  END IF;

  NEW.updated_at := now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_locations_sync_geog ON locations;
CREATE TRIGGER trg_locations_sync_geog
  BEFORE INSERT OR UPDATE OF precise_lat, precise_lng, coarse_lat, coarse_lng, travel_lat, travel_lng ON locations
  FOR EACH ROW EXECUTE FUNCTION locations_sync_geog();

-- ---------------------------------------------------------------------------
-- Bump chat_threads.last_message_at / updated_at when a message lands, so the
-- inbox can order threads by recency without a join.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION chat_messages_touch_thread() RETURNS trigger AS $$
BEGIN
  UPDATE chat_threads
     SET last_message_at = NEW.created_at,
         updated_at      = NEW.created_at
   WHERE id = NEW.thread_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_chat_messages_touch_thread ON chat_messages;
CREATE TRIGGER trg_chat_messages_touch_thread
  AFTER INSERT ON chat_messages
  FOR EACH ROW EXECUTE FUNCTION chat_messages_touch_thread();

-- ---------------------------------------------------------------------------
-- updated_at maintenance helper for tables that carry an updated_at column.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION set_updated_at() RETURNS trigger AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_users_updated_at ON users;
CREATE TRIGGER trg_users_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_profiles_updated_at ON profiles;
CREATE TRIGGER trg_profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_profile_photos_updated_at ON profile_photos;
CREATE TRIGGER trg_profile_photos_updated_at
  BEFORE UPDATE ON profile_photos
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_push_tokens_updated_at ON push_tokens;
CREATE TRIGGER trg_push_tokens_updated_at
  BEFORE UPDATE ON push_tokens
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
