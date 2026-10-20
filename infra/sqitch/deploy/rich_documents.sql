BEGIN;
CREATE TABLE event_inline_media(event_id TEXT NOT NULL REFERENCES events(id) ON DELETE CASCADE,media_id TEXT NOT NULL REFERENCES media(id) ON DELETE RESTRICT,PRIMARY KEY(event_id,media_id)) STRICT;
CREATE INDEX event_inline_media_image ON event_inline_media(media_id);
CREATE TRIGGER audit_guard_event_inline_media_insert BEFORE INSERT ON event_inline_media WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_event_inline_media_insert AFTER INSERT ON event_inline_media BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'event_inline_media','insert');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'event_id',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.event_id),CAST(NEW.event_id AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'media_id',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.media_id),CAST(NEW.media_id AS TEXT);
 UPDATE events_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.event_id;
 UPDATE events SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=NEW.event_id;
END;
CREATE TRIGGER audit_guard_event_inline_media_update BEFORE UPDATE ON event_inline_media WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_event_inline_media_update AFTER UPDATE ON event_inline_media BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'event_inline_media','update');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'event_id',typeof(OLD.event_id),CAST(OLD.event_id AS TEXT),typeof(NEW.event_id),CAST(NEW.event_id AS TEXT) WHERE OLD.event_id IS NOT NEW.event_id;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'media_id',typeof(OLD.media_id),CAST(OLD.media_id AS TEXT),typeof(NEW.media_id),CAST(NEW.media_id AS TEXT) WHERE OLD.media_id IS NOT NEW.media_id;
 UPDATE events_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.event_id;
 UPDATE events SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=NEW.event_id;
END;
CREATE TRIGGER audit_guard_event_inline_media_delete BEFORE DELETE ON event_inline_media WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_event_inline_media_delete AFTER DELETE ON event_inline_media BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'event_inline_media','delete');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'event_id',typeof(OLD.event_id),CAST(OLD.event_id AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'media_id',typeof(OLD.media_id),CAST(OLD.media_id AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 UPDATE events_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=OLD.event_id;
 UPDATE events SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=OLD.event_id;
END;
CREATE TABLE initiative_inline_media(initiative_id TEXT NOT NULL REFERENCES initiatives(id) ON DELETE CASCADE,media_id TEXT NOT NULL REFERENCES media(id) ON DELETE RESTRICT,PRIMARY KEY(initiative_id,media_id)) STRICT;
CREATE INDEX initiative_inline_media_image ON initiative_inline_media(media_id);
CREATE TRIGGER audit_guard_initiative_inline_media_insert BEFORE INSERT ON initiative_inline_media WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_initiative_inline_media_insert AFTER INSERT ON initiative_inline_media BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'initiative_inline_media','insert');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'initiative_id',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.initiative_id),CAST(NEW.initiative_id AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'media_id',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.media_id),CAST(NEW.media_id AS TEXT);
 UPDATE initiatives_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.initiative_id;
 UPDATE initiatives SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=NEW.initiative_id;
END;
CREATE TRIGGER audit_guard_initiative_inline_media_update BEFORE UPDATE ON initiative_inline_media WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_initiative_inline_media_update AFTER UPDATE ON initiative_inline_media BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'initiative_inline_media','update');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'initiative_id',typeof(OLD.initiative_id),CAST(OLD.initiative_id AS TEXT),typeof(NEW.initiative_id),CAST(NEW.initiative_id AS TEXT) WHERE OLD.initiative_id IS NOT NEW.initiative_id;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'media_id',typeof(OLD.media_id),CAST(OLD.media_id AS TEXT),typeof(NEW.media_id),CAST(NEW.media_id AS TEXT) WHERE OLD.media_id IS NOT NEW.media_id;
 UPDATE initiatives_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.initiative_id;
 UPDATE initiatives SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=NEW.initiative_id;
END;
CREATE TRIGGER audit_guard_initiative_inline_media_delete BEFORE DELETE ON initiative_inline_media WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_initiative_inline_media_delete AFTER DELETE ON initiative_inline_media BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'initiative_inline_media','delete');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'initiative_id',typeof(OLD.initiative_id),CAST(OLD.initiative_id AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'media_id',typeof(OLD.media_id),CAST(OLD.media_id AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 UPDATE initiatives_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=OLD.initiative_id;
 UPDATE initiatives SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=OLD.initiative_id;
END;
CREATE TABLE campaign_inline_media(campaign_id TEXT NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,media_id TEXT NOT NULL REFERENCES media(id) ON DELETE RESTRICT,PRIMARY KEY(campaign_id,media_id)) STRICT;
CREATE INDEX campaign_inline_media_image ON campaign_inline_media(media_id);
CREATE TRIGGER audit_guard_campaign_inline_media_insert BEFORE INSERT ON campaign_inline_media WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_campaign_inline_media_insert AFTER INSERT ON campaign_inline_media BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'campaign_inline_media','insert');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'campaign_id',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.campaign_id),CAST(NEW.campaign_id AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'media_id',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.media_id),CAST(NEW.media_id AS TEXT);
 UPDATE campaigns_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.campaign_id;
 UPDATE campaigns SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=NEW.campaign_id;
