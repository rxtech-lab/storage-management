export async function GET() {
  const teamId = process.env.APPLE_TEAM_ID;
  const appBundleId = process.env.APPLE_APP_BUNDLE_ID;
  const appClipBundleId = process.env.APPLE_APP_CLIP_BUNDLE_ID;

  if (!teamId || !appBundleId || !appClipBundleId) {
    return new Response(
      JSON.stringify({ error: "Apple bundle IDs not configured" }),
      {
        status: 500,
        headers: { "Content-Type": "application/json" },
      }
    );
  }

  const fullAppId = `${teamId}.${appBundleId}`;
  const fullAppClipId = `${teamId}.${appClipBundleId}`;

  const appSiteAssociation = {
    applinks: {
      details: [
        {
          appIDs: [fullAppClipId, fullAppId],
          components: [
            {
              "/": "/preview/*",
              comment: "Item preview pages trigger App Clip",
            },
          ],
        },
      ],
    },
    appclips: {
      apps: [fullAppClipId],
    },
    webcredentials: {
      apps: [fullAppId],
    },
  };

  return new Response(JSON.stringify(appSiteAssociation), {
    headers: { "Content-Type": "application/json" },
  });
}
