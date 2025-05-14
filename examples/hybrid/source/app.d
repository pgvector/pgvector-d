import dpq2;
import std.algorithm;
import std.format;
import std.json;
import std.net.curl;
import std.process;
import std.range;
import std.stdio;

float[][] embed(string[] input, string taskType)
{
    // nomic-embed-text uses a task prefix
    // https://huggingface.co/nomic-ai/nomic-embed-text-v1.5
    string[] taskInput = input.map!(v => taskType ~ ": " ~ v).array();

    string url = "http://localhost:11434/api/embed";
    JSONValue data;
    data["input"] = taskInput;
    data["model"] = "nomic-embed-text";

    auto client = HTTP();
    client.addRequestHeader("Content-Type", "application/json");
    auto response = post(url, data.toString, client);

    auto embeddings = parseJSON(response)["embeddings"].array;
    return embeddings.map!(e => e.array.map!(v => cast(float) v.floating).array()).array();
}

void main()
{
    Connection conn = new Connection("postgres://localhost/pgvector_example");

    conn.exec("CREATE EXTENSION IF NOT EXISTS vector");
    conn.exec("DROP TABLE IF EXISTS documents");
    conn.exec("CREATE TABLE documents (id bigserial PRIMARY KEY, content text, embedding vector(768))");
    conn.exec("CREATE INDEX ON documents USING GIN (to_tsvector('english', content))");

    string[] documents = [
        "The dog is barking",
        "The cat is purring",
        "The bear is growling"
    ];
    auto embeddings = embed(documents, "search_document");
    foreach (content, embedding; zip(documents, embeddings))
    {
        QueryParams p;
        p.sqlCommand = "INSERT INTO documents (content, embedding) VALUES ($1, $2::vector)";
        p.argsVariadic(content, embedding);
        conn.execParams(p);
    }

    string sql = "
    WITH semantic_search AS (
        SELECT id, RANK () OVER (ORDER BY embedding <=> $2::vector) AS rank
        FROM documents
        ORDER BY embedding <=> $2::vector
        LIMIT 20
    ),
    keyword_search AS (
        SELECT id, RANK () OVER (ORDER BY ts_rank_cd(to_tsvector('english', content), query) DESC)
        FROM documents, plainto_tsquery('english', $1) query
        WHERE to_tsvector('english', content) @@ query
        ORDER BY ts_rank_cd(to_tsvector('english', content), query) DESC
        LIMIT 20
    )
    SELECT
        COALESCE(semantic_search.id, keyword_search.id) AS id,
        COALESCE(1.0 / ($3 + semantic_search.rank), 0.0) +
        COALESCE(1.0 / ($3 + keyword_search.rank), 0.0) AS score
    FROM semantic_search
    FULL OUTER JOIN keyword_search ON semantic_search.id = keyword_search.id
    ORDER BY score DESC
    LIMIT 5
    ";
    string query = "growling bear";
    auto queryEmbedding = embed([query], "search_query")[0];
    int k = 60;
    QueryParams p;
    p.sqlCommand = sql;
    p.argsVariadic(query, queryEmbedding, k);
    p.resultFormat = ValueFormat.TEXT;
    auto result = conn.execParams(p);
    foreach (row; rangify(result))
    {
        writeln(row);
    }

    conn.destroy();
}
