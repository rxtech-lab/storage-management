export async function GET() {
  const appClipBundleId = process.env.APPLE_APP_CLIP_BUNDLE_ID;
  const appBundleId = process.env.APPLE_APP_BUNDLE_ID;

  if (!appClipBundleId || !appBundleId) {
    return new Response(
      JSON.stringify({ error: "Apple bundle IDs not configured" }),
      {
        status: 500,
        headers: { "Content-Type": "application/json" },
      }
    );
  }

  const appSiteAssociation = {
    appclips: {
      apps: [appClipBundleId],
    },
    webcredentials: {
      apps: [appBundleId],
    },
  };

  return new Response(JSON.stringify(appSiteAssociation), {
    headers: { "Content-Type": "application/json" },
  });
}
