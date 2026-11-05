
export default async function handler(req, res) {
    if (req.method !== "GET") {
        return res.status(405).json({
            error: "Method not allowed"
        });
    }

    res.setHeader("Cache-Control", "no-store");

    const apiKey = process.env.MODEL_API_KEY;

    if (!apiKey) {
        return res.status(500).json({
            error: "MODEL_API_KEY is missing"
        });
    }

    try {
        const response = await fetch(
            "https://api.meta.ai/v1/models",
            {
                headers: {
                    Authorization: `Bearer ${apiKey}`
                }
            }
        );

        const data = await response.json();

        if (!response.ok) {
            return res.status(502).json({
                metaStatus: response.status,
                errorCode: data.error?.code,
                error: "Unable to retrieve Meta models"
            });
        }

        const models = (data.data ?? []).map(
            model => model.id
        );

        return res.status(200).json({
            success: true,
            wonderAvailable:
                models.includes("muse-wonder-1.0"),
            sparkAvailable:
                models.includes("muse-spark-1.3"),
            availableModels: models
        });

    } catch (error) {
        return res.status(500).json({
            error: "Failed to check model availability"
        });
    }
}
