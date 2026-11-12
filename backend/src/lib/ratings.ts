import { sql } from '../db';
import { isUuid, requireActiveAccount } from './auth';
import { isActiveUser, isBlockedEither } from './chat';

export class RatingError extends Error {
  constructor(public status: number, public code: string, message: string) {
    super(message);
  }
}

export function validateStars(stars: unknown): asserts stars is number {
  if (typeof stars !== 'number' || !Number.isInteger(stars) || stars < 1 || stars > 5) {
    throw new RatingError(400, 'invalid_stars', 'Choose a whole number of stars from 1 to 5.');
  }
}

async function requireRatingPair(raterId: string, rateeId: string): Promise<void> {
  if (!isUuid(rateeId)) throw new RatingError(400, 'invalid_user', 'A valid user ID is required.');
  if (raterId === rateeId) throw new RatingError(400, 'self_rating', 'You cannot rate yourself.');
  await requireActiveAccount(raterId);
  if (!(await isActiveUser(rateeId)) || await isBlockedEither(raterId, rateeId)) {
    throw new RatingError(404, 'user_not_found', 'User not found.');
  }
}

/** Only eligibility and the caller's own vote; no chat metadata is exposed. */
export async function getRatingEligibility(raterId: string, rateeId: string) {
  await requireRatingPair(raterId, rateeId);
  const rows = await sql()`SELECT rating_chat_eligible(${raterId}::uuid, ${rateeId}::uuid) AS eligible,
    (SELECT stars FROM profile_ratings WHERE rater_id = ${raterId} AND ratee_id = ${rateeId}) AS my_rating`;
  const row = rows[0] as { eligible: boolean; my_rating: number | null };
  return { eligible: row.eligible === true, my_rating: row.my_rating };
}

export async function saveRating(raterId: string, rateeId: string, stars: unknown) {
  validateStars(stars);
  await requireRatingPair(raterId, rateeId);
  try {
    // The authenticated actor is always the rater. No client-supplied eligibility,
    // rater ID or timing value enters this query. PK serializes concurrent votes.
    const rows = await sql()`INSERT INTO profile_ratings (rater_id, ratee_id, stars)
      VALUES (${raterId}, ${rateeId}, ${stars})
      ON CONFLICT (rater_id, ratee_id) DO UPDATE SET stars = EXCLUDED.stars
      RETURNING stars`;
    return { stars: (rows[0] as { stars: number }).stars };
  } catch (error) {
    if (error && typeof error === 'object' && 'constraint' in error &&
        error.constraint === 'profile_ratings_eligible') {
      throw new RatingError(403, 'rating_not_eligible', 'Exchange messages with each other across at least five minutes before rating.');
    }
    throw error;
  }
}
