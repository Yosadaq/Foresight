
import {
  enforceAIRateLimit
} from "./_lib/ai-rate-limit.js";

/*
=============================================
FORESIGHT — AI MANUFACTURING IMAGE SCANNER
=============================================

AI rate limiting:
  10 image scans per IP per hour

Shared AI usage:
  100 requests per day across all users

The rate limiter must execute before
any Meta model request.

Inventory is never modified automatically.
All detected parts require confirmation.
*/

const META_URL =
  "https://api.meta.ai/v1/responses";

const MODEL =
  process.env.META_MODEL ||
  "muse-wonder-1.0";

const MAX_IMAGE_LENGTH = 3_500_000;

const MAX_DETECTED_ITEMS = 30;

const MAX_MATCHES_PER_ITEM = 8;

/*
=============================================
UTILITIES
=============================================
*/

const clean = value =>
  String(value ?? "").trim();

function normalizePart(value) {
  return clean(value).toUpperCase();
}

function extractText(response) {
  return (response?.output ?? [])
    .filter(
      item => item?.type === "message"
    )
    .flatMap(
      item => item.content ?? []
    )
    .filter(
      item => item?.type === "output_text"
    )
    .map(
      item => item.text ?? ""
    )
    .join("\n");
}

/*
=============================================
PARSE AI RESPONSE
=============================================
*/

function parseAI(text) {
  if (
    typeof text !== "string" ||
    !text.trim()
  ) {
    throw new Error(
      "AI returned an empty response."
    );
  }

  const cleaned = text
    .replace(
      /^\s*```(?:json)?\s*/i,
      ""
    )
    .replace(
      /\s*```\s*$/,
      ""
    )
    .trim();

  const start =
    cleaned.indexOf("{");

  const end =
    cleaned.lastIndexOf("}");

  if (
    start < 0 ||
    end < start
  ) {
    throw new Error(
      "AI did not return valid JSON."
    );
  }

  const data = JSON.parse(
    cleaned.slice(
      start,
      end + 1
    )
  );

  if (!Array.isArray(data.items)) {
    throw new Error(
      "AI items array missing."
    );
  }

  return data.items
    .slice(0, MAX_DETECTED_ITEMS)
    .map((item, index) => {
      if (
        !item ||
        typeof item !== "object"
      ) {
        return null;
      }

      const rawCount =
        item.visibleCount;

      const count =
        rawCount === null ||
        rawCount === undefined ||
        rawCount === ""
          ? null
          : Number(rawCount);

      const validCount =
        Number.isSafeInteger(count) &&
        count >= 0
          ? count
          : null;

      const countType =
        item.countType ===
        "exact_visible"
          ? "exact_visible"
          : "estimate";

      return {
        id: index + 1,

        label:
          clean(item.label)
            .slice(0, 120),

        description:
          clean(item.description)
            .slice(0, 300),

        partNumber:
          normalizePart(
            item.partNumber
          ).slice(0, 60),

        visibleText:
          clean(item.visibleText)
            .slice(0, 500),

        visibleCount:
          validCount,

        countType:
          validCount === null
            ? "estimate"
            : countType,

        needsReview:
          Boolean(item.needsReview) ||
          validCount === null ||
          countType !== "exact_visible",

        notes:
          clean(item.notes)
            .slice(0, 300)
      };
    })
    .filter(
      item =>
        item !== null &&
        item.label.length > 0
    );
}

/*
=============================================
SUPABASE DATABASE REQUESTS
=============================================
*/

async function supabaseQuery(
  table,
  params
) {
  const base =
    process.env.SUPABASE_URL;

  const key =
    process.env.SUPABASE_SECRET_KEY;

  if (!base || !key) {
    throw new Error(
      "Supabase is not configured."
    );
  }

  const url = new URL(
    `/rest/v1/${table}`,
    base
  );

  url.searchParams.set(
    "select",
    "*"
  );

  for (
    const [name, value]
    of Object.entries(params)
  ) {
    url.searchParams.set(
      name,
      value
    );
  }

  const response = await fetch(
    url,
    {
      method: "GET",

      headers: {
        apikey: key,

        Authorization:
          `Bearer ${key}`,

        Accept:
          "application/json"
      },

      signal:
        AbortSignal.timeout(15000)
    }
  );

  if (!response.ok) {
    throw new Error(
      `Supabase HTTP ${response.status}`
    );
  }

  const result =
    await response.json();

  if (!Array.isArray(result)) {
    throw new Error(
      "Unexpected Supabase response."
    );
  }

  return result;
}

/*
=============================================
SUPABASE SEARCH HELPERS
=============================================
*/

function escapeLike(value) {
  return String(value)
    .replace(
      /[\\%_*,()]/g,
      ""
    );
}

/*
=============================================
MATCH DETECTED ITEMS TO CATALOG
=============================================
*/

