import { Router } from "express";
import { conflict, notFound } from "../common/errors";
import { paginate } from "../common/pagination";
import { InMemoryStore } from "../common/store";
import {
  createCustomerSchema,
  listCustomersQuery,
  updateCustomerSchema,
  type Customer,
} from "./customer.schema";

export const customerStore = new InMemoryStore<Customer>();

export const customerRouter = Router();

const emailTaken = (email: string, exceptId?: string) =>
  customerStore.find((c) => c.email === email && c.id !== exceptId) !== undefined;

customerRouter.post("/", (req, res) => {
  const input = createCustomerSchema.parse(req.body);
  if (emailTaken(input.email)) throw conflict("A customer with this email already exists");
  res.status(201).json(customerStore.create(input));
});

customerRouter.get("/", (req, res) => {
  const { page, limit, email, q } = listCustomersQuery.parse(req.query);
  const items = customerStore.list().filter((c) => {
    if (email && c.email !== email) return false;
    if (q && !`${c.firstName} ${c.lastName} ${c.email}`.toLowerCase().includes(q)) return false;
    return true;
  });
  res.json(paginate(items, page, limit));
});

customerRouter.get("/:id", (req, res) => {
  const customer = customerStore.get(req.params.id);
  if (!customer) throw notFound("Customer");
  res.json(customer);
});

customerRouter.put("/:id", (req, res) => {
  const input = createCustomerSchema.parse(req.body);
  const existing = customerStore.get(req.params.id);
  if (!existing) throw notFound("Customer");
  if (emailTaken(input.email, existing.id)) throw conflict("A customer with this email already exists");
  // Full replacement: optional fields omitted from the body are cleared.
  res.json(customerStore.update(existing.id, { phone: undefined, address: undefined, ...input }));
});

customerRouter.patch("/:id", (req, res) => {
  const input = updateCustomerSchema.parse(req.body);
  const existing = customerStore.get(req.params.id);
  if (!existing) throw notFound("Customer");
  if (input.email && emailTaken(input.email, existing.id)) {
    throw conflict("A customer with this email already exists");
  }
  res.json(customerStore.update(existing.id, input));
});

customerRouter.delete("/:id", (req, res) => {
  if (!customerStore.delete(req.params.id)) throw notFound("Customer");
  res.status(204).end();
});
