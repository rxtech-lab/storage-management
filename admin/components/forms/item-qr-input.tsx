"use client";
import { useState } from "react";
import jsQR from "jsqr";
import { toast } from "sonner";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { Dialog, DialogContent, DialogTitle, DialogDescription } from "@/components/ui/dialog";

export function ItemQRInput({ value, onChange }: { value: string; onChange: (value: string) => void }) {
  const [open, setOpen] = useState(false);
  const [decoded, setDecoded] = useState("");
  const [busy, setBusy] = useState(false);
  async function scan(file?: File) {
    if (!file) return;
    setBusy(true);
    setDecoded("");
    try {
      const bitmap = await createImageBitmap(file);
      try {
        const canvas = document.createElement("canvas");
        const scale = Math.min(1, 2000 / Math.max(bitmap.width, bitmap.height));
        canvas.width = bitmap.width * scale; canvas.height = bitmap.height * scale;
        const context = canvas.getContext("2d");
        if (!context) throw new Error("Could not read image");
        context.drawImage(bitmap, 0, 0, canvas.width, canvas.height);
        const pixels = context.getImageData(0, 0, canvas.width, canvas.height);
        const result = jsQR(pixels.data, pixels.width, pixels.height);
        if (!result?.data) throw new Error("No QR code found in this image");
        setDecoded(result.data);
      } finally { bitmap.close(); }
    } catch (error) { toast.error(error instanceof Error ? error.message : "Could not scan image"); }
    finally { setBusy(false); }
  }
  return <div className="space-y-2">
    <Label htmlFor="originalQrCode">Original QR Code</Label>
    <div className="flex gap-2">
      <Input id="originalQrCode" data-testid="item-qr-input" value={value} onChange={e => onChange(e.target.value)} placeholder="QR code value or URL" />
      <Button type="button" variant="outline" onClick={() => { setDecoded(""); setOpen(true); }}>Scan QR</Button>
    </div>
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogContent>
        <DialogTitle>Scan QR code</DialogTitle>
        <DialogDescription>Choose a QR image, then review its value before adding it.</DialogDescription>
        <Input type="file" accept="image/*" aria-label="QR code image" onChange={e => void scan(e.target.files?.[0])} disabled={busy} />
        {decoded && <><p className="break-all" data-testid="qr-decoded-value">{decoded}</p><Button type="button" onClick={() => { onChange(decoded); setOpen(false); }}>Use QR code</Button></>}
        {busy && <div role="status" className="absolute inset-0 grid place-items-center bg-background/90 rounded-xl">Reading QR code…</div>}
      </DialogContent>
    </Dialog>
  </div>;
}
