
//
// api/rca/part.js
// Foresight Manufacturing Intelligence
//
// ERP Inventory + Engineering Specifications
// + Cascading BOM + Synthetic Raw Materials
//

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_KEY = process.env.SUPABASE_SECRET_KEY;

const ERP_API_ORIGIN =
  "https://foresight-omega.vercel.app";

// ============================================
// SUPABASE HEADERS
// ============================================

function dbHeaders() {

  const headers = {
    apikey: SUPABASE_KEY,
    Accept: "application/json"
  };

  // Legacy service_role JWTs use Bearer authorization.
  // Modern sb_secret_* keys are not JWTs.

  if (SUPABASE_KEY.startsWith("eyJ")) {
    headers.Authorization = `Bearer ${SUPABASE_KEY}`;
  }

  return headers;
}

// ============================================
// DATABASE QUERY
// ============================================

async function dbQuery(table, filters = {}) {

  const url = new URL(
    `${SUPABASE_URL.replace(/\/$/, "")}/rest/v1/${table}`
  );

  url.searchParams.set("select", "*");

  for (const [key, value] of Object.entries(filters)) {
    url.searchParams.set(key, String(value));
  }

  const response = await fetch(url, {
    method: "GET",
    headers: dbHeaders()
  });

  if (!response.ok) {

    const detail = await response.text();

    console.error("[FORESIGHT RCA DATABASE]", {
      table,
      status: response.status,
      detail: detail.slice(0, 1000)
    });

    throw new Error(
      `Database query failed for ${table}: HTTP ${response.status}`
    );
  }

  return response.json();
}

// ============================================
// NORMALIZE ENGINEERING RESPONSE
// ============================================

function buildEngineeringResponse({
  partNumber,
  name,
  partType,
  spec,
  inventoryQuantity = null,
  inventory = [],
  bom = [],
  inventorySource = "Engineering Database",
  synthetic = false
}) {

  return {
    success: true,

    part_number: partNumber,

    name: name || partNumber,

    part_type: partType || "UNKNOWN",

    unit_of_measure:
      spec?.unit_of_measure || "UNKNOWN",

    manufacturer: null,

    // Engineering revision

    revision: spec?.revision ?? null,

    // Material specifications

    material_form: spec?.material_type ?? null,

    material_code: spec?.material_code ?? null,

    material_name:
      spec?.material_description ?? null,

    metal_type: spec?.material_type ?? null,

    galvanized:
      spec?.material_type === "galvanized_steel"
        ? true
        : null,

    corrosion_resistance: null,

    // Gauge / thickness

    gauge_label: spec?.gauge ?? null,

    thickness_mm: spec?.thickness_mm ?? null,

    perforated: null,

    open_area_fraction: null,

    // Weight / scrap

    net_weight_kg: spec?.net_weight_kg ?? null,

    scrap_factor: spec?.scrap_factor ?? null,

    // Manufacturing revisions

    routing_revision:
      spec?.routing_revision ?? null,

    tooling_revision:
      spec?.tooling_revision ?? null,

    revision_approved:
      spec?.verification_status === "verified",

    // Inventory

    stock_quantity: inventoryQuantity ?? 0,

    stock_quantity_known:
      inventoryQuantity !== null,

    inventory_locations: inventory,

    inventory_source: inventorySource,

    // BOM

    bom_component_count: bom.length,

    bom_components: bom.map(line => ({
      partNumber: line.child_part_number,
      revision: line.child_revision || "",
      quantityPer: Number(line.quantity_per),
      unit: line.unit_of_measure
    })),

    // Data integrity

    demo_data: synthetic,

    engineering_status:
      synthetic
        ? "synthetic_test"
        : spec?.verification_status ?? "missing",

    source_reference:
      spec?.source_reference ?? null
  };
}

// ============================================
// API HANDLER
// ============================================

