import { Router } from "express";
import { conflict, notFound } from "../common/errors";
import { paginate } from "../common/pagination";
import { InMemoryStore } from "../common/store";
import {
  createProductSchema,
  listProductsQuery,
  updateProductSchema,
  type Product,
} from "./product.schema";

export const productStore = new InMemoryStore<Product>();

export const productRouter = Router();

const skuTaken = (sku: string, exceptId?: string) =>
  productStore.find((p) => p.sku === sku && p.id !== exceptId) !== undefined;

productRouter.post("/", (req, res) => {
  const input = createProductSchema.parse(req.body);
  if (skuTaken(input.sku)) throw conflict("A product with this SKU already exists");
  res.status(201).json(productStore.create(input));
});

productRouter.get("/", (req, res) => {
  const { page, limit, category, active, inStock, minPriceCents, maxPriceCents, q } =
    listProductsQuery.parse(req.query);
  const items = productStore.list().filter((p) => {
    if (category && p.category?.toLowerCase() !== category.toLowerCase()) return false;
    if (active !== undefined && p.active !== active) return false;
    if (inStock !== undefined && p.stock > 0 !== inStock) return false;
    if (minPriceCents !== undefined && p.priceCents < minPriceCents) return false;
    if (maxPriceCents !== undefined && p.priceCents > maxPriceCents) return false;
    if (q && !`${p.name} ${p.sku} ${p.description ?? ""}`.toLowerCase().includes(q)) return false;
    return true;
  });
  res.json(paginate(items, page, limit));
});

productRouter.get("/:id", (req, res) => {
  const product = productStore.get(req.params.id);
  if (!product) throw notFound("Product");
  res.json(product);
});

productRouter.put("/:id", (req, res) => {
  const input = createProductSchema.parse(req.body);
  const existing = productStore.get(req.params.id);
  if (!existing) throw notFound("Product");
  if (skuTaken(input.sku, existing.id)) throw conflict("A product with this SKU already exists");
  // Full replacement: optional fields omitted from the body are cleared.
  res.json(productStore.update(existing.id, { description: undefined, category: undefined, ...input }));
});

productRouter.patch("/:id", (req, res) => {
  const input = updateProductSchema.parse(req.body);
  const existing = productStore.get(req.params.id);
  if (!existing) throw notFound("Product");
  if (input.sku && skuTaken(input.sku, existing.id)) {
    throw conflict("A product with this SKU already exists");
  }
  res.json(productStore.update(existing.id, input));
});

productRouter.delete("/:id", (req, res) => {
  if (!productStore.delete(req.params.id)) throw notFound("Product");
  res.status(204).end();
});
