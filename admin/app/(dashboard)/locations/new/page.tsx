import { LocationForm } from "@/components/forms/location-form";

export default function NewLocationPage() {
  return (
    <div className="max-w-4xl">
      <div className="mb-6">
        <h1 className="text-3xl font-bold">New Location</h1>
        <p className="text-muted-foreground">
          Add a new storage location
        </p>
      </div>
      <LocationForm />
    </div>
  );
}
