BEGIN;
CREATE TABLE verify_media_metadata(valid INTEGER NOT NULL CHECK(valid=1));
INSERT INTO verify_media_metadata SELECT version>=5 FROM gcf_schema WHERE id=1;
INSERT INTO verify_media_metadata SELECT COUNT(*)=0 FROM pragma_foreign_key_check;
DROP TABLE verify_media_metadata;
ROLLBACK;
