BEGIN;
CREATE TABLE media_groups (
 id TEXT PRIMARY KEY CHECK(length(id)=32),
 title TEXT NOT NULL CHECK(length(trim(title)) BETWEEN 1 AND 200),
 created_at TEXT NOT NULL,
 updated_at TEXT NOT NULL
) STRICT;
CREATE TABLE media_groups_attribution (
 record_id TEXT PRIMARY KEY REFERENCES media_groups(id) ON DELETE CASCADE,
 created_by TEXT NOT NULL REFERENCES actors(id),
 updated_by TEXT NOT NULL REFERENCES actors(id)
) STRICT;
CREATE TABLE media_group_members (
 group_id TEXT NOT NULL REFERENCES media_groups(id) ON DELETE CASCADE,
 media_id TEXT NOT NULL REFERENCES media(id) ON DELETE RESTRICT,
 position INTEGER NOT NULL CHECK(position>=0),
 PRIMARY KEY(group_id,media_id), UNIQUE(group_id,position)
) STRICT;
CREATE INDEX media_group_members_media ON media_group_members(media_id,group_id);
CREATE TABLE event_media_groups (
 event_id TEXT NOT NULL REFERENCES events(id) ON DELETE CASCADE,
 group_id TEXT NOT NULL REFERENCES media_groups(id) ON DELETE RESTRICT,
 position INTEGER NOT NULL CHECK(position>=0),
 PRIMARY KEY(event_id,group_id), UNIQUE(event_id,position)
) STRICT;
CREATE INDEX event_media_groups_group ON event_media_groups(group_id);
CREATE TABLE initiative_media_groups (
 initiative_id TEXT NOT NULL REFERENCES initiatives(id) ON DELETE CASCADE,
 group_id TEXT NOT NULL REFERENCES media_groups(id) ON DELETE RESTRICT,
 position INTEGER NOT NULL CHECK(position>=0),
 PRIMARY KEY(initiative_id,group_id), UNIQUE(initiative_id,position)
) STRICT;
CREATE INDEX initiative_media_groups_group ON initiative_media_groups(group_id);
CREATE TABLE campaign_media_groups (
 campaign_id TEXT NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
 group_id TEXT NOT NULL REFERENCES media_groups(id) ON DELETE RESTRICT,
 position INTEGER NOT NULL CHECK(position>=0),
 PRIMARY KEY(campaign_id,group_id), UNIQUE(campaign_id,position)
) STRICT;
CREATE INDEX campaign_media_groups_group ON campaign_media_groups(group_id);
CREATE TABLE publication_media_groups (
 publication_id TEXT NOT NULL REFERENCES publications(id) ON DELETE CASCADE,
 group_id TEXT NOT NULL REFERENCES media_groups(id) ON DELETE RESTRICT,
 position INTEGER NOT NULL CHECK(position>=0),
 PRIMARY KEY(publication_id,group_id), UNIQUE(publication_id,position)
) STRICT;
CREATE INDEX publication_media_groups_group ON publication_media_groups(group_id);
CREATE TRIGGER audit_guard_media_groups_insert BEFORE INSERT ON media_groups WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_media_groups_insert AFTER INSERT ON media_groups BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'media_groups','insert');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'id',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.id),CAST(NEW.id AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'title',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.title),CAST(NEW.title AS TEXT);
 INSERT INTO media_groups_attribution VALUES(NEW.id,(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)),(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)));
 UPDATE media_groups SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=NEW.id;
END;
CREATE TRIGGER audit_guard_media_groups_update BEFORE UPDATE ON media_groups WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_media_groups_update AFTER UPDATE ON media_groups WHEN OLD.id IS NOT NEW.id OR OLD.title IS NOT NEW.title BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'media_groups','update');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'id',typeof(OLD.id),CAST(OLD.id AS TEXT),typeof(NEW.id),CAST(NEW.id AS TEXT) WHERE OLD.id IS NOT NEW.id;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'title',typeof(OLD.title),CAST(OLD.title AS TEXT),typeof(NEW.title),CAST(NEW.title AS TEXT) WHERE OLD.title IS NOT NEW.title;
 UPDATE media_groups_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.id;
 UPDATE media_groups SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=NEW.id;
