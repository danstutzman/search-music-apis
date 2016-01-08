CREATE TABLE api_queries (
  api_query_id serial,
  song_source_num INT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL,
  api_name TEXT NOT NULL,
  artist_name TEXT NOT NULL,
  song_name TEXT NOT NULL,
  response_status_code INT NOT NULL,
  response_json TEXT NOT NULL,
  cover_image_url text,
  cover_image_path text
);
CREATE INDEX idx_api_queries_song_source_num ON api_queries(song_source_num);
