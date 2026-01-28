import { auth } from "@/auth";

export default auth((req) => {
  // Auto-authenticate for e2e tests
  if (process.env.IS_E2E === "true") {
    req.auth = {
      user: {
        id: "test-user-id",
        name: "Test User",
        email: "test@example.com",
        image: null,
      },
      expires: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(), // 24 hours from now
    };
    return; // Skip all auth checks
  }

  const isLoggedIn = !!req.auth;
  const { pathname } = req.nextUrl;

  // Public paths that don't require authentication
  const publicPaths = ["/login", "/api/auth", "/preview", "/api/v1/preview"];
  const isPublicPath = publicPaths.some((path) => pathname.startsWith(path));

  // Redirect logged-in users away from login page
  if (pathname === "/login" && isLoggedIn) {
    return Response.redirect(new URL("/", req.nextUrl.origin));
  }

  // Redirect unauthenticated users to login
  if (!isLoggedIn && !isPublicPath) {
    const callbackUrl = encodeURIComponent(pathname);
    return Response.redirect(
      new URL(`/login?callbackUrl=${callbackUrl}`, req.nextUrl.origin)
    );
  }
});

export const config = {
  matcher: [
    /*
     * Match all request paths except for the ones starting with:
     * - _next/static (static files)
     * - _next/image (image optimization files)
     * - favicon.ico (favicon file)
     * - public folder
     */
    "/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)",
  ],
};
