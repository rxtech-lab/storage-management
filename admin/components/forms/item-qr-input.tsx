"use client";
import { BrowserMultiFormatReader } from "@zxing/browser";
import type { ItemAIResponse } from "@/lib/schemas/item-ai";
import { BarcodeLookupResponseSchema } from "@/lib/schemas/barcode";
import { useState } from "react";
import { toast } from "sonner";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { Dialog, DialogContent, DialogTitle, DialogDescription } from "@/components/ui/dialog";

export function ItemQRInput({ value, onChange, onLookup }: { value: string; onChange: (value: string) => void; onLookup: (result: ItemAIResponse) => void }) {
  const [open, setOpen] = useState(false);
  const [decoded, setDecoded] = useState("");
  const [busy, setBusy] = useState(false);
  async function scan(file?: File) {
    if (!file) return;
    setBusy(true);
    setDecoded("");
    try {
      const url = URL.createObjectURL(file);
      try {
        const result = await new BrowserMultiFormatReader().decodeFromImageUrl(url);
        setDecoded(result.getText());
        await lookup(result.getText());
      } finally { URL.revokeObjectURL(url); }
    } catch (error) { toast.error(error instanceof Error ? error.message : "Could not scan image"); }
    finally { setBusy(false); }
  }
  async function lookup(code: string) {
    onChange(code);
    setBusy(true);
    try {
      const response = await fetch("/api/v1/items/lookup", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ barcode: code, inventory: false }) });
      const body = await response.json();
      if (!response.ok) throw new Error(body.error || "Could not look up barcode");
      const data = BarcodeLookupResponseSchema.parse(body);
      if (!data.result) throw new Error("No book or product found. You can enter its details manually.");
      setOpen(false);
      onLookup(data.result);
    } catch (error) { toast.error(error instanceof Error ? error.message : "Could not look up barcode"); }
    finally { setBusy(false); }
  }
  return <div className="space-y-2">
    <Label htmlFor="originalQrCode">Barcode or QR Code</Label>
    <div className="flex gap-2">
      <Input id="originalQrCode" data-testid="item-qr-input" value={value} onChange={e => onChange(e.target.value)} placeholder="Barcode, ISBN, or QR value" />
      <Button type="button" variant="outline" disabled={busy} onClick={() => { setDecoded(""); setOpen(true); }}>Scan barcode</Button>
      <Button type="button" variant="outline" disabled={busy || !value.trim()} onClick={() => void lookup(value)}>Look up</Button>
    </div>
    <Dialog open={open} onOpenChange={next => { if (!busy) setOpen(next); }}>
      <DialogContent showCloseButton={!busy} onPointerDownOutside={e => { if (busy) e.preventDefault(); }} onEscapeKeyDown={e => { if (busy) e.preventDefault(); }}>
        <DialogTitle>Scan barcode</DialogTitle>
        <DialogDescription>Choose a barcode or QR image to look up book or product details.</DialogDescription>
        <Input type="file" accept="image/*" aria-label="Barcode or QR code image" onChange={e => void scan(e.target.files?.[0])} disabled={busy} />
        {decoded && <><p className="break-all" data-testid="qr-decoded-value">{decoded}</p><Button type="button" disabled={busy} onClick={() => void lookup(decoded)}>Look up item</Button><Button type="button" variant="outline" disabled={busy} onClick={() => { onChange(decoded); setOpen(false); }}>Use QR code</Button></>}
        {busy && <div role="status" className="absolute inset-0 grid place-items-center bg-background/90 rounded-xl">Looking up barcode…</div>}
      </DialogContent>
    </Dialog>
    {busy && !open && <div role="status" className="fixed inset-0 z-50 grid place-items-center bg-background/90">Looking up barcode…</div>}
  </div>;
}
