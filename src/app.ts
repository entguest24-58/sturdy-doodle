import express from "express";
import { errorHandler, notFoundHandler } from "./common/errors";
import { customerRouter } from "./customers/customer.routes";
import { productRouter } from "./products/product.routes";

export function createApp() {
  const app = express();
  app.use(express.json());

  app.get("/health", (_req, res) => {
    res.json({ status: "ok" });
  });

  app.use("/api/customers", customerRouter);
  app.use("/api/products", productRouter);

  app.use(notFoundHandler);
  app.use(errorHandler);
  return app;
}
