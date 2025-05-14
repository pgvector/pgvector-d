# pgvector-d

[pgvector](https://github.com/pgvector/pgvector) examples for D

Supports [dpq2](https://github.com/denizzzka/dpq2)

[![Build Status](https://github.com/pgvector/pgvector-d/actions/workflows/build.yml/badge.svg)](https://github.com/pgvector/pgvector-d/actions)

## Getting Started

Follow the instructions for your database library:

- [dpq2](#dpq2)

Or check out some examples:

- [Embeddings](examples/openai/source/app.d) with OpenAI
- [Binary embeddings](examples/cohere/source/app.d) with Cohere
- [Hybrid search](examples/hybrid/source/app.d) with Ollama (Reciprocal Rank Fusion)

## dpq2

Enable the extension

```d
conn.exec("CREATE EXTENSION IF NOT EXISTS vector");
```

Create a table

```d
conn.exec("CREATE TABLE items (id bigserial PRIMARY KEY, embedding vector(3))");
```

Insert vectors

```d
QueryParams p;
p.sqlCommand = "INSERT INTO items (embedding) VALUES ($1::vector), ($2::vector)";
p.argsVariadic([1, 2, 3], [4, 5, 6]);
conn.execParams(p);
```

Get the nearest neighbors

```d
QueryParams p;
p.sqlCommand = "SELECT * FROM items ORDER BY embedding <-> $1::vector LIMIT 5";
p.argsVariadic([3, 1, 2]);
p.resultFormat = ValueFormat.TEXT;
auto result = conn.execParams(p);
foreach (row; rangify(result))
{
    writeln(row);
}
```

Add an approximate index

```d
conn.exec("CREATE INDEX ON items USING hnsw (embedding vector_l2_ops)");
// or
conn.exec("CREATE INDEX ON items USING ivfflat (embedding vector_l2_ops) WITH (lists = 100)");
```

Use `vector_ip_ops` for inner product and `vector_cosine_ops` for cosine distance

See a [full example](source/app.d)

## Contributing

Everyone is encouraged to help improve this project. Here are a few ways you can help:

- [Report bugs](https://github.com/pgvector/pgvector-d/issues)
- Fix bugs and [submit pull requests](https://github.com/pgvector/pgvector-d/pulls)
- Write, clarify, or fix documentation
- Suggest or add new features

To get started with development:

```sh
git clone https://github.com/pgvector/pgvector-d.git
cd pgvector-d
createdb pgvector_d_test
dub run
```

Specify the path to libpq if needed:

```sh
DFLAGS="-L-L/opt/homebrew/opt/libpq/lib" dub run
```

To run an example:

```sh
cd examples/openai
createdb pgvector_example
dub run
```
