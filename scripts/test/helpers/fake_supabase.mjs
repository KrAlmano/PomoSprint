// Edge Function testleri için supabase-js yerine geçen küçük bellek içi sahte.
// Yalnızca fonksiyonların kullandığı zincir desteklenir:
//   from(t).select(c).eq(..).maybeSingle()
//   from(t).update(v).eq(..).is(..).gte(..).select(c).maybeSingle()
//   await from(t).update(v).eq(..)   /   await from(t).delete().eq(..)
// Veri globalThis.__fakeDb'den okunur:
//   { tables: { <tablo>: [satır, ...] }, calls: [], failures: { "<tablo>.<işlem>": "mesaj" } }

class Query {
  constructor(db, table) {
    this.db = db;
    this.table = table;
    this.action = "select";
    this.values = null;
    this.columns = null;
    this.filters = [];
  }

  select(columns) {
    this.columns = columns;
    return this;
  }

  update(values) {
    this.action = "update";
    this.values = values;
    return this;
  }

  delete() {
    this.action = "delete";
    return this;
  }

  eq(column, value) {
    this.filters.push({ op: "eq", column, value, test: (row) => row[column] === value });
    return this;
  }

  is(column, value) {
    this.filters.push({ op: "is", column, value, test: (row) => (row[column] ?? null) === value });
    return this;
  }

  gte(column, value) {
    this.filters.push({ op: "gte", column, value, test: (row) => row[column] != null && row[column] >= value });
    return this;
  }

  maybeSingle() {
    return this.exec(true);
  }

  then(onFulfilled, onRejected) {
    return this.exec(false).then(onFulfilled, onRejected);
  }

  async exec(single) {
    const call = {
      table: this.table,
      action: this.action,
      values: this.values,
      filters: this.filters.map(({ op, column, value }) => [op, column, value]),
    };
    this.db.calls.push(call);
    const failure = this.db.failures?.[`${this.table}.${this.action}`];
    if (failure) return { data: null, error: { message: failure } };

    const rows = (this.db.tables[this.table] ??= []);
    const matched = rows.filter((row) => this.filters.every((f) => f.test(row)));
    if (this.action === "update") matched.forEach((row) => Object.assign(row, this.values));
    if (this.action === "delete") this.db.tables[this.table] = rows.filter((row) => !matched.includes(row));

    const data = matched.map((row) => ({ ...row }));
    if (single) {
      if (data.length > 1) return { data: null, error: { message: "multiple rows" } };
      return { data: data[0] ?? null, error: null };
    }
    return { data: this.columns ? data : null, error: null };
  }
}

export function createClient(url, key) {
  const db = globalThis.__fakeDb;
  if (!db) throw new Error("globalThis.__fakeDb tanımlı değil");
  db.clients = (db.clients ?? 0) + 1;
  db.lastClient = { url, key };
  return { from: (table) => new Query(db, table) };
}
