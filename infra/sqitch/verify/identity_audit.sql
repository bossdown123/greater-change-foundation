BEGIN;
CREATE TABLE verify_identity_audit(valid INTEGER NOT NULL CHECK(valid=1));
INSERT INTO verify_identity_audit SELECT version>=4 FROM gcf_schema WHERE id=1;
INSERT INTO verify_identity_audit SELECT COUNT(*)=0 FROM pragma_foreign_key_check;
INSERT INTO verify_identity_audit SELECT COUNT(*)=0 FROM audit_context;
INSERT INTO verify_identity_audit SELECT COUNT(*)=2 FROM actors WHERE id IN ('legacy','bootstrap') AND kind='system';
INSERT INTO verify_identity_audit SELECT COUNT(*)=0 FROM audit_values WHERE column_name IN ('password_hash','session_version','password');
DROP TABLE verify_identity_audit;
ROLLBACK;
