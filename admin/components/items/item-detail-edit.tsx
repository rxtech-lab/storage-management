"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Switch } from "@/components/ui/switch";
import { Loader2, X, Check } from "lucide-react";
import { toast } from "sonner";
import { EntitySheet } from "@/components/forms/entity-sheet";
import { ParentItemCombobox } from "@/components/forms/parent-item-combobox";
import {
  updateItemAction,
  type ItemWithRelations,
} from "@/lib/actions/item-actions";
import type { Category, Location, Author } from "@/lib/db";

const CURRENCIES = [
  "USD",
  "EUR",
  "GBP",
  "JPY",
  "CNY",
  "CAD",
  "AUD",
  "CHF",
  "HKD",
  "SGD",
  "TWD",
] as const;

const itemSchema = z.object({
  title: z.string().min(1, "Title is required"),
  description: z.string().optional(),
  originalQrCode: z.string().optional(),
  categoryId: z.number().nullable().optional(),
  locationId: z.number().nullable().optional(),
  authorId: z.number().nullable().optional(),
  parentId: z.number().nullable().optional(),
  price: z.number().nullable().optional(),
  currency: z.string().optional(),
  visibility: z.enum(["public", "private"]),
  images: z.array(z.string()).optional(),
});

type ItemFormData = z.infer<typeof itemSchema>;

interface ItemDetailEditProps {
  item: ItemWithRelations;
  categories: Category[];
  locations: Location[];
  authors: Author[];
  onSave: () => void;
  onCancel: () => void;
}

