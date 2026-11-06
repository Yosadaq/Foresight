
import {
  getFirebaseAdmin
} from "./firebase-admin.js";

const DEFAULT_DAILY_LIMIT = 100;

export async function enforceAIRateLimit({
  uid,
  limit = DEFAULT_DAILY_LIMIT
}) {
  if (
    typeof uid !== "string" ||
    !uid.trim()
  ) {
    const error = new Error(
      "Authentication is required."
    );

    error.statusCode = 401;
    error.code = "UNAUTHENTICATED";

    throw error;
  }

  const { db } = getFirebaseAdmin();

  const date = new Date()
    .toISOString()
    .slice(0, 10);

  const rateLimitRef = db.ref(
    `AIRateLimits/${uid}/${date}`
  );

  let allowed = false;
  let currentCount = 0;

  const result =
    await rateLimitRef.transaction(
      current => {
        const count =
          Number(current?.count || 0);

        if (
          !Number.isSafeInteger(count) ||
          count < 0 ||
          count >= limit
        ) {
          return;
        }

        allowed = true;
        currentCount = count + 1;

        return {
          count: count + 1,
          limit,
          updatedAt: Date.now()
        };
      },
      undefined,
      false
    );

  const finalCount =
    Number(
      result.snapshot.val()?.count || 0
    );

  if (!result.committed) {
    const error = new Error(
      "Daily AI scan limit reached."
    );

    error.statusCode = 429;
    error.code = "AI_RATE_LIMIT_EXCEEDED";

    throw error;
  }

  return {
    allowed: true,
    used: finalCount,
    remaining: Math.max(
      0,
      limit - finalCount
    ),
    limit,
    resetsAt:
      `${date}T23:59:59.999Z`
  };
}

