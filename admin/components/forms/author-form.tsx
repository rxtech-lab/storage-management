"use client";

import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import * as z from "zod";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Label } from "@/components/ui/label";
import type { Author } from "@/lib/db";
import {
  createAuthorAction,
  updateAuthorAction,
  deleteAuthorAndRedirect,
} from "@/lib/actions/author-actions";
import { DeleteConfirmButton } from "@/components/ui/delete-confirm-button";
import { toast } from "sonner";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { Loader2 } from "lucide-react";

const authorSchema = z.object({
  name: z.string().min(1, "Name is required"),
  bio: z.string().optional().nullable(),
});

type AuthorFormData = z.infer<typeof authorSchema>;

interface AuthorFormProps {
  author?: Author;
}

export function AuthorForm({ author }: AuthorFormProps) {
  const router = useRouter();
  const [isSubmitting, setIsSubmitting] = useState(false);
  const isEditing = !!author;

  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<AuthorFormData>({
    resolver: zodResolver(authorSchema),
    defaultValues: {
      name: author?.name || "",
      bio: author?.bio || "",
    },
  });

  const onSubmit = async (data: AuthorFormData) => {
    setIsSubmitting(true);
    try {
      const result = isEditing
        ? await updateAuthorAction(author.id, data)
        : await createAuthorAction(data);

      if (result.success) {
        toast.success(isEditing ? "Author updated" : "Author created");
        router.push("/authors");
      } else {
        toast.error(result.error || "Failed to save author");
      }
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <Card>
      <CardHeader>
        <CardTitle>{isEditing ? "Edit Author" : "Create Author"}</CardTitle>
      </CardHeader>
      <CardContent>
        <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
          <div className="space-y-2">
            <Label htmlFor="name">Author Name *</Label>
            <Input id="name" {...register("name")} placeholder="Author name" />
            {errors.name && (
              <p className="text-sm text-destructive">{errors.name.message}</p>
            )}
          </div>

          <div className="space-y-2">
            <Label htmlFor="bio">Bio</Label>
            <Textarea
              id="bio"
              {...register("bio")}
              placeholder="Author bio"
              rows={4}
            />
          </div>

          <div className="flex gap-4">
            <Button type="submit" disabled={isSubmitting}>
              {isSubmitting && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
              {isEditing ? "Update Author" : "Create Author"}
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
                  const result = await deleteAuthorAndRedirect(author.id);
                  if (result.success) {
                    toast.success("Author deleted");
                    router.push("/authors");
                  } else {
                    toast.error(result.error || "Failed to delete author");
                  }
                }}
                title={`Delete "${author.name}"?`}
                description="This action cannot be undone. This will permanently delete this author."
              />
            )}
          </div>
        </form>
      </CardContent>
    </Card>
  );
}
