// supabase/functions/send_push/index.ts

import { serve } from "https://deno.land/std@0.201.0/http/server.ts";
import { encode as b64url } from "https://deno.land/std@0.201.0/encoding/base64url.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

/**
 * Из PEM-строки в ArrayBuffer (для WebCrypto)
 */
function pemToArrayBuffer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/-----(BEGIN|END)[^-]+-----/g, "")
    .replace(/\s/g, "");
  // в Deno globalThis.atob работает
  const bin = globalThis.atob(b64);
  const arr = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) {
    arr[i] = bin.charCodeAt(i);
  }
  return arr.buffer;
}

serve(async (req) => {
  try {
    const { title, body, discountId } = await req.json();

    // берём из окружения все нужные переменные
    const projectId = Deno.env.get("FCM_PROJECT_ID")!;
    const clientEmail = Deno.env.get("FCM_SA_CLIENT_EMAIL")!;
    const privateKey = Deno.env.get("FCM_SA_PRIVATE_KEY")!; // полный PEM
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    // инициализируем Supabase-клиент с service-role
    const supabase = createClient(supabaseUrl, supabaseKey);

    // 1) достаём ВСЕ токены
    const { data: tokenRows, error: fetchErr } = await supabase
      .from("user_tokens")
      .select("fcm_token")
      .not("fcm_token", "is", null);

    if (fetchErr) throw fetchErr;
    const tokens = (tokenRows || [])
      .map((r: any) => r.fcm_token as string)
      .filter((t) => !!t);

    if (tokens.length === 0) {
      return new Response(
        JSON.stringify({ success: true, info: "no FCM tokens to send" }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    // 2) собираем JWT для OAuth2
    const now = Math.floor(Date.now() / 1000);
    const header = b64url(
      JSON.stringify({ alg: "RS256", typ: "JWT" })
    );
    const payload = b64url(
      JSON.stringify({
        iss: clientEmail,
        scope: "https://www.googleapis.com/auth/firebase.messaging",
        aud: "https://oauth2.googleapis.com/token",
        iat: now,
        exp: now + 3600,
      })
    );
    const toSign = `${header}.${payload}`;
    const key = await crypto.subtle.importKey(
      "pkcs8",
      pemToArrayBuffer(privateKey),
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
      false,
      ["sign"]
    );
    const sig = new Uint8Array(
      await crypto.subtle.sign(
        "RSASSA-PKCS1-v1_5",
        key,
        new TextEncoder().encode(toSign)
      )
    );
    const jwt = `${toSign}.${b64url(sig)}`;

    // 3) обмен JWT на access_token
    const tokenRes = await fetch(
      "https://oauth2.googleapis.com/token",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: new URLSearchParams({
          grant_type:
            "urn:ietf:params:oauth:grant-type:jwt-bearer",
          assertion: jwt,
        }),
      }
    );
    if (!tokenRes.ok) {
      const errText = await tokenRes.text();
      throw new Error("OAuth token fetch failed: " + errText);
    }
    const { access_token } = await tokenRes.json();

    // 4) шлём пуш на каждый токен
    const results: any[] = [];
    for (const tok of tokens) {
      const fcmRes = await fetch(
        `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${access_token}`,
          },
          body: JSON.stringify({
            message: {
              token: tok,
              notification: { title, body },
              data: discountId
                ? { discountId: discountId.toString() }
                : {},
            },
          }),
        }
      );
      let json: any;
      try {
        json = await fcmRes.json();
      } catch {
        json = await fcmRes.text();
      }
      results.push({
        token: tok,
        status: fcmRes.status,
        response: json,
      });
    }

    return new Response(
      JSON.stringify({
        success: true,
        sent: results.filter((r) => r.status === 200).length,
        failed: results.filter((r) => r.status !== 200).length,
        results,
      }),
      {
        status: 200,
        headers: { "Content-Type": "application/json" },
      }
    );
  } catch (e: any) {
    console.error("send_push error:", e);
    return new Response(
      JSON.stringify({ error: e.message ?? String(e) }),
      {
        status: 500,
        headers: { "Content-Type": "application/json" },
      }
    );
  }
});
