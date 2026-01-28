"use client";

import { useState, useCallback } from "react";
import Map, { Marker, MapMouseEvent, NavigationControl } from "react-map-gl/mapbox";
import { MapPin } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import "mapbox-gl/dist/mapbox-gl.css";

interface LocationPickerProps {
  value?: { latitude: number; longitude: number };
  onChange: (location: { latitude: number; longitude: number }) => void;
  className?: string;
}

export function LocationPicker({ value, onChange, className }: LocationPickerProps) {
  const [viewState, setViewState] = useState({
    latitude: value?.latitude ?? 37.7749,
    longitude: value?.longitude ?? -122.4194,
    zoom: value ? 14 : 10,
  });

  const [manualLat, setManualLat] = useState(value?.latitude?.toString() ?? "");
  const [manualLng, setManualLng] = useState(value?.longitude?.toString() ?? "");

  const handleMapClick = useCallback(
    (event: MapMouseEvent) => {
      const { lng, lat } = event.lngLat;
      onChange({ latitude: lat, longitude: lng });
      setManualLat(lat.toFixed(6));
      setManualLng(lng.toFixed(6));
    },
    [onChange]
  );

  const handleManualInput = useCallback(() => {
    const lat = parseFloat(manualLat);
    const lng = parseFloat(manualLng);
    if (!isNaN(lat) && !isNaN(lng) && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
      onChange({ latitude: lat, longitude: lng });
      setViewState((prev) => ({ ...prev, latitude: lat, longitude: lng, zoom: 14 }));
    }
  }, [manualLat, manualLng, onChange]);

  const handleCurrentLocation = useCallback(() => {
    if (navigator.geolocation) {
      navigator.geolocation.getCurrentPosition(
        (position) => {
          const { latitude, longitude } = position.coords;
          onChange({ latitude, longitude });
          setManualLat(latitude.toFixed(6));
          setManualLng(longitude.toFixed(6));
          setViewState((prev) => ({ ...prev, latitude, longitude, zoom: 14 }));
        },
        (error) => {
          console.error("Geolocation error:", error);
        }
      );
    }
  }, [onChange]);

  return (
    <div className={className}>
      <div className="mb-4 flex gap-4 items-end">
        <div className="flex-1">
          <Label htmlFor="latitude">Latitude</Label>
          <Input
            id="latitude"
            type="number"
            step="any"
            placeholder="-90 to 90"
            value={manualLat}
            onChange={(e) => setManualLat(e.target.value)}
          />
        </div>
        <div className="flex-1">
          <Label htmlFor="longitude">Longitude</Label>
          <Input
            id="longitude"
            type="number"
            step="any"
            placeholder="-180 to 180"
            value={manualLng}
            onChange={(e) => setManualLng(e.target.value)}
          />
        </div>
        <Button type="button" variant="outline" onClick={handleManualInput}>
          Set
        </Button>
        <Button type="button" variant="secondary" onClick={handleCurrentLocation}>
          <MapPin className="h-4 w-4 mr-2" />
          Current
        </Button>
      </div>

      <div className="h-[400px] rounded-lg overflow-hidden border">
        <Map
          {...viewState}
          onMove={(evt) => setViewState(evt.viewState)}
          onClick={handleMapClick}
          mapStyle="mapbox://styles/mapbox/dark-v11"
          mapboxAccessToken={process.env.NEXT_PUBLIC_MAPBOX_ACCESS_TOKEN}
        >
          <NavigationControl position="top-right" />
          {value && (
            <Marker latitude={value.latitude} longitude={value.longitude} anchor="bottom">
              <MapPin className="h-8 w-8 text-red-500 fill-red-500" />
            </Marker>
          )}
        </Map>
      </div>

      {value && (
        <p className="mt-2 text-sm text-muted-foreground">
          Selected: {value.latitude.toFixed(6)}, {value.longitude.toFixed(6)}
        </p>
      )}
    </div>
  );
}
