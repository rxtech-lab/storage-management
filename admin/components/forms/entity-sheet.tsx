"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
  SheetTrigger,
  SheetFooter,
} from "@/components/ui/sheet";
import { Plus, Loader2 } from "lucide-react";
import { toast } from "sonner";
import { createCategoryAction } from "@/lib/actions/category-actions";
import { createLocationAction } from "@/lib/actions/location-actions";
import { createAuthorAction } from "@/lib/actions/author-actions";
import { LocationPicker } from "@/components/maps/location-picker";

export type EntityType = "category" | "location" | "author";

interface EntitySheetProps {
  type: EntityType;
  onCreated?: (entity: { id: number; name?: string; title?: string }) => void;
  trigger?: React.ReactNode;
}

export function EntitySheet({ type, onCreated, trigger }: EntitySheetProps) {
  const [open, setOpen] = useState(false);
  const [loading, setLoading] = useState(false);
  const [formData, setFormData] = useState({
    name: "",
    title: "",
    description: "",
    bio: "",
    latitude: 0,
    longitude: 0,
  });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);

    try {
      let result;

      switch (type) {
        case "category":
          result = await createCategoryAction({
            name: formData.name,
            description: formData.description || null,
          });
          break;
        case "location":
          result = await createLocationAction({
            title: formData.title,
            latitude: formData.latitude,
            longitude: formData.longitude,
          });
          break;
        case "author":
          result = await createAuthorAction({
            name: formData.name,
            bio: formData.bio || null,
          });
          break;
      }

      if (result.success && result.data) {
        toast.success(
          `${type.charAt(0).toUpperCase() + type.slice(1)} created`,
        );
        onCreated?.(
          result.data as { id: number; name?: string; title?: string },
        );
        setOpen(false);
        setFormData({
          name: "",
          title: "",
          description: "",
          bio: "",
          latitude: 0,
          longitude: 0,
        });
      } else {
        toast.error(result.error || `Failed to create ${type}`);
      }
    } catch {
      toast.error(`Failed to create ${type}`);
    } finally {
      setLoading(false);
    }
  };

  const titles: Record<EntityType, { title: string; description: string }> = {
    category: {
      title: "New Category",
      description: "Create a new category to organize your items.",
    },
    location: {
      title: "New Location",
      description: "Add a new storage location.",
    },
    author: {
      title: "New Author",
      description: "Add a new author or creator.",
    },
  };

  return (
    <Sheet open={open} onOpenChange={setOpen}>
      <SheetTrigger asChild>
        {trigger || (
          <Button variant="outline" size="sm" type="button">
            <Plus className="h-4 w-4" />
          </Button>
        )}
      </SheetTrigger>
      <SheetContent className="sm:max-w-lg max-w-3xl overflow-y-auto">
        <SheetHeader>
          <SheetTitle>{titles[type].title}</SheetTitle>
          <SheetDescription>{titles[type].description}</SheetDescription>
        </SheetHeader>
        <form onSubmit={handleSubmit} className="space-y-4 px-2 pb-6">
          {type === "category" && (
            <>
              <div className="space-y-2">
                <Label htmlFor="name">Name</Label>
                <Input
                  id="name"
                  value={formData.name}
                  onChange={(e) =>
                    setFormData({ ...formData, name: e.target.value })
                  }
                  placeholder="Category name"
                  required
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="description">Description</Label>
                <Textarea
                  id="description"
                  value={formData.description}
                  onChange={(e) =>
                    setFormData({ ...formData, description: e.target.value })
                  }
                  placeholder="Optional description"
                />
              </div>
            </>
          )}

          {type === "location" && (
            <>
              <div className="space-y-2">
                <Label htmlFor="title">Title</Label>
                <Input
                  id="title"
                  value={formData.title}
                  onChange={(e) =>
                    setFormData({ ...formData, title: e.target.value })
                  }
                  placeholder="Location title"
                  required
                />
              </div>
              <div className="space-y-2">
                <Label>Location</Label>
                <LocationPicker
                  value={
                    formData.latitude && formData.longitude
                      ? {
                          latitude: formData.latitude,
                          longitude: formData.longitude,
                        }
                      : undefined
                  }
                  onChange={({ latitude, longitude }) =>
                    setFormData({ ...formData, latitude, longitude })
                  }
                />
              </div>
            </>
          )}

          {type === "author" && (
            <>
              <div className="space-y-2">
                <Label htmlFor="name">Name</Label>
                <Input
                  id="name"
                  value={formData.name}
                  onChange={(e) =>
                    setFormData({ ...formData, name: e.target.value })
                  }
                  placeholder="Author name"
                  required
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="bio">Bio</Label>
                <Textarea
                  id="bio"
                  value={formData.bio}
                  onChange={(e) =>
                    setFormData({ ...formData, bio: e.target.value })
                  }
                  placeholder="Optional bio"
                />
              </div>
            </>
          )}

          <SheetFooter>
            <Button type="submit" disabled={loading}>
              {loading && <Loader2 className="h-4 w-4 mr-2 animate-spin" />}
              Create {type.charAt(0).toUpperCase() + type.slice(1)}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  );
}
