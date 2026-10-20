BEGIN;
CREATE TABLE gcf_schema (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  version INTEGER NOT NULL CHECK (version > 0)
) STRICT;
INSERT INTO gcf_schema (id, version) VALUES (1, 1);
COMMIT;
