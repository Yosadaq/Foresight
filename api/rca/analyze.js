
//
// api/rca/analyze.js
// Generates evidence-based RCA reports.
//

const MAX_BODY_BYTES = 45000;

const SYSTEM_PROMPT = `
You are Foresight, an industrial manufacturing
root-cause analysis specialist.

You receive a manufacturing part snapshot,
inventory evidence and answers from a cycle counter.

Generate:
1. A concise investigation summary.
2. Up to three ranked possible root causes.
3. The most useful remaining verification.
4. A corrective action plan.
5. Preventive actions.
6. A recommended effectiveness check.

Investigate:
- Part identification and location
- Physical count versus ERP quantity
- Unit conversions
- Material grade, coil, thickness and weight
- Revision and routing
- Scrap factor and actual scrap
- Parent-child BOM consumption
- Manufacturing order and operation
- Material substitutions and missing postings

Never invent records, drawing approvals, transactions,
coils, measurements or manufacturing orders.

Treat missing engineering fields as unknown, not as
verified specifications.

Separate suspected causes from confirmed evidence.
A negative ERP balance is not proof of a scrap problem.
A suggested substitution must be reviewed.

Return ONLY a JSON object with these string fields:
summary
possibleCauses
nextVerification
correctiveAction
preventiveAction
effectivenessCheck

/*
Add the following text inside SYSTEM_PROMPT,
not as a separate JavaScript statement.
*/

The engineering database contains synthetic
manufacturing specifications created for the
Foresight hackathon.

Use them as simulated reference standards
when investigating the fictional scenario.

You may compare expected and observed values,
identify inconsistencies, calculate variances,
and recommend corrective actions.

Do not describe synthetic records as approved
manufacturer specifications.

Do not claim an actual manufacturing order,
coil issue, substitution or scrap transaction
has been verified unless supporting evidence
is included in the investigation.

Clearly distinguish:
- Database reference value
- Employee observation
- AI hypothesis
- Confirmed evidence
- Recommended corrective action

`;

function extractJSON(text) {
  const cleaned = text
    .replace(/```json/gi, "")
    .replace(/```/g, "")
    .trim();

  const start = cleaned.indexOf("{");
  const end = cleaned.lastIndexOf("}");

  if (start < 0 || end < start) {
    throw new Error("AI returned no JSON object");
  }

  return JSON.parse(cleaned.slice(start, end + 1));
}

export default async function handler(req, res) {
  res.setHeader("Cache-Control", "no-store");

  if (req.method !== "POST") {
    res.setHeader("Allow", "POST");

    return res.status(405).json({
      error: "Method not allowed"
    });
  }

  const key = process.env.MODEL_API_KEY;

  if (!key) {
    return res.status(503).json({
      error: "Meta Model API is not configured"
    });
  }

  try {
    const packet = req.body;

    if (
      !packet ||
      typeof packet !== "object" ||
      Array.isArray(packet) ||
      typeof packet.partNumber !== "string" ||
      !Array.isArray(packet.answers) ||
      packet.answers.length > 40 ||
      packet.partNumber.length > 80 ||
      JSON.stringify(packet).length > MAX_BODY_BYTES
    ) {
      return res.status(400).json({
        error: "Invalid investigation packet"
      });
    }

    const response = await fetch(
      "https://api.meta.ai/v1/chat/completions",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${key}`,
          "Content-Type": "application/json"
        },
        body: JSON.stringify({
          model:
            process.env.META_RCA_MODEL ||
            "muse-spark-1.3",
          temperature: 0.2,
          messages: [
            {
              role: "system",
              content: SYSTEM_PROMPT
            },
            {
              role: "user",
              content: JSON.stringify(packet)
            }
          ]
        }),
        signal: AbortSignal.timeout(55000)
      }
    );

    const body = await response.json();

    if (!response.ok) {
      console.error("[META RCA]", {
        status: response.status,
        code: body?.error?.code
      });

      return res.status(502).json({
        error: "Meta AI analysis unavailable",
        upstreamStatus: response.status
      });
    }

    const content =
      body.choices?.[0]?.message?.content;

    if (typeof content !== "string") {
      throw new Error("Missing model response text");
    }

    const report = extractJSON(content);

    const required = [
      "summary",
      "possibleCauses",
      "nextVerification",
      "correctiveAction",
      "preventiveAction",
      "effectivenessCheck"
    ];

    for (const field of required) {
      if (typeof report[field] !== "string") {
        throw new Error(`Invalid report field: ${field}`);
      }
    }

    return res.status(200).json({
      success: true,
      model: body.model || "Meta Model API",
      report
    });

  } catch (error) {
    console.error("[RCA ANALYSIS]", error.message);

    return res.status(502).json({
      error: "Unable to generate RCA report"
    });
  }
}
