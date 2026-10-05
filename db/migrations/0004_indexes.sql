-- =============================================================================
-- BEEF — Migration 0004: Indexes
-- Idempotent (CREATE INDEX IF NOT EXISTS).
--
-- PostGIS: GIST indexes on the geography columns make ST_DWithin radius queries
-- (grid, nearby) index-assisted. The grid queries coarse_geog; precise_geog is
-- indexed for internal distance math only.
-- =============================================================================

-- Locations / proximity grid
CREATE INDEX IF NOT EXISTS idx_locations_coarse_geog ON locations USING GIST (coarse_geog);
CREATE INDEX IF NOT EXISTS idx_locations_precise_geog ON locations USING GIST (precise_geog);
CREATE INDEX IF NOT EXISTS idx_locations_updated_at ON locations (updated_at);

-- Chat
CREATE INDEX IF NOT EXISTS idx_chat_messages_thread_created ON chat_messages (thread_id, created_at);
CREATE INDEX IF NOT EXISTS idx_thread_participants_user ON thread_participants (user_id);
CREATE INDEX IF NOT EXISTS idx_chat_threads_last_message ON chat_threads (last_message_at DESC);

-- Safety
CREATE INDEX IF NOT EXISTS idx_blocks_blocked ON blocks (blocked_id);
CREATE INDEX IF NOT EXISTS idx_reports_reported_user ON reports (reported_user_id) WHERE reported_user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_reports_status ON reports (status);
CREATE INDEX IF NOT EXISTS idx_moderation_queue_status ON moderation_queue (status, created_at);

-- Ads: region + active shortlist for server-side matching
CREATE INDEX IF NOT EXISTS idx_ad_inventory_active ON ad_inventory (active, placement);

-- Profile discovery
CREATE INDEX IF NOT EXISTS idx_profiles_intent_tags ON profiles USING GIN (intent_tags);
CREATE INDEX IF NOT EXISTS idx_profile_interests_interest ON profile_interests (interest_id);
