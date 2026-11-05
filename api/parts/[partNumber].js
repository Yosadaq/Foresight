
//
// Foresight AI
// Manufacturing Part Lookup
// Supabase PostgreSQL
//

export default async function handler(req, res) {
  res.setHeader("Cache-Control", "no-store");

  if (req.method !== "GET") {
    return res.status(405).json({
      error: "Method not allowed"
    });
  }

  const baseURL = process.env.SUPABASE_URL;
  const apiKey = process.env.SUPABASE_SECRET_KEY;

  if (!baseURL || !apiKey) {
    return res.status(500).json({
      error: "Supabase configuration missing"
    });
  }

  const partNumber = String(req.query.partNumber ?? "")
    .trim()
    .toUpperCase();

  if (!/^[A-Z0-9._-]{1,60}$/.test(partNumber)) {
    return res.status(400).json({
      error: "Invalid part number"
    });
  }

  async function query(table, column, value) {
    const url = new URL(
      `/rest/v1/${table}`,
      baseURL
    );

    url.searchParams.set("select", "*");
    url.searchParams.set(column, `eq.${value}`);

    const response = await fetch(url, {
      headers: {
        apikey: apiKey,
        Authorization: `Bearer ${apiKey}`
      }
    });

    if (!response.ok) {
      throw new Error(
        `${table} query failed: ${response.status}`
      );
    }

    return response.json();
  }

  try {
    const [catalog, inventory] = await Promise.all([
      query(
        "manufacturing_catalog",
        "part_number",
        partNumber
      ),
      query(
        "inventory_import",
        "part_number",
        partNumber
      )
    ]);

    if (catalog.length === 0) {
      return res.status(404).json({
        error: "Part not found",
        partNumber
      });
    }

    const part = catalog[0];

    const totalBalance = inventory.reduce(
      (sum, row) => sum + Number(row.balance ?? 0),
      0
    );

    return res.status(200).json({
      success: true,
      source: "SUPABASE",
      part: {
        partNumber: part.part_number,
        description: part.description,
        description2: part.description_2,
        typeCode: part.legacy_type_code,
        partType: part.part_type
      },
      inventory: inventory.map(row => ({
        id: row.id,
        area: row.area_code,
        balance: Number(row.balance ?? 0),
        standardCost: row.standard_cost === null
          ? null
          : Number(row.standard_cost),
        inventoryValue: row.inventory_value === null
          ? null
          : Number(row.inventory_value)
      })),
      totalBalance,
      inventoryStatus: "IMPORTED_SAMPLE"
    });

  } catch (error) {
    console.error(
      "Manufacturing lookup failed:",
      error.message
    );

    return res.status(500).json({
      error: "Database lookup failed"
    });
  }
}
