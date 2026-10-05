-- =============================================================================
-- BEEF — Migration 0001: Extensions
-- Idempotent. Safe to run repeatedly.
--
-- postgis : PostGIS geometry/geography types + ST_DWithin for radius queries
--           (precise lat/lng live server-side only; grid queries run against
--            the coarse centroid — see 0005_triggers.sql).
-- citext  : case-insensitive text, used for email uniqueness (waitlist_emails,
--           users) so the waitlist→users import can dedupe by lowercased email
--           at the storage layer too.
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS citext;
