import { z } from "zod";

export const DevicePlatform = z.enum(["ios", "macos"]).describe("Platform the app runs on");

export const DeviceEnvironment = z
  .enum(["sandbox", "production"])
  .describe("APNs environment the token belongs to: sandbox for debug builds, production for TestFlight and App Store builds");

// Body sent by the app after it receives an APNs device token
export const DeviceRegisterSchema = z.object({
  token: z
    .string()
    .regex(/^[0-9a-fA-F]{32,200}$/)
    .describe("Hex-encoded APNs device token"),
  platform: DevicePlatform,
  environment: DeviceEnvironment,
});

export const DeviceResponseSchema = z.object({
  token: z.string().describe("Hex-encoded APNs device token"),
  platform: DevicePlatform,
  environment: DeviceEnvironment,
  createdAt: z.coerce.date().describe("When the device was first registered"),
  updatedAt: z.coerce.date().describe("When the device was last registered"),
});

export const DeviceTokenPathParams = z.object({
  token: z.string().describe("Hex-encoded APNs device token"),
});