END;
CREATE TRIGGER audit_guard_media_groups_delete BEFORE DELETE ON media_groups WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_media_groups_delete AFTER DELETE ON media_groups BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'media_groups','delete');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'id',typeof(OLD.id),CAST(OLD.id AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'title',typeof(OLD.title),CAST(OLD.title AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
END;
CREATE TRIGGER audit_guard_media_group_members_insert BEFORE INSERT ON media_group_members WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_media_group_members_insert AFTER INSERT ON media_group_members BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'media_group_members','insert');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'group_id',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.group_id),CAST(NEW.group_id AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'media_id',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.media_id),CAST(NEW.media_id AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'position',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.position),CAST(NEW.position AS TEXT);
 UPDATE media_groups_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.group_id;
 UPDATE media_groups SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=NEW.group_id;
 UPDATE media_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.media_id;
 UPDATE media SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=NEW.media_id;
END;
CREATE TRIGGER audit_guard_media_group_members_update BEFORE UPDATE ON media_group_members WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_media_group_members_update AFTER UPDATE ON media_group_members WHEN OLD.group_id IS NOT NEW.group_id OR OLD.media_id IS NOT NEW.media_id OR OLD.position IS NOT NEW.position BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'media_group_members','update');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'group_id',typeof(OLD.group_id),CAST(OLD.group_id AS TEXT),typeof(NEW.group_id),CAST(NEW.group_id AS TEXT) WHERE OLD.group_id IS NOT NEW.group_id;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'media_id',typeof(OLD.media_id),CAST(OLD.media_id AS TEXT),typeof(NEW.media_id),CAST(NEW.media_id AS TEXT) WHERE OLD.media_id IS NOT NEW.media_id;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'position',typeof(OLD.position),CAST(OLD.position AS TEXT),typeof(NEW.position),CAST(NEW.position AS TEXT) WHERE OLD.position IS NOT NEW.position;
 UPDATE media_groups_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.group_id;
 UPDATE media_groups SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=NEW.group_id;
 UPDATE media_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.media_id;
 UPDATE media SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=NEW.media_id;
END;
CREATE TRIGGER audit_guard_media_group_members_delete BEFORE DELETE ON media_group_members WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_media_group_members_delete AFTER DELETE ON media_group_members BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'media_group_members','delete');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'group_id',typeof(OLD.group_id),CAST(OLD.group_id AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'media_id',typeof(OLD.media_id),CAST(OLD.media_id AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'position',typeof(OLD.position),CAST(OLD.position AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 UPDATE media_groups_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=OLD.group_id;
 UPDATE media_groups SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=OLD.group_id;
 UPDATE media_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=OLD.media_id;
 UPDATE media SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=OLD.media_id;
END;
CREATE TRIGGER immutable_media_group_members_identity BEFORE UPDATE ON media_group_members WHEN OLD.group_id IS NOT NEW.group_id OR OLD.media_id IS NOT NEW.media_id BEGIN SELECT RAISE(ABORT,'Replace relationship identities rather than moving them'); END;
CREATE TRIGGER audit_guard_event_media_groups_insert BEFORE INSERT ON event_media_groups WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_event_media_groups_insert AFTER INSERT ON event_media_groups BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'event_media_groups','insert');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'event_id',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.event_id),CAST(NEW.event_id AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'group_id',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.group_id),CAST(NEW.group_id AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'position',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.position),CAST(NEW.position AS TEXT);
 UPDATE events_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.event_id;
 UPDATE events SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=NEW.event_id;
END;
CREATE TRIGGER audit_guard_event_media_groups_update BEFORE UPDATE ON event_media_groups WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_event_media_groups_update AFTER UPDATE ON event_media_groups WHEN OLD.event_id IS NOT NEW.event_id OR OLD.group_id IS NOT NEW.group_id OR OLD.position IS NOT NEW.position BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'event_media_groups','update');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'event_id',typeof(OLD.event_id),CAST(OLD.event_id AS TEXT),typeof(NEW.event_id),CAST(NEW.event_id AS TEXT) WHERE OLD.event_id IS NOT NEW.event_id;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'group_id',typeof(OLD.group_id),CAST(OLD.group_id AS TEXT),typeof(NEW.group_id),CAST(NEW.group_id AS TEXT) WHERE OLD.group_id IS NOT NEW.group_id;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'position',typeof(OLD.position),CAST(OLD.position AS TEXT),typeof(NEW.position),CAST(NEW.position AS TEXT) WHERE OLD.position IS NOT NEW.position;
 UPDATE events_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.event_id;
 UPDATE events SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=NEW.event_id;