export default async function handler(req, res) {

  res.setHeader(
    "Cache-Control",
    "no-store"
  );

  // ------------------------------------------
  // METHOD VALIDATION
  // ------------------------------------------

  if (req.method !== "GET") {

    res.setHeader("Allow", "GET");

    return res.status(405).json({
      error: "Method not allowed"
    });
  }

  // ------------------------------------------
  // DATABASE CONFIGURATION
  // ------------------------------------------

  if (!SUPABASE_URL || !SUPABASE_KEY) {

    console.error(
      "[FORESIGHT RCA] Missing Supabase credentials"
    );

    return res.status(503).json({
      error: "Database configuration missing"
    });
  }

  // ------------------------------------------
  // PART NUMBER VALIDATION
  // ------------------------------------------

  const number = req.query.number;

  if (
    typeof number !== "string" ||
    !/^[A-Z0-9._/-]{1,80}$/i.test(number)
  ) {

    return res.status(400).json({
      error: "Invalid part number"
    });
  }

  const partNumber =
    number.trim().toUpperCase();

  try {

    // ========================================
    // 1. EXISTING DEMO PARTS
    // ========================================

    if (partNumber.startsWith("DEMO-")) {

      const records = await dbQuery(
        "foresight_rca_part_health",
        {
          part_number: `eq.${partNumber}`,
          limit: 1
        }
      );

      const demo = records[0];

      if (!demo || demo.demo_data !== true) {

        return res.status(404).json({
          error: "Demo manufacturing part not found"
        });
      }

      return res.status(200).json({
        ...demo,
        success: true,
        engineering_status: "synthetic_test",
        stock_quantity_known: true,
        inventory_source: "Demo Manufacturing Database"
      });
    }

    // ========================================
    // 2. SYNTHETIC RAW MATERIALS
    // ========================================

    // Examples:
    //
    // SIM-RM-GALV
    // SIM-RM-CRS
    // SIM-RM-AL
    // SIM-RM-SS
    //
    // These records exist in the engineering
    // database, not necessarily in the ERP
    // imported inventory.

    if (partNumber.startsWith("SIM-RM-")) {

      const records = await dbQuery(
        "foresight_part_engineering",
        {
          part_number: `eq.${partNumber}`,
          limit: 1
        }
      );

      const spec = records[0];

      if (
        !spec ||
        spec.source_reference !==
          "SYNTHETIC_HACKATHON_TEST"
      ) {

        return res.status(404).json({
          error: "Synthetic raw material not found"
        });
      }

      // Look up any child relationships.
      // Raw materials will usually have none.

      const bom = await dbQuery(
        "foresight_engineering_bom",
        {
          parent_part_number: `eq.${partNumber}`,
          order: "child_part_number.asc",
          limit: 200
        }
      );

      const response = buildEngineeringResponse({
        partNumber,

        name:
          spec.material_description ||
          "Synthetic Raw Material",

        partType: "RAW_MATERIAL",

        spec,

        // Inventory is unavailable because
        // this material is not in ERP stock.

        inventoryQuantity: null,

        inventory: [],

        bom,

        inventorySource:
          "Synthetic Engineering Database",

        synthetic: true
      });

      return res.status(200).json(response);
    }

    // ========================================
    // 3. REAL ERP INVENTORY PARTS
    // ========================================

    // Preserve existing Mac Pac inventory
    // quantities and descriptions.

    const erpURL = new URL(
      `/api/parts/${encodeURIComponent(partNumber)}`,
      ERP_API_ORIGIN
    );

    const erpResponse = await fetch(erpURL, {
      method: "GET",
      headers: {
        Accept: "application/json"
      }
    });

    if (erpResponse.status === 404) {

      return res.status(404).json({
        error: "ERP manufacturing part not found"
      });
    }

    if (!erpResponse.ok) {

      console.error(
        "[FORESIGHT RCA ERP]",
        erpResponse.status
      );

      return res.status(502).json({
        error: "ERP manufacturing lookup failed"
      });
    }

    const erp = await erpResponse.json();

    if (
      erp.success !== true ||
      !erp.part
    ) {

      return res.status(502).json({
        error: "Unexpected ERP response"
      });
    }

    // ========================================
    // 4. ENGINEERING + BOM LOOKUP
    // ========================================

    const [specifications, bom] =
      await Promise.all([

        dbQuery(
          "foresight_part_engineering",
          {
            part_number: `eq.${partNumber}`,
            limit: 1
          }
        ),

        dbQuery(
          "foresight_engineering_bom",
          {
            parent_part_number:
              `eq.${partNumber}`,

            order:
              "child_part_number.asc",

            limit: 200
          }
        )
      ]);

    const spec =
      specifications[0] ?? null;

    // ========================================
    // 5. ERP INVENTORY BALANCES
    // ========================================

    const inventory =
      Array.isArray(erp.inventory)
        ? erp.inventory
        : [];

    const locations = inventory.map(item => ({
      location:
        item.area || "UNKNOWN",

      quantity:
        Number(item.balance)
    }));

    const quantity = Number(erp.totalBalance);

    const validQuantity =
      Number.isFinite(quantity)
        ? quantity
        : null;

    // ========================================
    // 6. IDENTIFY SYNTHETIC SPECIFICATIONS
    // ========================================

    // The part number is real, but its
    // engineering specifications may have
    // been generated for testing.

    const synthetic =
      spec?.source_reference ===
      "SYNTHETIC_HACKATHON_TEST";

    // ========================================
    // 7. BUILD COMPLETE RESPONSE
    // ========================================

    const response = buildEngineeringResponse({
      partNumber,

      name:
        erp.part.description ||
        erp.part.description2 ||
        partNumber,

      partType:
        erp.part.partType ||
        "UNKNOWN",

      spec,

      inventoryQuantity: validQuantity,

      inventory: locations,

      bom,

      inventorySource:
        erp.source || "Mac Pac ERP",

      synthetic
    });

    // Additional ERP metadata

    response.erp_type_code =
      erp.part.typeCode ?? null;

    response.erp_description2 =
      erp.part.description2 ?? null;

    // ========================================
    // RETURN MANUFACTURING INTELLIGENCE
    // ========================================

    return res.status(200).json(
      response
    );

  } catch (error) {

    console.error(
      "[FORESIGHT RCA PART ERROR]",
      error
    );

    return res.status(502).json({
      error:
        "Unable to load manufacturing intelligence"
    });
  }
}
