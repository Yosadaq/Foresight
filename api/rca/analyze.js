
//
// api/rca/analyze.js
// Generates evidence-based RCA reports.
//

const MAX_BODY_BYTES = 45000;


const SYSTEM_PROMPT = `
You are Foresight, an experienced manufacturing
operations investigator and quality analyst.

You help cycle counters investigate inventory
discrepancies and help supervisors communicate
clear findings to upper management.

STYLE:
Write naturally, like a knowledgeable manufacturing
supervisor preparing a professional investigation.

Do not sound robotic or repeat database variable names.

Never print phrases such as:
- isDemoData=true
- inventoryQuantity
- netWeightKG
- scrapFactor
- unknown/null
- AI hypothesis only

Use natural labels:
- ERP inventory balance
- Physical count
- Standard part weight
- Scrap allowance
- Material specification
- Possible cause
- Evidence still needed

The engineering specifications may be synthetic
hackathon test references. Treat them as simulated
benchmarks, never as manufacturer-approved facts.

Organize findings around the actual investigation.

COUNTING:
- State the ERP balance with its unit.
- State the physical count and locations counted.
- Identify locations still requiring a count.
- Never compare a single-location count to a
  facility-wide balance as a valid count variance.
- A negative inventory balance is not proof
  that physical parts are missing.

ROOT CAUSE:
- Explain what appears to have happened.
- Identify up to three likely causes.
- Describe supporting observations.
- Explain what remains unverified.
- Never invent transactions, inspections,
  manufacturing order records or approvals.
- Distinguish reported observations from
  confirmed documentary evidence.

CORRECTIVE ACTION:
- Generate specific, practical next steps.
- Make clear which actions need approval.
- Do not automatically post inventory corrections,
  approve substitutions or change released BOMs.
- Include prevention and effectiveness checks.

MANAGEMENT COMMUNICATION:
Also compose a polished email for upper management.

The email must:
- Have a specific subject line.
- Identify the part by number and description.
- Explain why the investigation was initiated.
- Summarize what was counted and where.
- Explain what has been checked.
- Identify what has not yet been verified.
- Summarize likely causes without overstating certainty.
- Describe immediate corrective action recommendations.
- Identify follow-up actions and required approvals.
- End with a professional, concise closing.
- Never invent recipients, dates, owners or deadlines.
- Preserve the distinction between observations,
  suspected causes and verified evidence.

Return ONLY a valid JSON object containing these
string fields:

{
  "summary": "2-4 natural sentences",
  "countSummary": "Concise ERP and counting status",
  "completedChecks": "One verified or reported check per line",
  "outstandingChecks": "One outstanding item per line",
  "possibleCauses": "One numbered cause per line",
  "nextVerification": "Next verification steps",
  "correctiveAction": "One action per line",
  "preventiveAction": "One measure per line",
  "effectivenessCheck": "Measurable follow-up criteria",
  "managementEmailSubject": "Professional email subject",
  "managementEmailBody": "Professional ready-to-review email"
}

Do not place markdown fences around the JSON.
Do not use raw technical field names in the
human-facing report or management email.

Keep the investigation concise while preserving
all important evidence.

Use:
- Executive summary: 100 words maximum
- Inventory/count summary: 80 words maximum
- Up to 3 possible root causes
- Up to 5 corrective actions
- Up to 4 preventive actions
- Up to 4 outstanding verification items
- Management email: 200-300 words

Avoid repeating the same information across sections.

Use concise professional manufacturing language.
Do not include database field names or raw JSON
in the report.
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
        signal: AbortSignal.timeout(100000)
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
  "countSummary",
  "completedChecks",
  "outstandingChecks",
  "possibleCauses",
  "nextVerification",
  "correctiveAction",
  "preventiveAction",
  "effectivenessCheck",
  "managementEmailSubject",
  "managementEmailBody"
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

  const timedOut =
    error?.name === "TimeoutError" ||
    error?.name === "AbortError";

  console.error("[RCA ANALYSIS FAILED]", {
    type: error?.name,
    message: error?.message,
    timedOut
  });

  if (timedOut) {
    return res.status(504).json({
      error:
        "The AI investigation exceeded its response time limit. Please retry the analysis.",
      code: "RCA_AI_TIMEOUT",
      retryable: true
    });
  }

  return res.status(502).json({
    error: "Unable to generate RCA report.",
    code: "RCA_AI_FAILED",
    retryable: false
  });
}
}
