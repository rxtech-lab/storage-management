"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Textarea } from "@/components/ui/textarea";
import { Badge } from "@/components/ui/badge";
import { Loader2, Plus, Trash, Mail, Upload } from "lucide-react";
import { toast } from "sonner";
import {
  addToWhitelistAction,
  removeFromWhitelistAction,
  bulkAddToWhitelistAction,
} from "@/lib/actions/whitelist-actions";
import type { ItemWhitelist } from "@/lib/db";

interface WhitelistFormProps {
  itemId: number;
  whitelist: ItemWhitelist[];
  onUpdate?: () => void;
}

export function WhitelistForm({
  itemId,
  whitelist,
  onUpdate,
}: WhitelistFormProps) {
  const [loading, setLoading] = useState(false);
  const [email, setEmail] = useState("");
  const [bulkEmails, setBulkEmails] = useState("");
  const [showBulk, setShowBulk] = useState(false);

  const handleAddEmail = async () => {
    if (!email.trim()) {
      toast.error("Please enter an email");
      return;
    }

    // Basic email validation
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email.trim())) {
      toast.error("Please enter a valid email");
      return;
    }

    setLoading(true);
    try {
      const result = await addToWhitelistAction({
        itemId,
        email: email.trim(),
      });

      if (result.success) {
        toast.success("Email added to whitelist");
        setEmail("");
        onUpdate?.();
      } else {
        toast.error(result.error || "Failed to add email");
      }
    } catch {
      toast.error("Failed to add email");
    } finally {
      setLoading(false);
    }
  };

  const handleBulkAdd = async () => {
    if (!bulkEmails.trim()) {
      toast.error("Please enter emails");
      return;
    }

    // Split by newlines, commas, or semicolons
    const emails = bulkEmails
      .split(/[\n,;]+/)
      .map((e) => e.trim())
      .filter(Boolean);

    if (emails.length === 0) {
      toast.error("No valid emails found");
      return;
    }

    setLoading(true);
    try {
      const result = await bulkAddToWhitelistAction(itemId, emails);

      if (result.success) {
        toast.success(`Added ${result.added} email(s) to whitelist`);
        setBulkEmails("");
        setShowBulk(false);
        onUpdate?.();
      } else {
        toast.error(result.error || "Failed to add emails");
      }
    } catch {
      toast.error("Failed to add emails");
    } finally {
      setLoading(false);
    }
  };

  const handleRemoveEmail = async (id: number) => {
    setLoading(true);
    try {
      const result = await removeFromWhitelistAction(id);

      if (result.success) {
        toast.success("Email removed from whitelist");
        onUpdate?.();
      } else {
        toast.error(result.error || "Failed to remove email");
      }
    } catch {
      toast.error("Failed to remove email");
    } finally {
      setLoading(false);
    }
  };

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-lg flex items-center gap-2">
          <Mail className="h-5 w-5" />
          Access Whitelist
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        <p className="text-sm text-muted-foreground">
          Only these email addresses can view this private item.
        </p>

        {whitelist.length > 0 && (
          <div className="flex flex-wrap gap-2">
            {whitelist.map((entry) => (
              <Badge
                key={entry.id}
                variant="secondary"
                className="flex items-center gap-1 pr-1"
              >
                {entry.email}
                <button
                  onClick={() => handleRemoveEmail(entry.id)}
                  disabled={loading}
                  className="ml-1 p-0.5 rounded-full hover:bg-muted"
                >
                  <Trash className="h-3 w-3" />
                </button>
              </Badge>
            ))}
          </div>
        )}

        {!showBulk ? (
          <div className="flex gap-2">
            <Input
              type="email"
              placeholder="Enter email address"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === "Enter") {
                  e.preventDefault();
                  handleAddEmail();
                }
              }}
            />
            <Button onClick={handleAddEmail} disabled={loading}>
              {loading ? (
                <Loader2 className="h-4 w-4 animate-spin" />
              ) : (
                <Plus className="h-4 w-4" />
              )}
            </Button>
            <Button variant="outline" onClick={() => setShowBulk(true)}>
              <Upload className="h-4 w-4" />
            </Button>
          </div>
        ) : (
          <div className="space-y-2">
            <Textarea
              placeholder="Enter emails (one per line, or comma/semicolon separated)"
              value={bulkEmails}
              onChange={(e) => setBulkEmails(e.target.value)}
              rows={5}
            />
            <div className="flex gap-2">
              <Button onClick={handleBulkAdd} disabled={loading}>
                {loading ? (
                  <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                ) : (
                  <Plus className="h-4 w-4 mr-2" />
                )}
                Add All
              </Button>
              <Button
                variant="outline"
                onClick={() => {
                  setShowBulk(false);
                  setBulkEmails("");
                }}
              >
                Cancel
              </Button>
            </div>
          </div>
        )}
      </CardContent>
    </Card>
  );
}
