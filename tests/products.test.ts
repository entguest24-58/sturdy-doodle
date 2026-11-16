import request from "supertest";
import { beforeEach, describe, expect, it } from "vitest";
import { createApp } from "../src/app";
import { productStore } from "../src/products/product.routes";

const app = createApp();
const valid = { sku: "tee-001", name: "T-Shirt", priceCents: 1999, stock: 5, category: "Apparel" };

beforeEach(() => productStore.clear());

describe("products", () => {
  it("creates a product with defaults", async () => {
    const res = await request(app).post("/api/products").send(valid);
    expect(res.status).toBe(201);
    expect(res.body).toMatchObject({ sku: "TEE-001", currency: "USD", active: true, stock: 5 });
  });

  it("rejects invalid input", async () => {
    const res = await request(app).post("/api/products").send({ ...valid, priceCents: -1 });
    expect(res.status).toBe(400);
    const fractional = await request(app).post("/api/products").send({ ...valid, priceCents: 19.99 });
    expect(fractional.status).toBe(400);
  });

  it("rejects a duplicate SKU", async () => {
    await request(app).post("/api/products").send(valid);
    const res = await request(app).post("/api/products").send({ ...valid, sku: "TEE-001" });
    expect(res.status).toBe(409);
  });

  it("filters the list", async () => {
    await request(app).post("/api/products").send(valid);
    await request(app)
      .post("/api/products")
      .send({ sku: "mug-001", name: "Mug", priceCents: 900, stock: 0, category: "Kitchen", active: false });

    expect((await request(app).get("/api/products")).body.total).toBe(2);
    expect((await request(app).get("/api/products?category=apparel")).body.total).toBe(1);
    expect((await request(app).get("/api/products?active=false")).body.data[0].sku).toBe("MUG-001");
    expect((await request(app).get("/api/products?inStock=true")).body.data[0].sku).toBe("TEE-001");
    expect((await request(app).get("/api/products?maxPriceCents=1000")).body.total).toBe(1);
    expect((await request(app).get("/api/products?q=shirt")).body.total).toBe(1);
    expect((await request(app).get("/api/products?active=maybe")).status).toBe(400);
  });

  it("gets, patches, replaces and deletes", async () => {
    const { body: created } = await request(app).post("/api/products").send(valid);
    const url = `/api/products/${created.id}`;

    expect((await request(app).get(url)).status).toBe(200);

    const patched = await request(app).patch(url).send({ stock: 0, active: false });
    expect(patched.body).toMatchObject({ stock: 0, active: false, category: "Apparel" });

    const replaced = await request(app).put(url).send({ sku: "tee-002", name: "Tee", priceCents: 100 });
    expect(replaced.body).toMatchObject({ sku: "TEE-002", stock: 0, active: true });
    expect(replaced.body.category).toBeUndefined();

    expect((await request(app).delete(url)).status).toBe(204);
    expect((await request(app).get(url)).status).toBe(404);
  });
});

describe("app", () => {
  it("serves health and handles unknown routes and bad JSON", async () => {
    expect((await request(app).get("/health")).body).toEqual({ status: "ok" });
    expect((await request(app).get("/nope")).status).toBe(404);
    const bad = await request(app).post("/api/products").set("Content-Type", "application/json").send("{bad");
    expect(bad.status).toBe(400);
  });
});
