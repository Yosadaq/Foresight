
//
// api/rca/part.js
//
// Public, read-only hackathon demo endpoint.
// No user authentication required.
//

export default async function handler(req, res) {
  res.setHeader("Cache-Control", "no-store");

  if (req.method !== "GET") {
    res.setHeader("Allow", "GET");

    return res.status(405).json({
      error: "Method not allowed."
    });
  }

  try {
    const rawNumber = req.query.number;

    if (
      typeof rawNumber !== "string" ||
      rawNumber.length > 80
    ) {
      return res.status(400).json({
        error: "A valid part number is required."
      });
    }

    const partNumber = rawNumber
      .trim()
      .toUpperCase();

    // Limit this public endpoint to fictional demo data.
    if (!/^DEMO-[A-Z0-9-]+$/.test(partNumber)) {
      return res.status(404).json({
        error: "No demo engineering record found."
      });
    }

    const supabaseURL = process.env.SUPABASE_URL;
    const anonKey = process.env.SUPABASE_ANON_KEY;

    if (!supabaseURL || !anonKey) {
      console.error(
        "[RCA] Missing Supabase configuration."
      );

      return res.status(500).json({
        error: "RCA database is not configured."
      });
    }

    const url = new URL(
      `${supabaseURL.replace(/\/$/, "")}/rest/v1/foresight_rca_part_health`
    );

    url.searchParams.set(
      "part_number",
      `eq.${partNumber}`
    );

    url.searchParams.set("select", "*");
    url.searchParams.set("limit", "1");

    const headers = {
      apikey: anonKey,
      Accept: "application/json"
    };

    // Legacy anon JWTs can also be bearer tokens.
    // New publishable keys should not be used
    // as bearer JWTs.
    if (anonKey.startsWith("eyJ")) {
      headers.Authorization = `Bearer ${anonKey}`;
    }

    const response = await fetch(url, {
      method: "GET",
      headers
    });

    if (!response.ok) {
      console.error(
        "[RCA] Supabase request failed:",
        response.status,
        await response.text()
      );

      return res.status(502).json({
        error: "Unable to load engineering data."
      });
    }

    const records = await response.json();

    if (!Array.isArray(records)) {
      return res.status(502).json({
        error: "Unexpected database response."
      });
    }

    if (records.length === 0) {
      return res.status(404).json({
        error: "Engineering record not found."
      });
    }

    const part = records[0];

    if (part.demo_data !== true) {
      return res.status(404).json({
        error: "Engineering record not found."
      });
    }

    return res.status(200).json(part);

  } catch (error) {
    console.error("[RCA ERROR]", error);

    return res.status(500).json({
      error: "An internal RCA error occurred."
    });
  }
}