END;
CREATE TRIGGER audit_guard_event_media_groups_delete BEFORE DELETE ON event_media_groups WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_event_media_groups_delete AFTER DELETE ON event_media_groups BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'event_media_groups','delete');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'event_id',typeof(OLD.event_id),CAST(OLD.event_id AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'group_id',typeof(OLD.group_id),CAST(OLD.group_id AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'position',typeof(OLD.position),CAST(OLD.position AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 UPDATE events_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=OLD.event_id;
 UPDATE events SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=OLD.event_id;
END;
CREATE TRIGGER immutable_event_media_groups_identity BEFORE UPDATE ON event_media_groups WHEN OLD.event_id IS NOT NEW.event_id OR OLD.group_id IS NOT NEW.group_id BEGIN SELECT RAISE(ABORT,'Replace relationship identities rather than moving them'); END;
CREATE TRIGGER audit_guard_initiative_media_groups_insert BEFORE INSERT ON initiative_media_groups WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_initiative_media_groups_insert AFTER INSERT ON initiative_media_groups BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'initiative_media_groups','insert');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'initiative_id',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.initiative_id),CAST(NEW.initiative_id AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'group_id',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.group_id),CAST(NEW.group_id AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'position',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.position),CAST(NEW.position AS TEXT);
 UPDATE initiatives_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.initiative_id;
 UPDATE initiatives SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=NEW.initiative_id;
END;
CREATE TRIGGER audit_guard_initiative_media_groups_update BEFORE UPDATE ON initiative_media_groups WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_initiative_media_groups_update AFTER UPDATE ON initiative_media_groups WHEN OLD.initiative_id IS NOT NEW.initiative_id OR OLD.group_id IS NOT NEW.group_id OR OLD.position IS NOT NEW.position BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'initiative_media_groups','update');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'initiative_id',typeof(OLD.initiative_id),CAST(OLD.initiative_id AS TEXT),typeof(NEW.initiative_id),CAST(NEW.initiative_id AS TEXT) WHERE OLD.initiative_id IS NOT NEW.initiative_id;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'group_id',typeof(OLD.group_id),CAST(OLD.group_id AS TEXT),typeof(NEW.group_id),CAST(NEW.group_id AS TEXT) WHERE OLD.group_id IS NOT NEW.group_id;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'position',typeof(OLD.position),CAST(OLD.position AS TEXT),typeof(NEW.position),CAST(NEW.position AS TEXT) WHERE OLD.position IS NOT NEW.position;
 UPDATE initiatives_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.initiative_id;
 UPDATE initiatives SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=NEW.initiative_id;
END;
CREATE TRIGGER audit_guard_initiative_media_groups_delete BEFORE DELETE ON initiative_media_groups WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_initiative_media_groups_delete AFTER DELETE ON initiative_media_groups BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'initiative_media_groups','delete');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'initiative_id',typeof(OLD.initiative_id),CAST(OLD.initiative_id AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'group_id',typeof(OLD.group_id),CAST(OLD.group_id AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'position',typeof(OLD.position),CAST(OLD.position AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 UPDATE initiatives_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=OLD.initiative_id;
 UPDATE initiatives SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=OLD.initiative_id;
END;
CREATE TRIGGER immutable_initiative_media_groups_identity BEFORE UPDATE ON initiative_media_groups WHEN OLD.initiative_id IS NOT NEW.initiative_id OR OLD.group_id IS NOT NEW.group_id BEGIN SELECT RAISE(ABORT,'Replace relationship identities rather than moving them'); END;
CREATE TRIGGER audit_guard_campaign_media_groups_insert BEFORE INSERT ON campaign_media_groups WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_campaign_media_groups_insert AFTER INSERT ON campaign_media_groups BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'campaign_media_groups','insert');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'campaign_id',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.campaign_id),CAST(NEW.campaign_id AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'group_id',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.group_id),CAST(NEW.group_id AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'position',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.position),CAST(NEW.position AS TEXT);
 UPDATE campaigns_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.campaign_id;
 UPDATE campaigns SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=NEW.campaign_id;
END;
CREATE TRIGGER audit_guard_campaign_media_groups_update BEFORE UPDATE ON campaign_media_groups WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_campaign_media_groups_update AFTER UPDATE ON campaign_media_groups WHEN OLD.campaign_id IS NOT NEW.campaign_id OR OLD.group_id IS NOT NEW.group_id OR OLD.position IS NOT NEW.position BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'campaign_media_groups','update');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'campaign_id',typeof(OLD.campaign_id),CAST(OLD.campaign_id AS TEXT),typeof(NEW.campaign_id),CAST(NEW.campaign_id AS TEXT) WHERE OLD.campaign_id IS NOT NEW.campaign_id;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'group_id',typeof(OLD.group_id),CAST(OLD.group_id AS TEXT),typeof(NEW.group_id),CAST(NEW.group_id AS TEXT) WHERE OLD.group_id IS NOT NEW.group_id;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'position',typeof(OLD.position),CAST(OLD.position AS TEXT),typeof(NEW.position),CAST(NEW.position AS TEXT) WHERE OLD.position IS NOT NEW.position;
 UPDATE campaigns_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.campaign_id;
 UPDATE campaigns SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=NEW.campaign_id;
