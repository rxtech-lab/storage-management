import { notFound, redirect } from "next/navigation";
import { headers } from "next/headers";
import { Metadata } from "next";
import { auth } from "@/auth";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { MapPin, User, Tag, Lock, Calendar } from "lucide-react";
import { LocationDisplay } from "@/components/maps/location-display";
import { getItem } from "@/lib/actions/item-actions";
import { getLocation } from "@/lib/actions/location-actions";
import { getItemContents } from "@/lib/actions/content-actions";
import { isEmailWhitelisted } from "@/lib/actions/whitelist-actions";
import { signImageUrlsAction } from "@/lib/actions/s3-upload-actions";
import { formatDistanceToNow, format } from "date-fns";

interface PreviewPageProps {
  params: Promise<{ id: string }>;
}

export async function generateMetadata({
  params,
}: PreviewPageProps): Promise<Metadata> {
  const { id } = await params;
  const item = await getItem(parseInt(id));

  if (!item) {
    return { title: "Item Not Found" };
  }

  const appClipBundleId = process.env.APPLE_APP_CLIP_BUNDLE_ID;

  return {
    title: item.title,
    description: item.description || `View ${item.title}`,
    ...(appClipBundleId && {
      other: {
        "apple-itunes-app": `app-clip-bundle-id=${appClipBundleId}, app-clip-display=card`,
      },
    }),
    openGraph: {
      title: item.title,
      description: item.description || undefined,
      images: item.images?.[0] ? [item.images[0]] : undefined,
    },
  };
}

