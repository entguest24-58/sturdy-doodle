import request from "supertest";
import { beforeEach, describe, expect, it } from "vitest";
import { createApp } from "../src/app";
import { customerStore } from "../src/customers/customer.routes";

const app = createApp();
const valid = { firstName: "Ada", lastName: "Lovelace", email: "Ada@Example.com" };

beforeEach(() => customerStore.clear());

describe("customers", () => {
  it("creates a customer and normalises the email", async () => {
    const res = await request(app).post("/api/customers").send(valid);
    expect(res.status).toBe(201);
    expect(res.body).toMatchObject({ firstName: "Ada", email: "ada@example.com" });
    expect(res.body.id).toBeTypeOf("string");
  });

  it("rejects invalid input", async () => {
    const res = await request(app).post("/api/customers").send({ firstName: "", email: "nope" });
    expect(res.status).toBe(400);
    expect(res.body.error).toBe("Validation failed");
  });

  it("rejects a duplicate email", async () => {
    await request(app).post("/api/customers").send(valid);
    const res = await request(app).post("/api/customers").send(valid);
    expect(res.status).toBe(409);
  });

  it("lists with pagination and search", async () => {
    await request(app).post("/api/customers").send(valid);
    await request(app).post("/api/customers").send({ ...valid, firstName: "Grace", email: "grace@example.com" });
    const page = await request(app).get("/api/customers?limit=1&page=2");
    expect(page.body).toMatchObject({ total: 2, page: 2, limit: 1 });
    expect(page.body.data).toHaveLength(1);
    const search = await request(app).get("/api/customers?q=grace");
    expect(search.body.total).toBe(1);
  });

  it("gets, patches, replaces and deletes", async () => {
    const { body: created } = await request(app)
      .post("/api/customers")
      .send({ ...valid, phone: "+1 555 0100" });
    const url = `/api/customers/${created.id}`;

    expect((await request(app).get(url)).status).toBe(200);

    const patched = await request(app).patch(url).send({ lastName: "Byron" });
    expect(patched.body).toMatchObject({ lastName: "Byron", phone: "+1 555 0100" });

    const replaced = await request(app).put(url).send(valid);
    expect(replaced.status).toBe(200);
    expect(replaced.body.phone).toBeUndefined();

    expect((await request(app).patch(url).send({})).status).toBe(400);
    expect((await request(app).delete(url)).status).toBe(204);
    expect((await request(app).get(url)).status).toBe(404);
    expect((await request(app).delete(url)).status).toBe(404);
  });
});
