import dpq2;
import std.stdio;

void main()
{
	Connection conn = new Connection("postgres://localhost/pgvector_d_test");

	conn.exec("CREATE EXTENSION IF NOT EXISTS vector");
	conn.exec("DROP TABLE IF EXISTS items");
	conn.exec("CREATE TABLE items (id bigserial PRIMARY KEY, embedding vector(3))");

	QueryParams p;
	p.sqlCommand = "INSERT INTO items (embedding) VALUES ($1::vector), ($2::vector), ($3::vector)";
	p.argsVariadic([1, 1, 1], [2, 2, 2], [1, 1, 2]);
	conn.execParams(p);

	p.sqlCommand = "SELECT * FROM items ORDER BY embedding <-> $1::vector LIMIT 5";
	p.argsVariadic([1, 1, 1]);
	p.resultFormat = ValueFormat.TEXT;
	auto r = conn.execParams(p);
	foreach (row; rangify(r))
	{
		writeln(row);
	}

	conn.exec("CREATE INDEX ON items USING hnsw (embedding vector_l2_ops)");

	conn.destroy();
}
