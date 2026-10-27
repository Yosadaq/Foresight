
const MODEL = "muse-wonder-1.0";

export default async function handler(req, res) {
  res.setHeader("Cache-Control", "no-store");

  if (req.method !== "POST") {
    return res.status(405).json({
      error: "Only POST requests are allowed."
    });
  }

  const apiKey = process.env.MODEL_API_KEY;

  if (!apiKey) {
    return res.status(500).json({
      error: "Meta API key is not configured."
    });
  }

  const { image } = req.body ?? {};

  if (
    typeof image !== "string" ||
    !/^data:image\/jpeg;base64,[A-Za-z0-9+/=]+$/.test(image) ||
    image.length > 3_500_000
  ) {
    return res.status(400).json({
      error: "Invalid or oversized JPEG image."
    });
  }

  try {
    const response = await fetch(
      "https://api.meta.ai/v1/responses",
      {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${apiKey}`,
          "Content-Type": "application/json"
        },
        signal: AbortSignal.timeout(90000),
        body: JSON.stringify({
          model: MODEL,
          reasoning: {
            effort: "medium"
          },
          input: [
            {
              role: "user",
              content: [
                {
                  type: "input_text",
                  text: `
You are Foresight, an expert manufacturing
inventory identification assistant.

Analyze the attached photograph.

Extract:
1. Manufacturer
2. Manufacturer part number
3. Component or raw material name
4. Product category
5. Visible specifications
6. Quantity, only when reliably visible
7. All relevant readable markings
8. Uncertainty or missing information

Use information actually visible in the
image. Clearly label any inferences.

Never invent manufacturer names, part
numbers, quantities, or specifications.

Return a clear, readable inventory
identification report.
`
                },
                {
                  type: "input_image",
                  image_url: image
                }
              ]
            }
          ]
        })
      }
    );

    const data = await response.json();

    if (!response.ok) {
      console.error("Meta request failed:", response.status);

      return res.status(502).json({
        error: "Meta image analysis failed."
      });
    }

    const result = (data.output ?? [])
      .filter(item => item.type === "message")
      .flatMap(item => item.content ?? [])
      .filter(item => item.type === "output_text")
      .map(item => item.text)
      .join("\n")
      .trim();

    if (!result) {
      return res.status(502).json({
        error: "The AI returned no readable result."
      });
    }

    return res.status(200).json({
      success: true,
      model: MODEL,
      result
    });

  } catch (error) {
    console.error("Analysis error:", error.message);

    return res.status(502).json({
      error: "Unable to complete image analysis."
    });
  }
}
