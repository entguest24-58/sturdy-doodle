# sturdy-doodle

E-commerce REST API in TypeScript (Express 5 + Zod) with customer and product CRUD.
Data is held in memory, so it resets when the process restarts.

## Run

```bash
npm install
npm run dev        # watch mode on http://localhost:3000
npm test           # vitest + supertest
npm run build && npm start
```

Docker: `docker build -t shop-api . && docker run -p 3000:3000 shop-api`

`PORT` sets the listen port (default 3000).

## Endpoints

| Method | Path | Notes |
| --- | --- | --- |
| GET | `/health` | Liveness check |
| POST | `/api/customers` | Create; email must be unique (409 otherwise) |
| GET | `/api/customers` | List; `page`, `limit`, `email`, `q` |
| GET | `/api/customers/:id` | Fetch one |
| PUT | `/api/customers/:id` | Replace |
| PATCH | `/api/customers/:id` | Partial update |
| DELETE | `/api/customers/:id` | 204 on success |
| POST | `/api/products` | Create; SKU must be unique (409 otherwise) |
| GET | `/api/products` | List; `page`, `limit`, `category`, `active`, `inStock`, `minPriceCents`, `maxPriceCents`, `q` |
| GET | `/api/products/:id` | Fetch one |
| PUT | `/api/products/:id` | Replace |
| PATCH | `/api/products/:id` | Partial update |
| DELETE | `/api/products/:id` | 204 on success |

List responses have the shape `{ data, page, limit, total }`.
Validation errors return 400 with `{ error, details: [{ path, message }] }`; unknown ids return 404.

### Customer

```json
{
  "firstName": "Ada",
  "lastName": "Lovelace",
  "email": "ada@example.com",
  "phone": "+1 555 0100",
  "address": { "line1": "1 Main St", "city": "London", "postalCode": "N1 9GU", "country": "GB" }
}
```

`phone` and `address` are optional. Emails are lower-cased.

### Product

```json
{
  "sku": "TEE-001",
  "name": "T-Shirt",
  "description": "Cotton tee",
  "priceCents": 1999,
  "currency": "USD",
  "stock": 5,
  "category": "Apparel",
  "active": true
}
```

`priceCents` is an integer in minor units. Defaults: `currency` USD, `stock` 0, `active` true. SKUs are upper-cased.