END;
CREATE TRIGGER audit_guard_campaign_media_groups_delete BEFORE DELETE ON campaign_media_groups WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_campaign_media_groups_delete AFTER DELETE ON campaign_media_groups BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'campaign_media_groups','delete');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'campaign_id',typeof(OLD.campaign_id),CAST(OLD.campaign_id AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'group_id',typeof(OLD.group_id),CAST(OLD.group_id AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'position',typeof(OLD.position),CAST(OLD.position AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 UPDATE campaigns_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=OLD.campaign_id;
 UPDATE campaigns SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=OLD.campaign_id;
END;
CREATE TRIGGER immutable_campaign_media_groups_identity BEFORE UPDATE ON campaign_media_groups WHEN OLD.campaign_id IS NOT NEW.campaign_id OR OLD.group_id IS NOT NEW.group_id BEGIN SELECT RAISE(ABORT,'Replace relationship identities rather than moving them'); END;
CREATE TRIGGER audit_guard_publication_media_groups_insert BEFORE INSERT ON publication_media_groups WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_publication_media_groups_insert AFTER INSERT ON publication_media_groups BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'publication_media_groups','insert');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'publication_id',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.publication_id),CAST(NEW.publication_id AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'group_id',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.group_id),CAST(NEW.group_id AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'position',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.position),CAST(NEW.position AS TEXT);
 UPDATE newsletters_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.publication_id;
 UPDATE publications SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=NEW.publication_id;
END;
CREATE TRIGGER audit_guard_publication_media_groups_update BEFORE UPDATE ON publication_media_groups WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_publication_media_groups_update AFTER UPDATE ON publication_media_groups WHEN OLD.publication_id IS NOT NEW.publication_id OR OLD.group_id IS NOT NEW.group_id OR OLD.position IS NOT NEW.position BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'publication_media_groups','update');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'publication_id',typeof(OLD.publication_id),CAST(OLD.publication_id AS TEXT),typeof(NEW.publication_id),CAST(NEW.publication_id AS TEXT) WHERE OLD.publication_id IS NOT NEW.publication_id;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'group_id',typeof(OLD.group_id),CAST(OLD.group_id AS TEXT),typeof(NEW.group_id),CAST(NEW.group_id AS TEXT) WHERE OLD.group_id IS NOT NEW.group_id;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'position',typeof(OLD.position),CAST(OLD.position AS TEXT),typeof(NEW.position),CAST(NEW.position AS TEXT) WHERE OLD.position IS NOT NEW.position;
 UPDATE newsletters_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.publication_id;
 UPDATE publications SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=NEW.publication_id;
END;
CREATE TRIGGER audit_guard_publication_media_groups_delete BEFORE DELETE ON publication_media_groups WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_publication_media_groups_delete AFTER DELETE ON publication_media_groups BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'publication_media_groups','delete');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'publication_id',typeof(OLD.publication_id),CAST(OLD.publication_id AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'group_id',typeof(OLD.group_id),CAST(OLD.group_id AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'position',typeof(OLD.position),CAST(OLD.position AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 UPDATE newsletters_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=OLD.publication_id;
 UPDATE publications SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=OLD.publication_id;
END;
CREATE TRIGGER immutable_publication_media_groups_identity BEFORE UPDATE ON publication_media_groups WHEN OLD.publication_id IS NOT NEW.publication_id OR OLD.group_id IS NOT NEW.group_id BEGIN SELECT RAISE(ABORT,'Replace relationship identities rather than moving them'); END;
CREATE TRIGGER guard_media_groups_attribution_insert BEFORE INSERT ON media_groups_attribution WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER guard_media_groups_attribution_update BEFORE UPDATE ON media_groups_attribution WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER guard_media_groups_attribution_delete BEFORE DELETE ON media_groups_attribution WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
UPDATE gcf_schema SET version=9 WHERE id=1;
COMMIT;
