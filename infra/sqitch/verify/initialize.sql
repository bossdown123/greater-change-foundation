BEGIN;
CREATE TABLE gcf_verify_assertion (valid INTEGER NOT NULL CHECK (valid = 1));
INSERT INTO gcf_verify_assertion SELECT count(*) FROM gcf_schema WHERE id = 1 AND version >= 1;
DROP TABLE gcf_verify_assertion;
ROLLBACK;
