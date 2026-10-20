BEGIN;
-- Independent per-account presentation fact: user_id -> color, in 6NF.
CREATE TABLE user_colors(user_id TEXT PRIMARY KEY REFERENCES users(id),color TEXT NOT NULL CHECK(length(color)=7 AND substr(color,1,1)='#' AND substr(color,2) NOT GLOB '*[^0-9a-f]*')) STRICT;
INSERT INTO user_colors SELECT id, CASE (unicode(substr(id,1,1)) % 8) WHEN 0 THEN '#2563eb' WHEN 1 THEN '#a855f7' WHEN 2 THEN '#db2777' WHEN 3 THEN '#d97706' WHEN 4 THEN '#059669' WHEN 5 THEN '#0891b2' WHEN 6 THEN '#e11d48' ELSE '#4f46e5' END FROM users;
CREATE TRIGGER audit_guard_user_colors_insert BEFORE INSERT ON user_colors WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_user_colors_insert AFTER INSERT ON user_colors BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'user_colors','insert');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'user_id',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.user_id),CAST(NEW.user_id AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'color',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.color),CAST(NEW.color AS TEXT);
END;
CREATE TRIGGER audit_guard_user_colors_update BEFORE UPDATE ON user_colors WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_user_colors_update AFTER UPDATE ON user_colors BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'user_colors','update');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'user_id',typeof(OLD.user_id),CAST(OLD.user_id AS TEXT),typeof(NEW.user_id),CAST(NEW.user_id AS TEXT) WHERE OLD.user_id IS NOT NEW.user_id;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'color',typeof(OLD.color),CAST(OLD.color AS TEXT),typeof(NEW.color),CAST(NEW.color AS TEXT) WHERE OLD.color IS NOT NEW.color;
END;
CREATE TRIGGER audit_guard_user_colors_delete BEFORE DELETE ON user_colors WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_user_colors_delete AFTER DELETE ON user_colors BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'user_colors','delete');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'user_id',typeof(OLD.user_id),CAST(OLD.user_id AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'color',typeof(OLD.color),CAST(OLD.color AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
END;
UPDATE gcf_schema SET version=6 WHERE id=1;
COMMIT;
