BEGIN;
CREATE TABLE initiatives (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL CHECK(length(trim(title)) BETWEEN 1 AND 200),
  summary TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
) STRICT;
CREATE TABLE campaigns (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL CHECK(length(trim(title)) BETWEEN 1 AND 200),
  summary TEXT NOT NULL DEFAULT '',
  target_minor INTEGER CHECK(target_minor >= 0),
  raised_minor INTEGER CHECK(raised_minor >= 0),
  currency TEXT NOT NULL CHECK(length(currency)=3),
  starts_on TEXT,
  ends_on TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  CHECK(starts_on IS NULL OR ends_on IS NULL OR starts_on<=ends_on)
) STRICT;
CREATE TABLE initiative_events (
  initiative_id TEXT NOT NULL REFERENCES initiatives(id) ON DELETE CASCADE,
  event_id TEXT NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  position INTEGER NOT NULL CHECK(position>=0),
  PRIMARY KEY(initiative_id,event_id), UNIQUE(initiative_id,position)
) STRICT;
CREATE TABLE campaign_events (
  campaign_id TEXT NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
  event_id TEXT NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  position INTEGER NOT NULL CHECK(position>=0),
  PRIMARY KEY(campaign_id,event_id), UNIQUE(campaign_id,position)
) STRICT;
CREATE TABLE campaign_initiatives (
  campaign_id TEXT NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
  initiative_id TEXT NOT NULL REFERENCES initiatives(id) ON DELETE CASCADE,
  position INTEGER NOT NULL CHECK(position>=0),
  PRIMARY KEY(campaign_id,initiative_id), UNIQUE(campaign_id,position)
) STRICT;
CREATE TABLE newsletter_items (
  id TEXT PRIMARY KEY,
  newsletter_id TEXT NOT NULL REFERENCES newsletters(id) ON DELETE CASCADE,
  position INTEGER NOT NULL CHECK(position>=0),
  kind TEXT NOT NULL CHECK(kind IN ('events','initiatives','campaigns')),
  UNIQUE(newsletter_id,position), UNIQUE(id,kind)
) STRICT;
CREATE TABLE newsletter_event_items (
  item_id TEXT PRIMARY KEY,
  kind TEXT NOT NULL DEFAULT 'events' CHECK(kind='events'),
  event_id TEXT NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  FOREIGN KEY(item_id,kind) REFERENCES newsletter_items(id,kind) ON DELETE CASCADE
) STRICT;
CREATE TABLE newsletter_initiative_items (
  item_id TEXT PRIMARY KEY,
  kind TEXT NOT NULL DEFAULT 'initiatives' CHECK(kind='initiatives'),
  initiative_id TEXT NOT NULL REFERENCES initiatives(id) ON DELETE CASCADE,
  FOREIGN KEY(item_id,kind) REFERENCES newsletter_items(id,kind) ON DELETE CASCADE
) STRICT;
CREATE TABLE newsletter_campaign_items (
  item_id TEXT PRIMARY KEY,
  kind TEXT NOT NULL DEFAULT 'campaigns' CHECK(kind='campaigns'),
  campaign_id TEXT NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
  FOREIGN KEY(item_id,kind) REFERENCES newsletter_items(id,kind) ON DELETE CASCADE
) STRICT;
INSERT INTO newsletter_items(id,newsletter_id,position,kind)
SELECT lower(hex(randomblob(16))),newsletter_id,position,'events' FROM newsletter_events;
INSERT INTO newsletter_event_items(item_id,event_id)
SELECT i.id,e.event_id FROM newsletter_items i JOIN newsletter_events e ON i.newsletter_id=e.newsletter_id AND i.position=e.position;
DROP TABLE newsletter_events;
CREATE TRIGGER clean_newsletter_event_item AFTER DELETE ON newsletter_event_items
BEGIN DELETE FROM newsletter_items WHERE id=OLD.item_id; END;
CREATE TRIGGER clean_newsletter_initiative_item AFTER DELETE ON newsletter_initiative_items
BEGIN DELETE FROM newsletter_items WHERE id=OLD.item_id; END;
CREATE TRIGGER clean_newsletter_campaign_item AFTER DELETE ON newsletter_campaign_items
BEGIN DELETE FROM newsletter_items WHERE id=OLD.item_id; END;
CREATE TRIGGER unique_newsletter_event_insert BEFORE INSERT ON newsletter_event_items
WHEN EXISTS(SELECT 1 FROM newsletter_event_items old JOIN newsletter_items oi ON old.item_id=oi.id JOIN newsletter_items ni ON ni.id=NEW.item_id WHERE oi.newsletter_id=ni.newsletter_id AND old.event_id=NEW.event_id AND old.item_id<>NEW.item_id)
BEGIN SELECT RAISE(ABORT,'An update may appear only once in a newsletter'); END;
CREATE TRIGGER unique_newsletter_event_update BEFORE UPDATE ON newsletter_event_items
WHEN EXISTS(SELECT 1 FROM newsletter_event_items old JOIN newsletter_items oi ON old.item_id=oi.id JOIN newsletter_items ni ON ni.id=NEW.item_id WHERE oi.newsletter_id=ni.newsletter_id AND old.event_id=NEW.event_id AND old.item_id<>NEW.item_id)
BEGIN SELECT RAISE(ABORT,'An update may appear only once in a newsletter'); END;
CREATE TRIGGER unique_newsletter_initiative_insert BEFORE INSERT ON newsletter_initiative_items
WHEN EXISTS(SELECT 1 FROM newsletter_initiative_items old JOIN newsletter_items oi ON old.item_id=oi.id JOIN newsletter_items ni ON ni.id=NEW.item_id WHERE oi.newsletter_id=ni.newsletter_id AND old.initiative_id=NEW.initiative_id AND old.item_id<>NEW.item_id)
BEGIN SELECT RAISE(ABORT,'An update may appear only once in a newsletter'); END;
CREATE TRIGGER unique_newsletter_initiative_update BEFORE UPDATE ON newsletter_initiative_items
WHEN EXISTS(SELECT 1 FROM newsletter_initiative_items old JOIN newsletter_items oi ON old.item_id=oi.id JOIN newsletter_items ni ON ni.id=NEW.item_id WHERE oi.newsletter_id=ni.newsletter_id AND old.initiative_id=NEW.initiative_id AND old.item_id<>NEW.item_id)
BEGIN SELECT RAISE(ABORT,'An update may appear only once in a newsletter'); END;
CREATE TRIGGER unique_newsletter_campaign_insert BEFORE INSERT ON newsletter_campaign_items
WHEN EXISTS(SELECT 1 FROM newsletter_campaign_items old JOIN newsletter_items oi ON old.item_id=oi.id JOIN newsletter_items ni ON ni.id=NEW.item_id WHERE oi.newsletter_id=ni.newsletter_id AND old.campaign_id=NEW.campaign_id AND old.item_id<>NEW.item_id)
BEGIN SELECT RAISE(ABORT,'An update may appear only once in a newsletter'); END;
CREATE TRIGGER unique_newsletter_campaign_update BEFORE UPDATE ON newsletter_campaign_items
WHEN EXISTS(SELECT 1 FROM newsletter_campaign_items old JOIN newsletter_items oi ON old.item_id=oi.id JOIN newsletter_items ni ON ni.id=NEW.item_id WHERE oi.newsletter_id=ni.newsletter_id AND old.campaign_id=NEW.campaign_id AND old.item_id<>NEW.item_id)
BEGIN SELECT RAISE(ABORT,'An update may appear only once in a newsletter'); END;
CREATE TRIGGER newsletter_item_owner_immutable BEFORE UPDATE OF newsletter_id,kind ON newsletter_items
BEGIN SELECT RAISE(ABORT,'Recreate a newsletter item to move it'); END;
UPDATE gcf_schema SET version=3 WHERE id=1;
COMMIT;
