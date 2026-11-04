
//
// api/rca/part.js
// Foresight: ERP + engineering + BOM
//

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_KEY = process.env.SUPABASE_SECRET_KEY;

function dbHeaders() {
  return {
    apikey: SUPABASE_KEY,
    ...(SUPABASE_KEY.startsWith("eyJ")
      ? { Authorization: `Bearer ${SUPABASE_KEY}` }
      : {}),
    Accept: "application/json"
  };
}

async function dbQuery(table, filters) {
  const url = new URL(
    `${SUPABASE_URL.replace(/\/$/, "")}/rest/v1/${table}`
  );

  url.searchParams.set("select", "*");

  for (const [key, value] of Object.entries(filters)) {
    url.searchParams.set(key, value);
  }

  const response = await fetch(url, {
    headers: dbHeaders()
  });

  if (!response.ok) {
    const detail = await response.text();

    console.error("[RCA DB]", {
      table,
      status: response.status,
      detail: detail.slice(0, 1000)
    });

    throw new Error(`Database query failed: ${table}`);
  }

  return response.json();
}

export default async function handler(req, res) {
  res.setHeader("Cache-Control", "no-store");

  if (req.method !== "GET") {
    return res.status(405).json({
      error: "Method not allowed"
    });
  }

  const number = req.query.number;

  if (
    typeof number !== "string" ||
    !/^[A-Z0-9._/-]{1,80}$/i.test(number)
  ) {
    return res.status(400).json({
      error: "Invalid part number"
    });
  }

  if (!SUPABASE_URL || !SUPABASE_KEY) {
    return res.status(503).json({
      error: "Database configuration missing"
    });
  }

  const partNumber = number.toUpperCase();

  try {
    // Preserve compatibility with existing DEMO records.

    if (partNumber.startsWith("DEMO-")) {
      const demo = await dbQuery(
        "foresight_rca_part_health",
        {
          part_number: `eq.${partNumber}`,
          limit: "1"
        }
      );

      if (!demo.length) {
        return res.status(404).json({
          error: "Demo part not found"
        });
      }

      return res.status(200).json(demo[0]);
    }

    // Use the existing ERP lookup API.
    // Fixed origin avoids trusting client-supplied Host headers.
    const erpURL = new URL(
      `/api/parts/${encodeURIComponent(partNumber)}`,
      "https://foresight-omega.vercel.app"
    );

    const erpResponse = await fetch(erpURL);

    if (erpResponse.status === 404) {
      return res.status(404).json({
        error: "ERP part not found"
      });
    }

    if (!erpResponse.ok) {
      return res.status(502).json({
        error: "ERP lookup failed"
      });
    }

    const erp = await erpResponse.json();

    if (!erp.part || erp.success !== true) {
      return res.status(502).json({
        error: "Unexpected ERP response"
      });
    }

    const [specs, bom] = await Promise.all([
      dbQuery("foresight_part_engineering", {
        part_number: `eq.${partNumber}`,
        limit: "1"
      }),

      dbQuery("foresight_engineering_bom", {
        parent_part_number: `eq.${partNumber}`,
        order: "child_part_number.asc",
        limit: "200"
      })
    ]);

    const spec = specs[0] ?? null;

    const inventory = Array.isArray(erp.inventory)
      ? erp.inventory
      : [];

    // These fields match RCAPartHealth.swift decoding.
    return res.status(200).json({
      part_number: partNumber,
      name:
        erp.part.description ||
        erp.part.description2 ||
        partNumber,

      part_type: erp.part.partType || "UNKNOWN",
      unit_of_measure: spec?.unit_of_measure || "UNKNOWN",
      manufacturer: null,

      revision: spec?.revision ?? null,
      material_form: spec?.material_type ?? null,
      material_code: spec?.material_code ?? null,
      material_name: spec?.material_description ?? null,
      metal_type: spec?.material_type ?? null,
      galvanized: null,
      corrosion_resistance: null,

      gauge_label: spec?.gauge ?? null,
      thickness_mm: spec?.thickness_mm ?? null,
      perforated: null,
      open_area_fraction: null,
      net_weight_kg: spec?.net_weight_kg ?? null,
      scrap_factor: spec?.scrap_factor ?? null,

      routing_revision: spec?.routing_revision ?? null,
      tooling_revision: spec?.tooling_revision ?? null,

      revision_approved:
        spec?.verification_status === "verified",

      stock_quantity: Number(erp.totalBalance ?? 0),

      bom_component_count: bom.length,

      bom_components: bom.map(line => ({
        partNumber: line.child_part_number,
        revision: line.child_revision || "",
        quantityPer: Number(line.quantity_per),
        unit: line.unit_of_measure
      })),

      demo_data: false,

      // Additional diagnostic context:
      engineering_status:
        spec?.verification_status ?? "missing",

      inventory_source: erp.source,

      inventory_locations: inventory.map(item => ({
        location: item.area || "UNKNOWN",
        quantity: Number(item.balance)
      }))
    });

  } catch (error) {
    console.error("[RCA PART]", error);

    return res.status(502).json({
      error: "Unable to load manufacturing intelligence"
    });
  }
}
