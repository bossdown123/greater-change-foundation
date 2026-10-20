BEGIN;
CREATE TEMP TABLE verify_schema (valid INTEGER NOT NULL CHECK (valid = 1));
INSERT INTO verify_schema SELECT count(*) FROM gcf_schema WHERE id = 1 AND version = 1;
DROP TABLE verify_schema;
ROLLBACK;
