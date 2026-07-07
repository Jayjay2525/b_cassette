import "@supabase/functions-js/edge-runtime.d.ts";

export default {
  fetch: async (req: Request) => {
    if (req.method !== "POST") {
      return new Response("Method not allowed", { status: 405 });
    }

    try {
      const { keywords, photoCount, cassetteID, cassetteName, userID, deviceToken } =
        await req.json() as {
          keywords: string[];
          photoCount: number;
          cassetteID: string;
          cassetteName: string;
          userID: string;
          deviceToken?: string;
        };

      if (!keywords || keywords.length === 0) {
        return Response.json({ error: "keywords required" }, { status: 400 });
      }

      const duration = photoCount <= 15 ? 30 : photoCount <= 30 ? 60 : 120;
      const prompt = keywords.join(", ");
      const musicGPTKey = Deno.env.get("MUSICGPT_API_KEY");
      const supabaseURL = Deno.env.get("SUPABASE_URL");
      const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

      const body: Record<string, unknown> = {
        prompt,
        make_instrumental: true,
        output_length: duration,
        webhook_url: `${supabaseURL}/functions/v1/musicgpt-webhook`,
      };

      const response = await fetch("https://api.musicgpt.com/api/public/v1/MusicAI", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": musicGPTKey!,
        },
        body: JSON.stringify(body),
      });

      const data = await response.json();
      const taskId = data?.task_id as string | undefined;
      if (!taskId) {
        return Response.json({ error: "no task_id from MusicGPT", detail: data }, { status: 502 });
      }

      // cassette_music 테이블에 삽입
      const row: Record<string, string> = {
        cassette_id: cassetteID,
        task_id: taskId,
        user_id: userID,
        status: "generating",
        cassette_name: cassetteName,
      };
      if (deviceToken) row["device_token"] = deviceToken;

      await fetch(`${supabaseURL}/rest/v1/cassette_music`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "apikey": supabaseKey!,
          "Authorization": `Bearer ${supabaseKey}`,
        },
        body: JSON.stringify(row),
      });

      return Response.json({ taskId });
    } catch (e) {
      return Response.json({ error: String(e) }, { status: 500 });
    }
  },
};
