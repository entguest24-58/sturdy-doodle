import { randomUUID } from "node:crypto";

export interface Entity {
  id: string;
  createdAt: string;
  updatedAt: string;
}

/** In-memory collection. Swap for a database-backed implementation later. */
export class InMemoryStore<T extends Entity> {
  private readonly items = new Map<string, T>();

  list(): T[] {
    return [...this.items.values()];
  }

  get(id: string): T | undefined {
    return this.items.get(id);
  }

  find(predicate: (item: T) => boolean): T | undefined {
    return this.list().find(predicate);
  }

  create(data: Omit<T, keyof Entity>): T {
    const now = new Date().toISOString();
    const item = { ...data, id: randomUUID(), createdAt: now, updatedAt: now } as T;
    this.items.set(item.id, item);
    return item;
  }

  update(id: string, data: Partial<Omit<T, keyof Entity>>): T | undefined {
    const existing = this.items.get(id);
    if (!existing) return undefined;
    const updated = { ...existing, ...data, updatedAt: new Date().toISOString() };
    this.items.set(id, updated);
    return updated;
  }

  delete(id: string): boolean {
    return this.items.delete(id);
  }

  clear(): void {
    this.items.clear();
  }
}
