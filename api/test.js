
export default function handler(req, res) {
    return res.status(200).json({
        success: true,
        message: "Foresight API is working",
        service: "Vercel"
    });
}
