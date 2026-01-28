import { notFound } from "next/navigation";
import { LocationForm } from "@/components/forms/location-form";
import { getLocation } from "@/lib/actions/location-actions";

interface EditLocationPageProps {
  params: Promise<{ id: string }>;
}

export default async function EditLocationPage({ params }: EditLocationPageProps) {
  const { id } = await params;
  const location = await getLocation(parseInt(id));

  if (!location) {
    notFound();
  }

  return (
    <div className="max-w-4xl">
      <div className="mb-6">
        <h1 className="text-3xl font-bold">Edit Location</h1>
        <p className="text-muted-foreground">
          Update location details
        </p>
      </div>
      <LocationForm location={location} />
    </div>
  );
}