async function findMatches(item) {
  const candidates =
    new Map();

  /*
    First:
    Search by exact part number.
  */

  if (
    /^[A-Z0-9._-]{3,60}$/.test(
      item.partNumber
    )
  ) {
    const exact =
      await supabaseQuery(
        "manufacturing_catalog",
        {
          part_number:
            `eq.${item.partNumber}`,

          limit: "5"
        }
      );

    for (const row of exact) {
      if (!row?.part_number) {
        continue;
      }

      candidates.set(
        row.part_number,
        {
          partNumber:
            row.part_number,

          description:
            row.description,

          description2:
            row.description_2,

          partType:
            row.part_type,

          matchMethod:
            "exact_number"
        }
      );
    }
  }

  /*
    Second:
    Search by description.

    These matches are candidates only
    and require human verification.
  */

  const phrase =
    item.description ||
    item.label;

  const tokens =
    phrase
      .toUpperCase()
      .match(
        /[A-Z0-9]{3,}/g
      ) ?? [];

  const ignored =
    new Set([
      "THE",
      "AND",
      "FOR",
      "WITH",
      "PART",
      "METAL",
      "ITEM",
      "UNKNOWN",
      "VISIBLE",
      "MULTIPLE",
      "SMALL",
      "LARGE",
      "PIECES"
    ]);

  const terms =
    [...new Set(tokens)]
      .filter(
        term =>
          !ignored.has(term)
      )
      .slice(0, 3);

  for (const term of terms) {
    if (
      candidates.size >=
      MAX_MATCHES_PER_ITEM
    ) {
      break;
    }

    const safeTerm =
      escapeLike(term);

    if (!safeTerm) {
      continue;
    }

    const rows =
      await supabaseQuery(
        "manufacturing_catalog",
        {
          or:
            `(description.ilike.*${safeTerm}*,description_2.ilike.*${safeTerm}*)`,

          limit: "15"
        }
      );

    for (const row of rows) {
      if (
        candidates.size >=
        MAX_MATCHES_PER_ITEM
      ) {
        break;
      }

      if (!row?.part_number) {
        continue;
      }

      if (
        !candidates.has(
          row.part_number
        )
      ) {
        candidates.set(
          row.part_number,
          {
            partNumber:
              row.part_number,

            description:
              row.description,

            description2:
              row.description_2,

            partType:
              row.part_type,

            matchMethod:
              "description_candidate"
          }
        );
      }
    }
  }

  return [
    ...candidates.values()
  ];
}

/*
=============================================
VALIDATE JPEG IMAGE
=============================================
*/

function isValidImage(image) {
  if (
    typeof image !== "string"
  ) {
    return false;
  }

  if (
    image.length >
    MAX_IMAGE_LENGTH
  ) {
    return false;
  }

  const prefix =
    "data:image/jpeg;base64,";

  if (
    !image.startsWith(prefix)
  ) {
    return false;
  }

  const base64 =
    image.slice(prefix.length);

  if (
    !base64 ||
    base64.length % 4 !== 0
  ) {
    return false;
  }

  return (
    /^[A-Za-z0-9+/]+={0,2}$/
      .test(base64)
  );
}

/*
=============================================
META IMAGE ANALYSIS PROMPT
=============================================
*/

const SCAN_PROMPT = `
You analyze manufacturing inventory photographs.

Identify distinct visible object types.
Separate different parts into separate items.

For each type return:

- label:
  Short physical description.

- description:
  Observable shape, size, material,
  markings, and distinctive characteristics.

- partNumber:
  Exact visible manufacturing part number,
  or an empty string.

- visibleText:
  Important readable text.

- visibleCount:
  Integer number of visible items,
  or null when counting is unreliable.

- countType:
  "exact_visible" or "estimate".

- needsReview:
  Boolean.

- notes:
  Explain uncertainty, overlap, occlusion,
  and anything preventing reliable counting.

Rules:

1. Count each visible object once.

2. Never invent unseen items.

3. Never interpret a size or quantity
   as a manufacturing part number.

4. Never guess exact part identities
   from appearance alone.

5. If different objects cannot be
   separated reliably, request a
   better photograph.

6. A partially hidden part may require
   an estimated count and review.

7. If text is unreadable, do not invent it.

8. Never claim a catalog match without
   database verification.

Return ONLY valid JSON shaped like:

{
  "items": [
    {
      "label": "steel mounting bracket",
      "description": "L-shaped steel component",
      "partNumber": "",
      "visibleText": "",
      "visibleCount": 4,
      "countType": "estimate",
      "needsReview": true,
      "notes": "Two components overlap"
    }
  ]
}

No markdown.
No explanation outside JSON.
`;

/*
=============================================
VERCEL API HANDLER
=============================================
*/

