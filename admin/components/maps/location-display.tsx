"use client";

import Map, { Marker, NavigationControl } from "react-map-gl/mapbox";
import { MapPin } from "lucide-react";
import "mapbox-gl/dist/mapbox-gl.css";

interface LocationDisplayProps {
  latitude: number;
  longitude: number;
  title?: string;
  className?: string;
  height?: string;
}

export function LocationDisplay({
  latitude,
  longitude,
  title,
  className,
  height = "300px",
}: LocationDisplayProps) {
  return (
    <div className={className}>
      {title && (
        <p className="mb-2 text-sm font-medium">{title}</p>
      )}
      <div className="rounded-lg overflow-hidden border" style={{ height }}>
        <Map
          initialViewState={{
            latitude,
            longitude,
            zoom: 14,
          }}
          mapStyle="mapbox://styles/mapbox/streets-v12"
          mapboxAccessToken={process.env.NEXT_PUBLIC_MAPBOX_ACCESS_TOKEN}
          interactive={true}
        >
          <NavigationControl position="top-right" />
          <Marker latitude={latitude} longitude={longitude} anchor="bottom">
            <MapPin className="h-8 w-8 text-red-500 fill-red-500" />
          </Marker>
        </Map>
      </div>
      <p className="mt-2 text-sm text-muted-foreground">
        {latitude.toFixed(6)}, {longitude.toFixed(6)}
      </p>
    </div>
  );
}
