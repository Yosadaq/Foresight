/*
=============================================
FORESIGHT — SERVER-SIDE AI RATE LIMITING
=============================================

RCA:
  5 requests per IP per hour

Image analysis:
  10 requests per IP per hour

All AI endpoints combined:
  100 requests per 24 hours

All counters are shared across Vercel
server instances.

If Redis is unavailable, AI calls are blocked.
*/

let limiters = null;

function initializeLimiters() {
  if (limiters) {
    return limiters;
  }

  if (
    !process.env.UPSTASH_REDIS_REST_URL ||
    !process.env.UPSTASH_REDIS_REST_TOKEN
  ) {
    throw new Error(
      "AI rate limiter is not configured."
    );
  }

  const redis = new Redis({
    url: process.env.UPSTASH_REDIS_REST_URL,
    token: process.env.UPSTASH_REDIS_REST_TOKEN
  });

  limiters = {
    rca: new Ratelimit({
      redis,
      limiter: Ratelimit.slidingWindow(
        5,
        "1 h"
      ),
      prefix: "foresight:ai:rca"
    }),

    image: new Ratelimit({
      redis,
      limiter: Ratelimit.slidingWindow(
        10,
        "1 h"
      ),
      prefix: "foresight:ai:image"
    }),

    global: new Ratelimit({
      redis,
      limiter: Ratelimit.fixedWindow(
        100,
        "1 d"
      ),
      prefix: "foresight:ai:global"
    })
  };

  return limiters;
}

function clientIdentifier(req) {
  // Use the client IP supplied through Vercel.
  // Do not accept arbitrary user-provided IDs
  // as proof of identity.

  const forwarded = req.headers["x-forwarded-for"];

  const address = (
    Array.isArray(forwarded)
      ? forwarded[0]
      : forwarded?.split(",")[0]
  )?.trim();

  const ip =
    address ||
    req.socket?.remoteAddress ||
    "unknown";

  // Avoid storing plaintext IPs as Redis keys.
  return createHash("sha256")
    .update(ip)
    .digest("hex");
}

function sendLimitedResponse(res, reset) {
  const retryAfter = Math.max(
    1,
    Math.ceil(
      (reset - Date.now()) / 1000
    )
  );

  res.setHeader(
    "Retry-After",
    String(retryAfter)
  );

  res.setHeader(
    "Cache-Control",
    "no-store"
  );

  res.status(429).json({
    success: false,
    code: "AI_RATE_LIMITED",
    error:
      "Foresight AI usage limit reached. " +
      "Please try again later.",
    retryAfterSeconds: retryAfter
  });

  return false;
}

/*
=============================================
CALL BEFORE ANY META MODEL REQUEST
=============================================
*/

export async function enforceAIRateLimit(
  req,
  res,
  operation = "rca"
) {
  if (res.headersSent) {
    return false;
  }

  if (
    operation !== "rca" &&
    operation !== "image"
  ) {
    res.status(500).json({
      success: false,
      error: "Invalid AI operation."
    });

    return false;
  }

  try {
    const configured = initializeLimiters();

    const id = clientIdentifier(req);

    // Check individual request limits first.
    const individual = await configured[
      operation
    ].limit(id);

    if (!individual.success) {
      return sendLimitedResponse(
        res,
        individual.reset
      );
    }

    // Shared cap across all AI endpoints.
    const global = await configured.global.limit(
      "all-ai-requests"
    );

    if (!global.success) {
      return sendLimitedResponse(
        res,
        global.reset
      );
    }

    return true;

  } catch (error) {
    console.error(
      "[FORESIGHT AI RATE LIMIT ERROR]",
      error
    );

    // Fail closed: no unlimited AI usage.
    res.setHeader(
      "Cache-Control",
      "no-store"
    );

    res.status(503).json({
      success: false,
      code: "AI_RATE_LIMIT_UNAVAILABLE",
      error:
        "AI requests are temporarily unavailable."
    });

    return false;
  }
}

