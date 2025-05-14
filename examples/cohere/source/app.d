import dpq2;
import std.algorithm;
import std.format;
import std.json;
import std.net.curl;
import std.process;
import std.range;
import std.stdio;

string[] embed(string[] texts, string inputType)
{
    string apiKey = environment["CO_API_KEY"];
    string url = "https://api.cohere.com/v2/embed";
    JSONValue data = [ "texts": texts ];
    data.object["model"] = "embed-v4.0";
    data.object["input_type"] = inputType;
    data.object["embedding_types"] = ["ubinary"];

    auto client = HTTP();
    client.addRequestHeader("Authorization", "Bearer " ~ apiKey);
    client.addRequestHeader("Content-Type", "application/json");
    auto response = post(url, data.toString, client);

    auto embeddings = parseJSON(response)["embeddings"]["ubinary"].array;
    return embeddings.map!(e => e.array.map!(v => format("%08b", v.integer)).join()).array();
}

void main()
{
    Connection conn = new Connection("postgres://localhost/pgvector_example");

    conn.exec("CREATE EXTENSION IF NOT EXISTS vector");
    conn.exec("DROP TABLE IF EXISTS documents");
    conn.exec("CREATE TABLE documents (id bigserial PRIMARY KEY, content text, embedding bit(1536))");

    string[] documents = [
        "The dog is barking",
        "The cat is purring",
        "The bear is growling"
    ];
    auto embeddings = embed(documents, "search_document");
    foreach (content, embedding; zip(documents, embeddings))
    {
        QueryParams p;
        p.sqlCommand = "INSERT INTO documents (content, embedding) VALUES ($1, $2::varbit)";
        p.argsVariadic(content, embedding);
        conn.execParams(p);
    }

    string query = "forest";
    auto queryEmbedding = embed([query], "search_query")[0];
    QueryParams p;
    p.sqlCommand = "SELECT content FROM documents ORDER BY embedding <~> $1::varbit LIMIT 5";
    p.argsVariadic(queryEmbedding);
    p.resultFormat = ValueFormat.TEXT;
    auto r = conn.execParams(p);
    foreach (row; rangify(r))
    {
        writeln(row);
    }

    conn.destroy();
}
