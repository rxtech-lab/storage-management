"use client";

import { useState } from "react";
import Map, { Marker, NavigationControl } from "react-map-gl/mapbox";
import { MapPin, Maximize2, X } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import "mapbox-gl/dist/mapbox-gl.css";

interface HeroMapProps {
  latitude?: number;
  longitude?: number;
  title?: string;
}

export function HeroMap({ latitude, longitude, title }: HeroMapProps) {
  const [isExpanded, setIsExpanded] = useState(false);
  const hasLocation = latitude !== undefined && longitude !== undefined;

  return (
    <>
      <div className="relative h-[280px] md:h-[360px] -mx-4 md:-mx-6 lg:-mx-8">
        {hasLocation ? (
          <>
            <Map
              initialViewState={{
                latitude,
                longitude,
                zoom: 14,
              }}
              mapStyle="mapbox://styles/mapbox/light-v11"
              mapboxAccessToken={process.env.NEXT_PUBLIC_MAPBOX_ACCESS_TOKEN}
              interactive={false}
              style={{ position: "absolute", inset: 0 }}
            >
              <Marker latitude={latitude} longitude={longitude} anchor="bottom">
                <div className="relative">
                  <div className="absolute -inset-4 bg-primary/20 rounded-full animate-ping" />
                  <MapPin className="h-8 w-8 text-white fill-primary drop-shadow-lg" />
                </div>
              </Marker>
            </Map>

            {/* Gradient fade to background */}
            <div className="absolute inset-0 bg-linear-to-t from-background via-background/5 to-transparent pointer-events-none" />

            {/* Floating location card */}
            <div className="absolute bottom-0 left-4 right-4 md:left-6 md:right-6 lg:left-8 lg:right-8 translate-y-1/2 z-10">
              <div className="backdrop-blur-xl bg-card/80 rounded-2xl p-4 shadow-lg border border-border/50">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-3">
                    <div className="p-2 rounded-full bg-primary/10">
                      <MapPin className="h-5 w-5 text-primary" />
                    </div>
                    <div>
                      <p className="font-semibold">{title || "Location"}</p>
                      <p className="text-sm text-muted-foreground">
                        {latitude.toFixed(6)}, {longitude.toFixed(6)}
                      </p>
                    </div>
                  </div>
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() => setIsExpanded(true)}
                    className="gap-2"
                  >
                    <Maximize2 className="h-4 w-4" />
                    <span className="hidden sm:inline">Expand</span>
                  </Button>
                </div>
              </div>
            </div>
          </>
        ) : (
          <div className="absolute inset-0 bg-muted/50 flex items-center justify-center">
            <div className="text-center">
              <MapPin className="h-12 w-12 text-muted-foreground/50 mx-auto mb-2" />
              <p className="text-muted-foreground">No location set</p>
            </div>
          </div>
        )}
      </div>

      {/* Spacer for floating card */}
      <div className="h-12" />

      {/* Expanded Map Dialog */}
      <Dialog open={isExpanded} onOpenChange={setIsExpanded}>
        <DialogContent className="!max-w-4xl h-[80vh] p-0 overflow-hidden">
          <DialogHeader className="absolute top-0 left-0 right-0 z-10 p-4 bg-gradient-to-b from-background/90 to-transparent">
            <div className="flex items-center justify-between">
              <DialogTitle className="flex items-center gap-2">
                <MapPin className="h-5 w-5" />
                {title || "Location"}
              </DialogTitle>
              <Button
                variant="ghost"
                size="icon"
                onClick={() => setIsExpanded(false)}
              >
                <X className="h-4 w-4" />
              </Button>
            </div>
          </DialogHeader>
          {hasLocation && (
            <Map
              initialViewState={{
                latitude,
                longitude,
                zoom: 15,
              }}
              mapStyle="mapbox://styles/mapbox/light-v11"
              mapboxAccessToken={process.env.NEXT_PUBLIC_MAPBOX_ACCESS_TOKEN}
              interactive={true}
              style={{ width: "100%", height: "100%" }}
            >
              <NavigationControl position="top-right" />
              <Marker latitude={latitude} longitude={longitude} anchor="bottom">
                <MapPin className="h-10 w-10 text-white fill-red-400  drop-shadow-lg" />
              </Marker>
            </Map>
          )}
        </DialogContent>
      </Dialog>
    </>
  );
}
