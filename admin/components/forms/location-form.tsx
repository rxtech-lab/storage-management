"use client";

import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import * as z from "zod";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Label } from "@/components/ui/label";
import { LocationPicker } from "@/components/maps/location-picker";
import type { Location } from "@/lib/db";
import {
  createLocationAction,
  updateLocationAction,
  deleteLocationAndRedirect,
} from "@/lib/actions/location-actions";
import { DeleteConfirmButton } from "@/components/ui/delete-confirm-button";
import { toast } from "sonner";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { Loader2 } from "lucide-react";

const locationSchema = z.object({
  title: z.string().min(1, "Title is required"),
  latitude: z.number().min(-90).max(90),
  longitude: z.number().min(-180).max(180),
});

type LocationFormData = z.infer<typeof locationSchema>;

interface LocationFormProps {
  location?: Location;
}

export function LocationForm({ location }: LocationFormProps) {
  const router = useRouter();
  const [isSubmitting, setIsSubmitting] = useState(false);
  const isEditing = !!location;

  const {
    register,
    handleSubmit,
    setValue,
    watch,
    formState: { errors },
  } = useForm<LocationFormData>({
    resolver: zodResolver(locationSchema),
    defaultValues: {
      title: location?.title || "",
      latitude: location?.latitude || 0,
      longitude: location?.longitude || 0,
    },
  });

  const latitude = watch("latitude");
  const longitude = watch("longitude");

  const onSubmit = async (data: LocationFormData) => {
    setIsSubmitting(true);
    try {
      const result = isEditing
        ? await updateLocationAction(location.id, data)
        : await createLocationAction(data);

      if (result.success) {
        toast.success(isEditing ? "Location updated" : "Location created");
        router.push("/locations");
      } else {
        toast.error(result.error || "Failed to save location");
      }
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <Card>
      <CardHeader>
        <CardTitle>{isEditing ? "Edit Location" : "Create Location"}</CardTitle>
      </CardHeader>
      <CardContent>
        <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
          <div className="space-y-2">
            <Label htmlFor="title">Location Title *</Label>
            <Input id="title" {...register("title")} placeholder="Location title" />
            {errors.title && (
              <p className="text-sm text-destructive">{errors.title.message}</p>
            )}
          </div>

          <div className="space-y-2">
            <Label>Location *</Label>
            <LocationPicker
              value={
                latitude && longitude
                  ? { latitude, longitude }
                  : undefined
              }
              onChange={({ latitude, longitude }) => {
                setValue("latitude", latitude);
                setValue("longitude", longitude);
              }}
            />
            {(errors.latitude || errors.longitude) && (
              <p className="text-sm text-destructive">Please select a location on the map</p>
            )}
          </div>

          <div className="flex gap-4">
            <Button type="submit" disabled={isSubmitting}>
              {isSubmitting && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
              {isEditing ? "Update Location" : "Create Location"}
            </Button>
            <Button
              type="button"
              variant="outline"
              onClick={() => router.back()}
            >
              Cancel
            </Button>
            {isEditing && (
              <DeleteConfirmButton
                onConfirm={async () => {
                  const result = await deleteLocationAndRedirect(location.id);
                  if (result.success) {
                    toast.success("Location deleted");
                    router.push("/locations");
                  } else {
                    toast.error(result.error || "Failed to delete location");
                  }
                }}
                title={`Delete "${location.title}"?`}
                description="This action cannot be undone. This will permanently delete this location."
              />
            )}
          </div>
        </form>
      </CardContent>
    </Card>
  );
}
