BEGIN;
CREATE TABLE verify_media_groups(valid INTEGER CHECK(valid=1));
INSERT INTO verify_media_groups SELECT version>=9 FROM gcf_schema WHERE id=1;
INSERT INTO verify_media_groups SELECT COUNT(*)=0 FROM pragma_foreign_key_check;
INSERT INTO verify_media_groups SELECT COUNT(*)=0 FROM audit_context;
INSERT INTO verify_media_groups SELECT COUNT(*)=(SELECT COUNT(*) FROM media_groups) FROM media_groups_attribution;
DROP TABLE verify_media_groups;
ROLLBACK;
