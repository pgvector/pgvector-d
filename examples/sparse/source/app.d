import dpq2;
import std.algorithm;
import std.conv;
import std.json;
import std.net.curl;
import std.process;
import std.range;
import std.stdio;
import std.typecons;

float[int][] embed(string[] inputs)
{
    string url = "http://localhost:3000/embed_sparse";
    JSONValue data;
    data["inputs"] = inputs;

    auto client = HTTP();
    client.addRequestHeader("Content-Type", "application/json");
    auto response = post(url, data.toString, client);

    auto embeddings = parseJSON(response).array;
    return embeddings.map!(e => assocArray(e.array.map!(v => tuple(cast(int) v["index"].integer, cast(float) v["value"].floating)))).array();
}

string sparsevec(float[int] elements, int dim)
{
    return "{" ~ elements.byKeyValue.map!(e => to!string(e.key + 1) ~ ":" ~ to!string(e.value)).join(",") ~ "}/" ~ to!string(dim);
}

void main()
{
    Connection conn = new Connection("postgres://localhost/pgvector_example");

    conn.exec("CREATE EXTENSION IF NOT EXISTS vector");
    conn.exec("DROP TABLE IF EXISTS documents");
    conn.exec("CREATE TABLE documents (id bigserial PRIMARY KEY, content text, embedding sparsevec(30522))");

    string[] documents = [
        "The dog is barking",
        "The cat is purring",
        "The bear is growling"
    ];
    auto embeddings = embed(documents);
    foreach (content, embedding; zip(documents, embeddings))
    {
        QueryParams p;
        p.sqlCommand = "INSERT INTO documents (content, embedding) VALUES ($1, $2::sparsevec)";
        p.argsVariadic(content, sparsevec(embedding, 30522));
        conn.execParams(p);
    }

    string query = "forest";
    auto queryEmbedding = embed([query])[0];
    QueryParams p;
    p.sqlCommand = "SELECT content FROM documents ORDER BY embedding <=> $1::sparsevec LIMIT 5";
    p.argsVariadic(sparsevec(queryEmbedding, 30522));
    p.resultFormat = ValueFormat.TEXT;
    auto result = conn.execParams(p);
    foreach (row; rangify(result))
    {
        writeln(row);
    }

    conn.destroy();
}
