import { createFileRoute } from '@tanstack/react-router';
import { requireAuth } from '~/lib/auth';
import { errorResponse, json, readJson } from '~/lib/http';
import { getRatingEligibility, saveRating } from '~/lib/ratings';

export const Route = createFileRoute('/api/ratings/$id')({
  server: {
    handlers: {
      GET: async ({ request, params }) => {
        try {
          return json(await getRatingEligibility(await requireAuth(request), params.id));
        } catch (error) { return errorResponse(error); }
      },
      POST: async ({ request, params }) => {
        try {
          const userId = await requireAuth(request);
          const body = await readJson(request);
          if (!body) return json({ error: 'invalid_body', message: 'Expected a JSON body.' }, { status: 400 });
          return json({ rating: await saveRating(userId, params.id, body.stars) });
        } catch (error) { return errorResponse(error); }
      },
    },
  },
});
