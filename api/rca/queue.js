
//
// api/rca/queue.js
//

const supabaseURL = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SECRET_KEY;

async function query(table, params) {
  if (!supabaseURL || !supabaseKey) {
    throw new Error("Missing Supabase configuration");
  }

  const url = new URL(
    `${supabaseURL.replace(/\/$/, "")}/rest/v1/${table}`
  );

  for (const [key, value] of Object.entries(params)) {
    url.searchParams.set(key, value);
  }

  const headers = {
    apikey: supabaseKey,
    Accept: "application/json"
  };

  if (supabaseKey.startsWith("eyJ")) {
    headers.Authorization = `Bearer ${supabaseKey}`;
  }

  const response = await fetch(url, { headers });
  const body = await response.text();

  if (!response.ok) {
    console.error("[RCA QUEUE UPSTREAM]", {
      table,
      status: response.status,
      body: body.slice(0, 1000)
    });

    throw new Error(
      `Supabase returned HTTP ${response.status}`
    );
  }

  return JSON.parse(body);
}

export default async function handler(req, res) {
  res.setHeader("Cache-Control", "no-store");

  if (req.method !== "GET") {
    res.setHeader("Allow", "GET");
    return res.status(405).json({
      error: "Method not allowed"
    });
  }

  try {
    const imports = await query(
      "foresight_inventory_imports",
      {
        select: "id,imported_at",
        is_demo: "eq.true",
        order: "imported_at.desc,id.desc",
        limit: "1"
      }
    );

    if (!imports.length) {
      return res.status(200).json({
        success: true,
        tasks: []
      });
    }

    const rows = await query(
      "foresight_cycle_queue",
      {
        select: [
          "task_id",
          "part_number",
          "location_id",
          "erp_quantity",
          "count_variance",
          "priority_rank",
          "status",
          "assigned_to"
        ].join(","),
        import_id: `eq.${imports[0].id}`,
        is_demo: "eq.true",
        order: "priority_rank.asc",
        limit: "100"
      }
    );

    return res.status(200).json({
      success: true,
      snapshotID: imports[0].id,
      importedAt: imports[0].imported_at,
      tasks: rows
    });

  } catch (error) {
    console.error("[RCA QUEUE]", error);

    return res.status(502).json({
      error: "Unable to load cycle-count queue."
    });
  }
}