export function ItemDetailEdit({
  item,
  categories: initialCategories,
  locations: initialLocations,
  authors: initialAuthors,
  onSave,
  onCancel,
}: ItemDetailEditProps) {
  const router = useRouter();
  const [isPending, startTransition] = useTransition();
  const [categories, setCategories] = useState(initialCategories);
  const [locations, setLocations] = useState(initialLocations);
  const [authors, setAuthors] = useState(initialAuthors);

  const {
    register,
    handleSubmit,
    formState: { errors },
    setValue,
    watch,
  } = useForm<ItemFormData>({
    resolver: zodResolver(itemSchema),
    defaultValues: {
      title: item.title,
      description: item.description ?? "",
      originalQrCode: item.originalQrCode ?? "",
      categoryId: item.categoryId ?? null,
      locationId: item.locationId ?? null,
      authorId: item.authorId ?? null,
      parentId: item.parentId ?? null,
      price: item.price ?? null,
      currency: item.currency ?? "USD",
      visibility: item.visibility,
      images: item.images ?? [],
    },
  });

  const visibility = watch("visibility");
  const currency = watch("currency");
  const categoryId = watch("categoryId");
  const locationId = watch("locationId");
  const authorId = watch("authorId");
  const parentId = watch("parentId");

  const onSubmit = (data: ItemFormData) => {
    startTransition(async () => {
      try {
        const result = await updateItemAction(item.id, data);

        if (result.success) {
          toast.success("Item updated");
          router.refresh();
          onSave();
        } else {
          toast.error(result.error || "Failed to save item");
        }
      } catch {
        toast.error("An error occurred");
      }
    });
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-6 px-1 pb-6" noValidate>
      {/* Basic Info */}
      <div className="space-y-4">
        <div className="space-y-2">
          <Label htmlFor="title">Title *</Label>
          <Input
            id="title"
            {...register("title")}
            placeholder="Item title"
            className="text-lg"
          />
          {errors.title && (
            <p className="text-sm text-destructive">
              {errors.title.message}
            </p>
          )}
        </div>

        <div className="space-y-2">
          <Label htmlFor="description">Description</Label>
          <Textarea
            id="description"
            {...register("description")}
            placeholder="Item description"
            rows={4}
          />
        </div>

        <div className="grid grid-cols-1 gap-4">
          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-2">
              <Label htmlFor="price">Price</Label>
              <Input
                id="price"
                type="number"
                step="0.01"
                {...register("price", {
                  setValueAs: (v) => (v === "" ? null : parseFloat(v)),
                })}
                placeholder="0.00"
              />
            </div>

            <div className="space-y-2">
              <Label>Currency</Label>
              <Select
                value={currency ?? "USD"}
                onValueChange={(v) => setValue("currency", v)}
              >
                <SelectTrigger>
                  <SelectValue placeholder="Select currency" />
                </SelectTrigger>
                <SelectContent>
                  {CURRENCIES.map((curr) => (
                    <SelectItem key={curr} value={curr}>
                      {curr}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          </div>

          <div className="space-y-2">
            <Label htmlFor="originalQrCode">Original QR Code</Label>
            <Input
              id="originalQrCode"
              {...register("originalQrCode")}
              placeholder="Original QR code value"
            />
          </div>
        </div>

        <div className="flex items-center space-x-2">
          <Switch
            id="visibility"
            checked={visibility === "public"}
            onCheckedChange={(checked) =>
              setValue("visibility", checked ? "public" : "private")
            }
          />
          <Label htmlFor="visibility">
            {visibility === "public" ? "Public" : "Private"}
          </Label>
        </div>
      </div>

      {/* Relations */}
      <div className="border-t pt-6 space-y-4">
        <h3 className="font-semibold">Relations</h3>
        <div className="grid grid-cols-1 gap-4">
          <div className="space-y-2">
            <div className="flex items-center justify-between h-9">
              <Label>Category</Label>
              <EntitySheet
                type="category"
                onCreated={(entity) => {
                  setCategories([...categories, entity as Category]);
                  setValue("categoryId", entity.id);
                }}
              />
            </div>
            <Select
              value={categoryId?.toString() ?? "__none__"}
              onValueChange={(v) =>
                setValue("categoryId", v === "__none__" ? null : parseInt(v))
              }
            >
              <SelectTrigger className="w-full">
                <SelectValue placeholder="Select category" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="__none__">None</SelectItem>
                {categories.map((cat) => (
                  <SelectItem key={cat.id} value={cat.id.toString()}>
                    {cat.name}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          <div className="space-y-2">
            <div className="flex items-center justify-between h-9">
              <Label>Location</Label>
              <EntitySheet
                type="location"
                onCreated={(entity) => {
                  setLocations([...locations, entity as Location]);
                  setValue("locationId", entity.id);
                }}
              />
            </div>
            <Select
              value={locationId?.toString() ?? "__none__"}
              onValueChange={(v) =>
                setValue("locationId", v === "__none__" ? null : parseInt(v))
              }
            >
              <SelectTrigger className="w-full">
                <SelectValue placeholder="Select location" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="__none__">None</SelectItem>
                {locations.map((loc) => (
                  <SelectItem key={loc.id} value={loc.id.toString()}>
                    {loc.title}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          <div className="space-y-2">
            <div className="flex items-center justify-between h-9">
              <Label>Author</Label>
              <EntitySheet
                type="author"
                onCreated={(entity) => {
                  setAuthors([...authors, entity as Author]);
                  setValue("authorId", entity.id);
                }}
              />
            </div>
            <Select
              value={authorId?.toString() ?? "__none__"}
              onValueChange={(v) =>
                setValue("authorId", v === "__none__" ? null : parseInt(v))
              }
            >
              <SelectTrigger className="w-full">
                <SelectValue placeholder="Select author" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="__none__">None</SelectItem>
                {authors.map((author) => (
                  <SelectItem key={author.id} value={author.id.toString()}>
                    {author.name}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          <ParentItemCombobox
            value={parentId ?? null}
            onChange={(val) => setValue("parentId", val)}
            excludeId={item.id}
          />
        </div>
      </div>

      {/* Action Buttons */}
      <div className="flex justify-end gap-3 pt-4 border-t">
        <Button
          type="button"
          variant="outline"
          onClick={onCancel}
          disabled={isPending}
          className="gap-2"
        >
          <X className="h-4 w-4" />
          Cancel
        </Button>
        <Button type="submit" disabled={isPending} className="gap-2">
          {isPending ? (
            <Loader2 className="h-4 w-4 animate-spin" />
          ) : (
            <Check className="h-4 w-4" />
          )}
          Save Changes
        </Button>
      </div>
    </form>
  );
}
