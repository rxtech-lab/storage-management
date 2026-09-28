import { cn } from "@/lib/utils";

interface ProgressBarProps {
  value: number;
  className?: string;
  tone?: "default" | "success" | "destructive";
}

export function ProgressBar({ value, className, tone = "default" }: ProgressBarProps) {
  const percent = Math.round(Math.min(Math.max(value, 0), 1) * 100);
  return (
    <div
      role="progressbar"
      aria-valuemin={0}
      aria-valuemax={100}
      aria-valuenow={percent}
      className={cn("h-2 w-full overflow-hidden rounded-full bg-muted", className)}
    >
      <div
        className={cn(
          "h-full rounded-full transition-all",
          tone === "success" && "bg-green-600",
          tone === "destructive" && "bg-destructive",
          tone === "default" && "bg-primary"
        )}
        style={{ width: `${percent}%` }}
      />
    </div>
  );
}
