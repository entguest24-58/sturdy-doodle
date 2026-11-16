import { z } from "zod";
import type { Entity } from "../common/store";
import { paginationQuery } from "../common/pagination";

const addressSchema = z.object({
  line1: z.string().trim().min(1),
  line2: z.string().trim().optional(),
  city: z.string().trim().min(1),
  state: z.string().trim().optional(),
  postalCode: z.string().trim().min(1),
  country: z.string().trim().length(2, "country must be a 2-letter ISO code").toUpperCase(),
});

export const createCustomerSchema = z.object({
  firstName: z.string().trim().min(1).max(100),
  lastName: z.string().trim().min(1).max(100),
  email: z.string().trim().toLowerCase().email(),
  phone: z.string().trim().min(5).max(30).optional(),
  address: addressSchema.optional(),
});

export const updateCustomerSchema = createCustomerSchema
  .partial()
  .refine((v) => Object.keys(v).length > 0, "At least one field is required");

export const listCustomersQuery = paginationQuery.extend({
  email: z.string().trim().toLowerCase().optional(),
  q: z.string().trim().toLowerCase().optional(),
});

export type CustomerInput = z.infer<typeof createCustomerSchema>;
export type Customer = CustomerInput & Entity;
