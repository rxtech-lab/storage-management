"use client";

import { useState, useEffect } from "react";
import QRCode from "qrcode";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { QrCode, Download, Copy } from "lucide-react";
import { toast } from "sonner";

interface QRCodeGeneratorProps {
  itemId: number;
  itemTitle: string;
}

export function QRCodeGenerator({ itemId, itemTitle }: QRCodeGeneratorProps) {
  const [qrDataUrl, setQrDataUrl] = useState<string>("");
  const [previewUrl, setPreviewUrl] = useState<string>("");

  useEffect(() => {
    const baseUrl = typeof window !== "undefined" ? window.location.origin : "";
    const url = `${baseUrl}/preview/${itemId}`;
    setPreviewUrl(url);

    QRCode.toDataURL(url, {
      width: 400,
      margin: 2,
      color: {
        dark: "#000000",
        light: "#ffffff",
      },
    })
      .then(setQrDataUrl)
      .catch(console.error);
  }, [itemId]);

  const handleDownload = () => {
    if (!qrDataUrl) return;

    const link = document.createElement("a");
    link.download = `qr-code-${itemId}-${itemTitle.replace(/\s+/g, "-")}.png`;
    link.href = qrDataUrl;
    link.click();
  };

  const handleCopyUrl = async () => {
    try {
      await navigator.clipboard.writeText(previewUrl);
      toast.success("Preview URL copied to clipboard");
    } catch {
      toast.error("Failed to copy URL");
    }
  };

  return (
    <Dialog>
      <DialogTrigger asChild>
        <Button variant="outline" size="sm">
          <QrCode className="h-4 w-4 mr-2" />
          QR Code
        </Button>
      </DialogTrigger>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>QR Code for {itemTitle}</DialogTitle>
          <DialogDescription>
            Scan this QR code to view the item preview page.
          </DialogDescription>
        </DialogHeader>
        <div className="flex flex-col items-center gap-4 py-4">
          {qrDataUrl && (
            <img
              src={qrDataUrl}
              alt={`QR Code for ${itemTitle}`}
              className="w-64 h-64 border rounded-lg"
            />
          )}
          <p className="text-sm text-muted-foreground break-all text-center max-w-full px-4">
            {previewUrl}
          </p>
          <div className="flex gap-2">
            <Button variant="outline" onClick={handleCopyUrl}>
              <Copy className="h-4 w-4 mr-2" />
              Copy URL
            </Button>
            <Button onClick={handleDownload}>
              <Download className="h-4 w-4 mr-2" />
              Download
            </Button>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
}
