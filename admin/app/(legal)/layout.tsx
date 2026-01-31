import Link from "next/link";
import { Package } from "lucide-react";

export default function LegalLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="min-h-screen bg-muted/40">
      <header className="border-b bg-background">
        <div className="mx-auto flex max-w-4xl items-center justify-between px-6 py-4">
          <Link href="/" className="flex items-center gap-2">
            <div className="flex h-8 w-8 items-center justify-center rounded-full bg-primary">
              <Package className="h-4 w-4 text-primary-foreground" />
            </div>
            <span className="font-semibold">Storage Management</span>
          </Link>
          <nav className="flex gap-6 text-sm">
            <Link
              href="/support"
              className="text-muted-foreground hover:text-foreground"
            >
              Support
            </Link>
            <Link
              href="/privacy"
              className="text-muted-foreground hover:text-foreground"
            >
              Privacy
            </Link>
            <Link
              href="/terms"
              className="text-muted-foreground hover:text-foreground"
            >
              Terms
            </Link>
          </nav>
        </div>
      </header>
      <main className="mx-auto max-w-4xl px-6 py-12">{children}</main>
      <footer className="border-t bg-background">
        <div className="mx-auto max-w-4xl px-6 py-6 text-center text-sm text-muted-foreground">
          &copy; {new Date().getFullYear()} RxLab. All rights reserved.
        </div>
      </footer>
    </div>
  );
}
