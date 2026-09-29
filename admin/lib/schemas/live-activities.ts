import { z } from "zod";
import { DeviceEnvironment } from "./devices";

export const LiveActivityTokenKind = z
  .enum(["start", "update"])
  .describe("start is the app's push-to-start token; update belongs to the running ISO jobs activity");

// Body sent by the app when ActivityKit hands it a push token
export const LiveActivityTokenRegisterSchema = z.object({
  token: z
    .string()
    .regex(/^[0-9a-fA-F]{32,400}$/)
    .describe("Hex-encoded ActivityKit push token"),
  kind: LiveActivityTokenKind,
  environment: DeviceEnvironment,
});

export const LiveActivityTokenResponseSchema = z.object({
  token: z.string().describe("Hex-encoded ActivityKit push token"),
  kind: LiveActivityTokenKind,
  environment: DeviceEnvironment,
  createdAt: z.coerce.date().describe("When the token was first registered"),
  updatedAt: z.coerce.date().describe("When the token was last registered"),
});

export const LiveActivityTokenPathParams = z.object({
  token: z.string().describe("Hex-encoded ActivityKit push token"),
});
