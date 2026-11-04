//
// api/rca/part.js
// Foresight Hackathon
//
// Vercel -> Supabase
// Uses server-side SUPABASE_SECRET_KEY
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
        error: "Valid part number required."
      });
    }

    const partNumber = rawNumber
      .trim()
      .toUpperCase();

    // This public endpoint exposes demo parts only.
    if (!/^DEMO-[A-Z0-9-]+$/.test(partNumber)) {
      return res.status(404).json({
        error: "Demo part not found."
      });
    }

    const supabaseURL =
      process.env.SUPABASE_URL;

    const supabaseKey =
      process.env.SUPABASE_SECRET_KEY;

    if (!supabaseURL || !supabaseKey) {
      console.error(
        "[FORESIGHT RCA] Missing Supabase configuration"
      );

      return res.status(500).json({
        error: "Database configuration unavailable."
      });
    }

    const queryURL = new URL(
      `${supabaseURL.replace(/\/$/, "")}/rest/v1/foresight_rca_part_health`
    );

    queryURL.searchParams.set(
      "part_number",
      `eq.${partNumber}`
    );

    queryURL.searchParams.set("select", "*");
    queryURL.searchParams.set("limit", "1");
    queryURL.searchParams.set("demo_data", "eq.true");

    const headers = {
      "apikey": supabaseKey,
      "Accept": "application/json"
    };

    // Legacy service_role keys are JWTs.
    // Modern sb_secret_* keys are NOT bearer JWTs.
    if (supabaseKey.startsWith("eyJ")) {
      headers.Authorization = `Bearer ${supabaseKey}`;
    }

    const response = await fetch(queryURL, {
      method: "GET",
      headers
    });
    
if (!response.ok) {
  const detail = await response.text();

  console.error("[FORESIGHT RCA UPSTREAM]", {
    status: response.status,
    body: detail.slice(0, 1500),
    host: queryURL.host,
    path: queryURL.pathname
  });

  return res.status(502).json({
    error: "Engineering database query failed.",
    upstreamStatus: response.status,
    upstreamCode: (() => {
      try {
        return JSON.parse(detail).code ?? null;
      } catch {
        return null;
      }
    })()
  });
}

    const records = await response.json();

    if (
      !Array.isArray(records) ||
      records.length === 0
    ) {
      return res.status(404).json({
        error: "Engineering part not found."
      });
    }

    const part = records[0];

    // Defense in depth: never expose non-demo rows.
    if (
      part.demo_data !== true ||
      !part.part_number?.startsWith("DEMO-")
    ) {
      return res.status(404).json({
        error: "Engineering part not found."
      });
    }

    return res.status(200).json(part);

  } catch (error) {

    console.error(
      "[FORESIGHT RCA]",
      error
    );

    return res.status(500).json({
      error: "Unable to process RCA lookup."
    });
  }
}
