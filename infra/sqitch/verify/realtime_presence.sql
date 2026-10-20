BEGIN;
CREATE TABLE verify_realtime_presence(valid INTEGER NOT NULL CHECK(valid=1));
INSERT INTO verify_realtime_presence SELECT version>=6 FROM gcf_schema WHERE id=1;
INSERT INTO verify_realtime_presence SELECT COUNT(*)=0 FROM pragma_foreign_key_check;
INSERT INTO verify_realtime_presence SELECT COUNT(*)=0 FROM users LEFT JOIN user_colors ON users.id=user_colors.user_id WHERE color IS NULL;
DROP TABLE verify_realtime_presence;
ROLLBACK;
