BEGIN;
CREATE TABLE verify_rich_documents(valid INTEGER NOT NULL CHECK(valid=1));
INSERT INTO verify_rich_documents SELECT version>=7 FROM gcf_schema WHERE id=1;
INSERT INTO verify_rich_documents SELECT COUNT(*)=0 FROM pragma_foreign_key_check;
DROP TABLE verify_rich_documents;
ROLLBACK;
