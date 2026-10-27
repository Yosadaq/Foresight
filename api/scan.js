
const META_URL = "https://api.meta.ai/v1/responses";
const MODEL = process.env.META_MODEL || "muse-wonder-1.0";

const clean = value =>
  String(value ?? "").trim();

function normalizePart(value) {
  return clean(value).toUpperCase();
}

function extractText(response) {
  return (response.output ?? [])
    .filter(item => item.type === "message")
    .flatMap(item => item.content ?? [])
    .filter(item => item.type === "output_text")
    .map(item => item.text)
    .join("\n");
}

function parseAI(text) {
  const cleaned = text
    .replace(/^\s*```(?:json)?\s*/i, "")
    .replace(/\s*```\s*$/, "")
    .trim();

  const start = cleaned.indexOf("{");
  const end = cleaned.lastIndexOf("}");

  if (start < 0 || end < start) {
    throw new Error("AI did not return JSON");
  }

  const data = JSON.parse(cleaned.slice(start, end + 1));

  if (!Array.isArray(data.items)) {
    throw new Error("AI items array missing");
  }

  return data.items.slice(0, 30).map((item, index) => {
    const count = Number(item.visibleCount);

    return {
      id: index + 1,
      label: clean(item.label).slice(0, 120),
      description: clean(item.description).slice(0, 300),
      partNumber: normalizePart(item.partNumber).slice(0, 60),
      visibleText: clean(item.visibleText).slice(0, 500),
      visibleCount:
        Number.isInteger(count) && count >= 0
          ? count
          : null,
      countType:
        item.countType === "exact_visible"
          ? "exact_visible"
          : "estimate",
      needsReview: Boolean(item.needsReview),
      notes: clean(item.notes).slice(0, 300)
    };
  }).filter(item => item.label);
}

async function supabaseQuery(table, params) {
  const base = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_SECRET_KEY;

  const url = new URL(`/rest/v1/${table}`, base);

  url.searchParams.set("select", "*");

  for (const [name, value] of Object.entries(params)) {
    url.searchParams.set(name, value);
  }

  const response = await fetch(url, {
    headers: {
      apikey: key,
      Authorization: `Bearer ${key}`
    },
    signal: AbortSignal.timeout(15000)
  });

  if (!response.ok) {
    throw new Error(`Database HTTP ${response.status}`);
  }

  return response.json();
}

function escapeLike(value) {
  return value.replace(/[\\%_*,()]/g, "");
}

async function findMatches(item) {
  const candidates = new Map();

  // First: exact part number match.
  if (/^[A-Z0-9._-]{3,60}$/.test(item.partNumber)) {
    const exact = await supabaseQuery(
      "manufacturing_catalog",
      {
        part_number: `eq.${item.partNumber}`,
        limit: "5"
      }
    );

    for (const row of exact) {
      candidates.set(row.part_number, {
        partNumber: row.part_number,
        description: row.description,
        description2: row.description_2,
        partType: row.part_type,
        matchMethod: "exact_number"
      });
    }
  }

  // Second: description-based candidate search.
  // These results MUST be reviewed by a person.
  const phrase = item.description || item.label;

  const tokens = phrase
    .toUpperCase()
    .match(/[A-Z0-9]{3,}/g) ?? [];

  const ignored = new Set([
    "THE", "AND", "FOR", "WITH", "PART",
    "METAL", "ITEM", "UNKNOWN", "VISIBLE",
    "MULTIPLE", "SMALL", "LARGE", "PIECES"
  ]);

  const terms = [...new Set(tokens)]
    .filter(t => !ignored.has(t))
    .slice(0, 3);

  for (const term of terms) {
    if (candidates.size >= 8) break;

    const safeTerm = escapeLike(term);

    const rows = await supabaseQuery(
      "manufacturing_catalog",
      {
        or: `(description.ilike.*${safeTerm}*,description_2.ilike.*${safeTerm}*)`,
        limit: "15"
      }
    );

    for (const row of rows) {
      if (candidates.size >= 8) break;

      if (!candidates.has(row.part_number)) {
        candidates.set(row.part_number, {
          partNumber: row.part_number,
          description: row.description,
          description2: row.description_2,
          partType: row.part_type,
          matchMethod: "description_candidate"
        });
      }
    }
  }

  return [...candidates.values()];
}

export default async function handler(req, res) {
  res.setHeader("Cache-Control", "no-store");

  if (req.method !== "POST") {
    return res.status(405).json({
      error: "POST required"
    });
  }

  if (
    !process.env.MODEL_API_KEY ||
    !process.env.SUPABASE_URL ||
    !process.env.SUPABASE_SECRET_KEY
  ) {
    return res.status(500).json({
      error: "Server configuration incomplete"
    });
  }

  const { image } = req.body ?? {};

  if (
    typeof image !== "string" ||
    !/^data:image\/jpeg;base64,[A-Za-z0-9+/=]+$/.test(image) ||
    image.length > 3_500_000
  ) {
    return res.status(400).json({
      error: "Valid JPEG under upload limit required"
    });
  }

  try {
    const metaResponse = await fetch(META_URL, {
      method: "POST",
      headers: {
        Authorization:
          `Bearer ${process.env.MODEL_API_KEY}`,
        "Content-Type": "application/json"
      },
      signal: AbortSignal.timeout(90000),
      body: JSON.stringify({
        model: MODEL,
        reasoning: { effort: "medium" },
        input: [{
          role: "user",
          content: [
            {
              type: "input_text",
              text: `
You analyze manufacturing inventory photographs.

Identify distinct visible object types.
Separate different parts into separate items.

For each type return:
- label: short physical description
- description: observable shape, size, material,
  markings and distinctive characteristics
- partNumber: exact visible manufacturing part
  number, or empty string
- visibleText: important readable text
- visibleCount: integer number of visible items,
  or null when counting is unreliable
- countType: "exact_visible" or "estimate"
- needsReview: boolean
- notes: explain uncertainty, overlap, occlusion,
  and anything that prevents reliable counting

Count each visible object once.
Never invent unseen items.
Never interpret a size or quantity as a part number.
Do not guess exact part identities from appearance alone.
If different objects cannot be separated reliably,
say so and request a better photograph.
A partially hidden part may require an estimated
count and review.

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

No markdown. No explanation outside JSON.
`
            },
            {
              type: "input_image",
              image_url: image
            }
          ]
        }]
      })
    });

    const metaData = await metaResponse.json();

    if (!metaResponse.ok) {
      console.error("Meta scan error:", {
        status: metaResponse.status,
        code: metaData.error?.code
      });

      return res.status(502).json({
        error: "Meta could not analyze the image",
        metaStatus: metaResponse.status
      });
    }

    const identified = parseAI(extractText(metaData));

    const items = [];

    for (const item of identified) {
      let matches = [];
      let lookupError = false;

      try {
        matches = await findMatches(item);
      } catch (error) {
        lookupError = true;
        console.error("Matching failed:", error.message);
      }

      items.push({
        ...item,
        matches,
        lookupError
      });
    }

    return res.status(200).json({
      success: true,
      model: MODEL,
      items,
      totalVisibleCount: items.every(
        item => item.visibleCount !== null
      )
        ? items.reduce(
            (sum, item) => sum + item.visibleCount, 0
          )
        : null,
      requiresConfirmation: true,
      inventoryUpdated: false
    });

  } catch (error) {
    console.error("Scan failure:", error.message);

    return res.status(502).json({
      error: "Scan processing failed"
    });
  }
}
