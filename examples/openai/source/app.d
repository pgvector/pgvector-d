import dpq2;
import std.algorithm;
import std.json;
import std.net.curl;
import std.process;
import std.range;
import std.stdio;

float[][] embed(string[] input)
{
    string apiKey = environment["OPENAI_API_KEY"];
    string url = "https://api.openai.com/v1/embeddings";
    JSONValue data = [ "input": input ];
    data.object["model"] = "text-embedding-3-small";

    auto client = HTTP();
    client.addRequestHeader("Authorization", "Bearer " ~ apiKey);
    client.addRequestHeader("Content-Type", "application/json");
    auto response = post(url, data.toString, client);

    float[][] embeddings;
    foreach(v; parseJSON(response)["data"].array)
    {
        embeddings ~= v["embedding"].array.map!(e => cast(float) e.floating).array();
    }
    return embeddings;
}

void main()
{
    Connection conn = new Connection("postgres://localhost/pgvector_example");

    conn.exec("CREATE EXTENSION IF NOT EXISTS vector");
    conn.exec("DROP TABLE IF EXISTS documents");
    conn.exec("CREATE TABLE documents (id bigserial PRIMARY KEY, content text, embedding vector(1536))");

    string[] documents = [
        "The dog is barking",
        "The cat is purring",
        "The bear is growling"
    ];
    float[][] embeddings = embed(documents);
    foreach (content, embedding; zip(documents, embeddings))
    {
        QueryParams p;
        p.sqlCommand = "INSERT INTO documents (content, embedding) VALUES ($1, $2::vector)";
        p.argsVariadic(content, embedding);
        conn.execParams(p);
    }

    string query = "forest";
    float[] queryEmbedding = embed([query])[0];
    QueryParams p;
    p.sqlCommand = "SELECT content FROM documents ORDER BY embedding <=> $1::vector LIMIT 5";
    p.argsVariadic(queryEmbedding);
    p.resultFormat = ValueFormat.TEXT;
    auto r = conn.execParams(p);
    foreach (row; rangify(r))
    {
        writeln(row);
    }

    conn.destroy();
}
