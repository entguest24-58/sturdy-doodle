import { z } from "zod";
import type { Entity } from "../common/store";
import { paginationQuery } from "../common/pagination";

export const createProductSchema = z.object({
  sku: z.string().trim().min(1).max(64).toUpperCase(),
  name: z.string().trim().min(1).max(200),
  description: z.string().trim().max(2000).optional(),
  /** Price in minor units (e.g. cents) to avoid floating point errors. */
  priceCents: z.number().int().min(0),
  currency: z.string().trim().length(3, "currency must be a 3-letter ISO code").toUpperCase().default("USD"),
  stock: z.number().int().min(0).default(0),
  category: z.string().trim().min(1).max(100).optional(),
  active: z.boolean().default(true),
});

export const updateProductSchema = z
  .object({
    sku: z.string().trim().min(1).max(64).toUpperCase(),
    name: z.string().trim().min(1).max(200),
    description: z.string().trim().max(2000),
    priceCents: z.number().int().min(0),
    currency: z.string().trim().length(3, "currency must be a 3-letter ISO code").toUpperCase(),
    stock: z.number().int().min(0),
    category: z.string().trim().min(1).max(100),
    active: z.boolean(),
  })
  .partial()
  .refine((v) => Object.keys(v).length > 0, "At least one field is required");

const booleanQuery = z.enum(["true", "false"]).transform((v) => v === "true");

export const listProductsQuery = paginationQuery.extend({
  category: z.string().trim().optional(),
  active: booleanQuery.optional(),
  inStock: booleanQuery.optional(),
  minPriceCents: z.coerce.number().int().min(0).optional(),
  maxPriceCents: z.coerce.number().int().min(0).optional(),
  q: z.string().trim().toLowerCase().optional(),
});

export type ProductInput = z.infer<typeof createProductSchema>;
export type Product = ProductInput & Entity;
