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
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Loader2 } from "lucide-react";
import { toast } from "sonner";
import { ImageUpload } from "./image-upload";
import { ParentItemCombobox } from "./parent-item-combobox";
import { CategoryCombobox } from "./category-combobox";
import { AuthorCombobox } from "./author-combobox";
import { LocationCombobox } from "./location-combobox";
import { PositionSheet, type PendingPosition } from "./position-sheet";
import {
  createItemAction,
  updateItemAction,
  type ItemWithRelations,
} from "@/lib/actions/item-actions";
import {
  createPositionAction,
  deletePositionAction,
  type PositionWithSchema,
} from "@/lib/actions/position-actions";
import type { PositionSchema } from "@/lib/db";

const CURRENCIES = ["USD", "EUR", "GBP", "JPY", "CNY", "CAD", "AUD", "CHF", "HKD", "SGD", "TWD"] as const;

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
  visibility: z.enum(["publicAccess", "privateAccess"]),
  images: z.array(z.string()).optional(),
});

type ItemFormData = z.infer<typeof itemSchema>;

interface ItemFormProps {
  item?: ItemWithRelations;
  positionSchemas: PositionSchema[];
  positions?: PositionWithSchema[];
  defaultParentId?: number;
}

export function ItemForm({
  item,
  positionSchemas: initialPositionSchemas,
  positions: initialPositions,
  defaultParentId,
}: ItemFormProps) {
  const router = useRouter();
  const [isPending, startTransition] = useTransition();
  const [positionSchemas, setPositionSchemas] = useState(initialPositionSchemas);
  const [positions, setPositions] = useState<PositionWithSchema[]>(initialPositions ?? []);
  const [pendingPositions, setPendingPositions] = useState<PendingPosition[]>([]);

  const {
    register,
    handleSubmit,
    formState: { errors },
    setValue,
    watch,
  } = useForm<ItemFormData>({
    resolver: zodResolver(itemSchema),
    defaultValues: {
      title: item?.title ?? "",
      description: item?.description ?? "",
      originalQrCode: item?.originalQrCode ?? "",
      categoryId: item?.categoryId ?? null,
      locationId: item?.locationId ?? null,
      authorId: item?.authorId ?? null,
      parentId: item?.parentId ?? defaultParentId ?? null,
      price: item?.price ?? null,
      currency: item?.currency ?? "USD",
      visibility: item?.visibility ?? "privateAccess",
      images: item?.images ?? [],
    },
  });

  const visibility = watch("visibility");
  const currency = watch("currency");
  const categoryId = watch("categoryId");
  const locationId = watch("locationId");
  const authorId = watch("authorId");
  const parentId = watch("parentId");
  const images = watch("images");

  const handleDeletePosition = async (positionId: number) => {
    startTransition(async () => {
      try {
        const result = await deletePositionAction(positionId);
        if (result.success) {
          setPositions(positions.filter((p) => p.id !== positionId));
          toast.success("Position deleted");
        } else {
          toast.error(result.error || "Failed to delete position");
        }
      } catch {
        toast.error("Failed to delete position");
      }
    });
  };

  const handleRemovePendingPosition = (tempId: string) => {
    setPendingPositions(pendingPositions.filter((p) => p.tempId !== tempId));
  };

  const onSubmit = (data: ItemFormData) => {
    startTransition(async () => {
      try {
        const result = item
          ? await updateItemAction(item.id, data)
          : await createItemAction(data);

        if (result.success) {
          // If creating a new item and there are pending positions, create them
          if (!item && result.data && pendingPositions.length > 0) {
            const itemId = result.data.id;
            for (const pending of pendingPositions) {
              await createPositionAction({
                itemId,
                positionSchemaId: pending.positionSchemaId,
                data: pending.data,
              });
            }
          }

          toast.success(item ? "Item updated" : "Item created");
          if (!item && result.data) {
            router.push(`/items/${result.data.id}`);
          } else {
            router.refresh();
          }
        } else {
          toast.error(result.error || "Failed to save item");
        }
      } catch {
        toast.error("An error occurred");
      }
    });
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-6" noValidate data-testid="item-form">
      <Card>
        <CardHeader>
          <CardTitle>Basic Information</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="title">Title *</Label>
            <Input
              id="title"
              data-testid="item-title-input"
              {...register("title")}
              placeholder="Item title"
            />
            {errors.title && (
              <p className="text-sm text-destructive">{errors.title.message}</p>
            )}
          </div>

          <div className="space-y-2">
            <Label htmlFor="description">Description</Label>
            <Textarea
              id="description"
              data-testid="item-description-textarea"
              {...register("description")}
              placeholder="Item description"
              rows={4}
            />
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div className="space-y-2">
              <Label htmlFor="price">Price</Label>
              <Input
                id="price"
                data-testid="item-price-input"
                type="number"
                step="0.01"
                {...register("price", {
                  setValueAs: (v) => {
                    if (v === "" || v === null || v === undefined) return null;
                    const parsed = parseFloat(v);
                    return isNaN(parsed) ? null : parsed;
                  },
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
              data-testid="item-visibility-switch"
              checked={visibility === "publicAccess"}
              onCheckedChange={(checked) =>
                setValue("visibility", checked ? "publicAccess" : "privateAccess")
              }
            />
            <Label htmlFor="visibility">
              {visibility === "publicAccess" ? "Public" : "Private"}
            </Label>
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Relations</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <CategoryCombobox
              value={categoryId ?? null}
              onChange={(val) => setValue("categoryId", val)}
            />

            <LocationCombobox
              value={locationId ?? null}
              onChange={(val) => setValue("locationId", val)}
            />

            <AuthorCombobox
              value={authorId ?? null}
              onChange={(val) => setValue("authorId", val)}
            />

            <ParentItemCombobox
              value={parentId ?? null}
              onChange={(val) => setValue("parentId", val)}
              excludeId={item?.id}
            />
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Images</CardTitle>
        </CardHeader>
        <CardContent>
          <ImageUpload
            value={images ?? []}
            onChange={(urls) => setValue("images", urls)}
            maxImages={10}
            maxSizeMB={5}
            disabled={isPending}
          />
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <div className="flex items-center justify-between">
            <CardTitle>Positions</CardTitle>
            <PositionSheet
              itemId={item?.id}
              positionSchemas={positionSchemas}
              onPositionCreated={(position) => {
                setPositions([...positions, position]);
              }}
              onPendingPosition={(pending) => {
                setPendingPositions([...pendingPositions, pending]);
              }}
              onSchemaCreated={(schema) => {
                setPositionSchemas([...positionSchemas, schema]);
              }}
            />
          </div>
        </CardHeader>
        <CardContent className="space-y-4">
          {positions.length === 0 && pendingPositions.length === 0 ? (
            <p className="text-sm text-muted-foreground text-center py-4">
              No positions added yet. Click &quot;Add Position&quot; to add one.
            </p>
          ) : (
            <div className="space-y-2">
              {positions.map((position) => (
                <div
                  key={position.id}
                  className="flex items-center justify-between p-3 border rounded-lg"
                >
                  <div>
                    <p className="font-medium">
                      {position.positionSchema?.name || "Unknown Schema"}
                    </p>
                    <p className="text-sm text-muted-foreground">
                      {Object.entries(position.data)
                        .map(([k, v]) => `${k}: ${v}`)
                        .join(", ")}
                    </p>
                  </div>
                  <Button
                    type="button"
                    variant="ghost"
                    size="sm"
                    onClick={() => handleDeletePosition(position.id)}
                    disabled={isPending}
                  >
                    <Loader2
                      className={`h-4 w-4 text-destructive ${isPending ? "animate-spin" : "hidden"}`}
                    />
                    <span className={isPending ? "hidden" : ""}>Delete</span>
                  </Button>
                </div>
              ))}
              {pendingPositions.map((pending) => (
                <div
                  key={pending.tempId}
                  className="flex items-center justify-between p-3 border rounded-lg border-dashed"
                >
                  <div>
                    <p className="font-medium">
                      {pending.schema.name}{" "}
                      <span className="text-xs text-muted-foreground">
                        (pending)
                      </span>
                    </p>
                    <p className="text-sm text-muted-foreground">
                      {Object.entries(pending.data)
                        .map(([k, v]) => `${k}: ${v}`)
                        .join(", ")}
                    </p>
                  </div>
                  <Button
                    type="button"
                    variant="ghost"
                    size="sm"
                    onClick={() => handleRemovePendingPosition(pending.tempId)}
                  >
                    Remove
                  </Button>
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>

      <div className="flex justify-end gap-4">
        <Button
          type="button"
          variant="outline"
          onClick={() => router.back()}
          disabled={isPending}
          data-testid="item-cancel-button"
        >
          Cancel
        </Button>
        <Button type="submit" disabled={isPending} data-testid="item-submit-button">
          {isPending && <Loader2 className="h-4 w-4 mr-2 animate-spin" />}
          {item ? "Update Item" : "Create Item"}
        </Button>
      </div>
    </form>
  );
}