export default async function handler(
  req,
  res
) {
  res.setHeader(
    "Cache-Control",
    "no-store"
  );

  /*
    Only POST requests are accepted.
  */

  if (req.method !== "POST") {
    res.setHeader(
      "Allow",
      "POST"
    );

    return res.status(405).json({
      success: false,

      code:
        "METHOD_NOT_ALLOWED",

      error:
        "POST required."
    });
  }

  /*
    Validate server configuration
    before consuming AI quota.
  */

  if (
    !process.env.MODEL_API_KEY ||
    !process.env.SUPABASE_URL ||
    !process.env.SUPABASE_SECRET_KEY
  ) {
    console.error(
      "[FORESIGHT SCAN] Missing server configuration."
    );

    return res.status(500).json({
      success: false,

      code:
        "SERVER_CONFIGURATION_ERROR",

      error:
        "Server configuration incomplete."
    });
  }

  /*
    Validate the uploaded JPEG
    before consuming AI quota.
  */

  const { image } =
    req.body ?? {};

  if (!isValidImage(image)) {
    return res.status(400).json({
      success: false,

      code:
        "INVALID_IMAGE",

      error:
        "A valid JPEG image under the upload limit is required."
    });
  }

  /*
    RATE LIMIT CHECK

    This must run before Meta AI.

    The helper sends HTTP 429 or 503
    when access is denied.
  */

  const allowed =
    await enforceAIRateLimit(
      req,
      res,
      "image"
    );

  if (!allowed) {
    return;
  }

  /*
    Execute Meta image analysis.
  */

  try {
    const metaResponse =
      await fetch(
        META_URL,
        {
          method: "POST",

          headers: {
            Authorization:
              `Bearer ${process.env.MODEL_API_KEY}`,

            "Content-Type":
              "application/json"
          },

          signal:
            AbortSignal.timeout(90000),

          body: JSON.stringify({
            model: MODEL,

            reasoning: {
              effort: "medium"
            },

            input: [
              {
                role: "user",

                content: [
                  {
                    type:
                      "input_text",

                    text:
                      SCAN_PROMPT
                  },

                  {
                    type:
                      "input_image",

                    image_url:
                      image
                  }
                ]
              }
            ]
          })
        }
      );

    /*
      Read Meta response safely.
    */

    const responseText =
      await metaResponse.text();

    let metaData;

    try {
      metaData =
        JSON.parse(responseText);
    } catch {
      console.error(
        "[FORESIGHT META] Invalid JSON response.",
        {
          status:
            metaResponse.status,

          body:
            responseText.slice(
              0,
              500
            )
        }
      );

      return res.status(502).json({
        success: false,

        code:
          "META_INVALID_RESPONSE",

        error:
          "Meta returned an invalid response."
      });
    }

    /*
      Handle Meta API errors.
    */

    if (!metaResponse.ok) {
      const code =
        metaData?.error?.code ??
        "unknown_error";

      const requestId =
        metaResponse.headers.get(
          "x-request-id"
        );

      console.error(
        "[FORESIGHT META SCAN ERROR]",
        {
          status:
            metaResponse.status,

          code,

          message:
            metaData?.error?.message,

          model:
            MODEL,

          requestId
        }
      );

      let message =
        "Meta image analysis failed.";

      if (
        code === "model_not_found"
      ) {
        message =
          `Meta model ${MODEL} is unavailable to this API project. Verify model access.`;
      } else if (
        metaResponse.status === 401
      ) {
        message =
          "Meta API authentication failed.";
      } else if (
        metaResponse.status === 403
      ) {
        message =
          "Meta API permission denied.";
      } else if (
        metaResponse.status === 429
      ) {
        message =
          "Meta API rate limit exceeded.";
      } else if (
        metaResponse.status === 400
      ) {
        message =
          "Meta rejected the scan request.";
      }

      return res.status(502).json({
        success: false,

        code:
          "META_API_ERROR",

        error:
          message,

        metaStatus:
          metaResponse.status,

        metaCode:
          code
      });
    }

    /*
      Parse identified manufacturing
      parts from Meta output.
    */

    const identified =
      parseAI(
        extractText(metaData)
      );

    const items = [];

    /*
      Match each detected item
      against Supabase catalog.
    */

    for (const item of identified) {
      let matches = [];
      let lookupError = false;

      try {
        matches =
          await findMatches(item);
      } catch (error) {
        lookupError = true;

        console.error(
          "[FORESIGHT CATALOG MATCH ERROR]",
          {
            partNumber:
              item.partNumber,

            message:
              error.message
          }
        );
      }

      items.push({
        ...item,

        matches,

        lookupError
      });
    }

    /*
      Only calculate a total when
      every detected item has a
      reliable numeric count.

      Estimated counts still require
      human verification.
    */

    const hasAllCounts =
      items.every(
        item =>
          item.visibleCount !== null
      );

    const totalVisibleCount =
      hasAllCounts
        ? items.reduce(
            (sum, item) =>
              sum +
              item.visibleCount,
            0
          )
        : null;

    return res.status(200).json({
      success: true,

      model:
        MODEL,

      items,

      totalVisibleCount,

      requiresConfirmation:
        true,

      inventoryUpdated:
        false
    });

  } catch (error) {
    console.error(
      "[FORESIGHT SCAN FAILURE]",
      {
        message:
          error.message,

        name:
          error.name,

        stack:
          error.stack
      }
    );

    const timedOut =
      error.name ===
      "TimeoutError";

    return res.status(
      timedOut ? 504 : 502
    ).json({
      success: false,

      code:
        timedOut
          ? "AI_SCAN_TIMEOUT"
          : "AI_SCAN_FAILED",

      error:
        timedOut
          ? "AI scan timed out. Please try again."
          : "Scan processing failed."
    });
  }
}