END;
CREATE TRIGGER audit_guard_campaign_inline_media_update BEFORE UPDATE ON campaign_inline_media WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_campaign_inline_media_update AFTER UPDATE ON campaign_inline_media BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'campaign_inline_media','update');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'campaign_id',typeof(OLD.campaign_id),CAST(OLD.campaign_id AS TEXT),typeof(NEW.campaign_id),CAST(NEW.campaign_id AS TEXT) WHERE OLD.campaign_id IS NOT NEW.campaign_id;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'media_id',typeof(OLD.media_id),CAST(OLD.media_id AS TEXT),typeof(NEW.media_id),CAST(NEW.media_id AS TEXT) WHERE OLD.media_id IS NOT NEW.media_id;
 UPDATE campaigns_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.campaign_id;
 UPDATE campaigns SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=NEW.campaign_id;
END;
CREATE TRIGGER audit_guard_campaign_inline_media_delete BEFORE DELETE ON campaign_inline_media WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_campaign_inline_media_delete AFTER DELETE ON campaign_inline_media BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'campaign_inline_media','delete');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'campaign_id',typeof(OLD.campaign_id),CAST(OLD.campaign_id AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'media_id',typeof(OLD.media_id),CAST(OLD.media_id AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 UPDATE campaigns_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=OLD.campaign_id;
 UPDATE campaigns SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=OLD.campaign_id;
END;
CREATE TABLE newsletter_inline_media(newsletter_id TEXT NOT NULL REFERENCES newsletters(id) ON DELETE CASCADE,media_id TEXT NOT NULL REFERENCES media(id) ON DELETE RESTRICT,field TEXT NOT NULL CHECK(field IN ('introduction','body')),PRIMARY KEY(newsletter_id,media_id,field)) STRICT;
CREATE INDEX newsletter_inline_media_image ON newsletter_inline_media(media_id);
CREATE TRIGGER audit_guard_newsletter_inline_media_insert BEFORE INSERT ON newsletter_inline_media WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_newsletter_inline_media_insert AFTER INSERT ON newsletter_inline_media BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'newsletter_inline_media','insert');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'newsletter_id',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.newsletter_id),CAST(NEW.newsletter_id AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'media_id',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.media_id),CAST(NEW.media_id AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'field',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.field),CAST(NEW.field AS TEXT);
 UPDATE newsletters_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.newsletter_id;
 UPDATE newsletters SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=NEW.newsletter_id;
END;
CREATE TRIGGER audit_guard_newsletter_inline_media_update BEFORE UPDATE ON newsletter_inline_media WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_newsletter_inline_media_update AFTER UPDATE ON newsletter_inline_media BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'newsletter_inline_media','update');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'newsletter_id',typeof(OLD.newsletter_id),CAST(OLD.newsletter_id AS TEXT),typeof(NEW.newsletter_id),CAST(NEW.newsletter_id AS TEXT) WHERE OLD.newsletter_id IS NOT NEW.newsletter_id;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'media_id',typeof(OLD.media_id),CAST(OLD.media_id AS TEXT),typeof(NEW.media_id),CAST(NEW.media_id AS TEXT) WHERE OLD.media_id IS NOT NEW.media_id;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'field',typeof(OLD.field),CAST(OLD.field AS TEXT),typeof(NEW.field),CAST(NEW.field AS TEXT) WHERE OLD.field IS NOT NEW.field;
 UPDATE newsletters_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.newsletter_id;
 UPDATE newsletters SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=NEW.newsletter_id;
END;
CREATE TRIGGER audit_guard_newsletter_inline_media_delete BEFORE DELETE ON newsletter_inline_media WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_newsletter_inline_media_delete AFTER DELETE ON newsletter_inline_media BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'newsletter_inline_media','delete');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'newsletter_id',typeof(OLD.newsletter_id),CAST(OLD.newsletter_id AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'media_id',typeof(OLD.media_id),CAST(OLD.media_id AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'field',typeof(OLD.field),CAST(OLD.field AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 UPDATE newsletters_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=OLD.newsletter_id;
 UPDATE newsletters SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=OLD.newsletter_id;
END;
UPDATE gcf_schema SET version=7 WHERE id=1;
COMMIT;
