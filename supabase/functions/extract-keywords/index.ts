import "@supabase/functions-js/edge-runtime.d.ts";

export default {
  fetch: async (req: Request) => {
    if (req.method !== "POST") {
      return new Response("Method not allowed", { status: 405 });
    }

    try {
      const { images } = await req.json() as { images: string[] };
      if (!images || images.length === 0) {
        return Response.json({ error: "images required" }, { status: 400 });
      }

      const samples = images.slice(0, 5);
      const content: unknown[] = samples.map((b64: string) => ({
        type: "image",
        source: { type: "base64", media_type: "image/jpeg", data: b64 },
      }));
      content.push({
        type: "text",
        text: `Look at these photos and extract exactly 3 keywords that best describe \
the mood, atmosphere, and feeling of these moments. \
Keywords MUST be in English only. Never use any other language. \
Return ONLY a JSON array of 3 English strings. No explanation, no preamble. \
Example: ["golden hour", "nostalgic", "friends"]`,
      });

      const anthropicKey = Deno.env.get("ANTHROPIC_API_KEY");
      const response = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-api-key": anthropicKey!,
          "anthropic-version": "2023-06-01",
        },
        body: JSON.stringify({
          model: "claude-sonnet-4-6",
          max_tokens: 64,
          messages: [{ role: "user", content }],
        }),
      });

      const data = await response.json();
      const text = data?.content?.[0]?.text ?? "[]";
      const keywords = JSON.parse(text);

      return Response.json({ keywords });
    } catch (e) {
      return Response.json({ error: String(e) }, { status: 500 });
    }
  },
};
