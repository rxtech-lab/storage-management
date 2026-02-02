import { Metadata } from "next";

export const metadata: Metadata = {
  title: "API Documentation - Storage Management",
  description: "REST API documentation for the Storage Management system",
};

export default function ApiDocsPage() {
  return (
    <html lang="en">
      <head>
        <meta charSet="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
      </head>
      <body>
        <script
          id="api-reference"
          data-url="/api/openapi"
          data-configuration={JSON.stringify({
            theme: "purple",
            layout: "modern",
            darkMode: true,
            hiddenClients: ["unirest"],
            defaultHttpClient: {
              targetKey: "javascript",
              clientKey: "fetch",
            },
          })}
        />
        <script src="https://cdn.jsdelivr.net/npm/@scalar/api-reference" />
      </body>
    </html>
  );
}
