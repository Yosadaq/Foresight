
export default async function handler(req, res) {
  res.setHeader("Cache-Control", "no-store");

  if (req.method !== "GET") {
    return res.status(405).json({
      error: "Method not allowed"
    });
  }

  const base = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_SECRET_KEY;

  if (!base || !key) {
    return res.status(500).json({
      error: "Database configuration missing"
    });
  }

  const q = String(req.query.q ?? "").trim();

  if (q.length < 2 || q.length > 100) {
    return res.status(400).json({
      error: "Search must be 2-100 characters"
    });
  }

  // Remove PostgREST filter syntax characters.
  const safe = q.replace(/[(),.*\\%_]/g, "");

  if (safe.length < 2) {
    return res.status(400).json({
      error: "Invalid search term"
    });
  }

  try {
    const url = new URL(
      "/rest/v1/ci_components",
      base
    );

    url.searchParams.set(
      "select",
      "id,manufacturer_id,manufacturer_part_number," +
      "internal_part_number,name,description,category," +
      "material,dimensions,compatible_models," +
      "verification_status,inventory_part_number"
    );

    url.searchParams.set(
      "or",
      "(" +
      `manufacturer_part_number.ilike.*${safe}*,` +
      `name.ilike.*${safe}*,` +
      `description.ilike.*${safe}*,` +
      `category.ilike.*${safe}*,` +
      `compatible_models.cs.{"${safe}"}` +
      ")"
    );

    url.searchParams.set("limit", "30");

    const response = await fetch(url, {
      headers: {
        apikey: key,
        Authorization: `Bearer ${key}`
      },
      signal: AbortSignal.timeout(15000)
    });

    if (!response.ok) {
      console.error(
        "Component search failed:",
        response.status
      );

      return res.status(502).json({
        error: "Component catalog lookup failed"
      });
    }

    const results = await response.json();

    return res.status(200).json({
      success: true,
      query: q,
      results
    });

  } catch (error) {
    console.error(
      "Component search error:",
      error.message
    );

    return res.status(500).json({
      error: "Component search unavailable"
    });
  }
}
