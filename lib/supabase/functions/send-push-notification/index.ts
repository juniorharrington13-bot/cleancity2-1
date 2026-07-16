// Supabase Edge Function: forwards an in-app notification to OneSignal so it
// also reaches the device's system notification tray, not just the in-app
// bell/list. Invoked asynchronously (via pg_net) by a trigger on
// public.notifications, see the accompanying migration.
//
// Requires two Edge Function secrets (Project Settings -> Edge Functions ->
// Secrets in the Supabase dashboard): ONESIGNAL_APP_ID, ONESIGNAL_REST_API_KEY.
// Without them this function responds 200 but skips sending (fails soft, so a
// misconfigured push setup never breaks the underlying app feature).

Deno.serve(async (req: Request) => {
  const appId = Deno.env.get('ONESIGNAL_APP_ID');
  const restApiKey = Deno.env.get('ONESIGNAL_REST_API_KEY');

  if (!appId || !restApiKey) {
    return new Response(
      JSON.stringify({ skipped: true, reason: 'ONESIGNAL_APP_ID/ONESIGNAL_REST_API_KEY not configured' }),
      { status: 200, headers: { 'Content-Type': 'application/json' } },
    );
  }

  let payload: { user_id?: string; title?: string; body?: string; type?: string; related_id?: string };
  try {
    payload = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: 'Invalid JSON body' }), { status: 400 });
  }

  const { user_id, title, body, type, related_id } = payload;
  if (!user_id || !title || !body) {
    return new Response(JSON.stringify({ error: 'user_id, title and body are required' }), { status: 400 });
  }

  const oneSignalResponse = await fetch('https://onesignal.com/api/v1/notifications', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Basic ${restApiKey}`,
    },
    body: JSON.stringify({
      app_id: appId,
      target_channel: 'push',
      include_aliases: { external_id: [user_id] },
      headings: { en: title, fr: title },
      contents: { en: body, fr: body },
      data: { type: type ?? null, related_id: related_id ?? null },
    }),
  });

  const result = await oneSignalResponse.json().catch(() => ({}));
  return new Response(JSON.stringify(result), {
    status: oneSignalResponse.ok ? 200 : 502,
    headers: { 'Content-Type': 'application/json' },
  });
});