export default async function PreviewPage({ params }: PreviewPageProps) {
  const { id } = await params;
  const itemId = parseInt(id);

  // Redirect to API if client requests JSON
  const headersList = await headers();
  const accept = headersList.get("accept") || "";
  if (accept.includes("application/json")) {
    redirect(`/api/v1/items/${id}`);
  }

  const item = await getItem(itemId);

  if (!item) {
    notFound();
  }

  // Check visibility
  if (item.visibility === "privateAccess") {
    const session = await auth();

    if (!session?.user) {
      // Redirect to login with return URL
      console.log("User not signed in, redirecting to login");
      redirect(`/login?callbackUrl=/preview/item/${itemId}`);
    }

    // Check whitelist if user has email. Otherwise, just allow access
    const hasAccess = session.user.email
      ? await isEmailWhitelisted(itemId, session.user.email)
      : true;

    if (!hasAccess) {
      return (
        <div className="min-h-screen flex items-center justify-center bg-muted/30">
          <Card className="max-w-md">
            <CardContent className="pt-6 text-center">
              <Lock className="h-12 w-12 mx-auto text-muted-foreground mb-4" />
              <h1 className="text-xl font-bold mb-2">Access Restricted</h1>
              <p className="text-muted-foreground mb-4">
                You don&apos;t have permission to view this item. Contact the
                owner to request access.
              </p>
              <p className="text-sm text-muted-foreground">
                Signed in as: {session.user.email}
              </p>
            </CardContent>
          </Card>
        </div>
      );
    }
  }

  // Fetch additional data for display
  const [location, contents, signedImagesResult] = await Promise.all([
    item.locationId ? getLocation(item.locationId) : null,
    getItemContents(itemId),
    item.images && item.images.length > 0
      ? signImageUrlsAction(item.images)
      : null,
  ]);

  // Create map for signed URLs
  const signedImageMap = new Map<string, string>();
  if (signedImagesResult?.data) {
    signedImagesResult.data.forEach((r) => {
      signedImageMap.set(r.originalUrl, r.signedUrl);
    });
  }

  return (
    <div className="min-h-screen bg-muted/30 py-8">
      <div className="max-w-4xl mx-auto px-4">
        {/* Header */}
        <div className="mb-8">
          <div className="flex items-center gap-2 mb-2">
            {item.visibility === "privateAccess" && (
              <Badge variant="secondary" className="gap-1">
                <Lock className="h-3 w-3" />
                Private
              </Badge>
            )}
            {item.category && (
              <Badge variant="outline">{item.category.name}</Badge>
            )}
          </div>
          <h1 className="text-4xl font-bold mb-2">{item.title}</h1>
          <div className="flex items-center gap-4 text-sm text-muted-foreground">
            {item.author && (
              <span className="flex items-center gap-1">
                <User className="h-4 w-4" />
                {item.author.name}
              </span>
            )}
            <span className="flex items-center gap-1">
              <Calendar className="h-4 w-4" />
              {format(new Date(item.createdAt), "MMM d, yyyy")}
            </span>
          </div>
        </div>

        {/* Images */}
        {item.images && item.images.length > 0 && (
          <div className="mb-8">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {item.images.map((image, index) => (
                <img
                  key={index}
                  src={signedImageMap.get(image) || image}
                  alt={`${item.title} - Image ${index + 1}`}
                  className="w-full h-64 object-cover rounded-lg"
                />
              ))}
            </div>
          </div>
        )}

        {/* Description */}
        {item.description && (
          <Card className="mb-8">
            <CardHeader>
              <CardTitle>Description</CardTitle>
            </CardHeader>
            <CardContent>
              <p className="whitespace-pre-wrap">{item.description}</p>
            </CardContent>
          </Card>
        )}

        {/* Details */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
          {item.price !== null && (
            <Card size="sm">
              <CardContent>
                <p className="text-sm text-muted-foreground mb-1">Price</p>
                <p className="text-2xl font-bold">${item.price.toFixed(2)}</p>
              </CardContent>
            </Card>
          )}

          {item.location && (
            <Card size="sm">
              <CardContent>
                <p className="text-sm text-muted-foreground mb-1 flex items-center gap-1">
                  <MapPin className="h-4 w-4" />
                  Location
                </p>
                <p className="font-medium">{item.location.title}</p>
              </CardContent>
            </Card>
          )}

          {item.category && (
            <Card size="sm">
              <CardContent>
                <p className="text-sm text-muted-foreground mb-1 flex items-center gap-1">
                  <Tag className="h-4 w-4" />
                  Category
                </p>
                <p className="font-medium">{item.category.name}</p>
              </CardContent>
            </Card>
          )}

          {item.author && (
            <Card size="sm">
              <CardContent>
                <p className="text-sm text-muted-foreground mb-1 flex items-center gap-1">
                  <User className="h-4 w-4" />
                  Author
                </p>
                <p className="font-medium">{item.author.name}</p>
              </CardContent>
            </Card>
          )}
        </div>

        {/* Map */}
        {location && (
          <Card className="mb-8">
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <MapPin className="h-5 w-5" />
                Location
              </CardTitle>
            </CardHeader>
            <CardContent>
              <LocationDisplay
                latitude={location.latitude}
                longitude={location.longitude}
                title={location.title}
                height="300px"
              />
            </CardContent>
          </Card>
        )}

        {/* Contents */}
        {contents.length > 0 && (
          <Card className="mb-8">
            <CardHeader>
              <CardTitle>Contents ({contents.length})</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                {contents.map((content) => {
                  const data = content.data as {
                    title: string;
                    description?: string;
                  };
                  return (
                    <div
                      key={content.id}
                      className="flex items-center justify-between p-3 rounded-lg border"
                    >
                      <div>
                        <p className="font-medium">
                          {data.title || "Untitled"}
                        </p>
                        {data.description && (
                          <p className="text-sm text-muted-foreground">
                            {data.description}
                          </p>
                        )}
                      </div>
                      <Badge variant="outline">{content.type}</Badge>
                    </div>
                  );
                })}
              </div>
            </CardContent>
          </Card>
        )}

        {/* Footer */}
        <div className="text-center text-sm text-muted-foreground">
          <p>
            Last updated{" "}
            {formatDistanceToNow(new Date(item.updatedAt), { addSuffix: true })}
          </p>
        </div>
      </div>
    </div>
  );
}
