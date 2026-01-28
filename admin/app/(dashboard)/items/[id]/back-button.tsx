import Link from "next/link";
import { Button } from "@/components/ui/button";
import { ArrowLeft } from "lucide-react";

export function BackButton() {
  return (
    <Link href="/items">
      <Button
        variant="ghost"
        size="sm"
        className="gap-2 [animation-range:0px_20px] [animation-timeline:scroll()] animate-[scrolled-button_linear_forwards]"
      >
        <ArrowLeft className="h-4 w-4" />
        Back to Items
      </Button>
    </Link>
  );
}
