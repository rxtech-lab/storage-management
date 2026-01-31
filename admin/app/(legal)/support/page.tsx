import { Metadata } from "next";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Mail } from "lucide-react";

export const metadata: Metadata = {
  title: "Support - Storage Management",
  description: "Get help with Storage Management",
};

export default function SupportPage() {
  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-3xl font-bold tracking-tight">Support</h1>
        <p className="mt-2 text-muted-foreground">
          We&apos;re here to help. Reach out to us with any questions or
          concerns.
        </p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Mail className="h-5 w-5" />
            Email Support
          </CardTitle>
          <CardDescription>
            Send us an email and we&apos;ll get back to you as soon as possible.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <Button asChild>
            <a href="mailto:support@rxlab.app">support@rxlab.app</a>
          </Button>
        </CardContent>
      </Card>
    </div>
  );
}
