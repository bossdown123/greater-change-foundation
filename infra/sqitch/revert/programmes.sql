BEGIN;
CREATE TABLE newsletter_events (
  newsletter_id TEXT NOT NULL REFERENCES newsletters(id) ON DELETE CASCADE,
  event_id TEXT NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  position INTEGER NOT NULL CHECK(position>=0),
  PRIMARY KEY(newsletter_id,event_id), UNIQUE(newsletter_id,position)
) STRICT;
INSERT INTO newsletter_events(newsletter_id,event_id,position)
SELECT i.newsletter_id,e.event_id,i.position FROM newsletter_items i JOIN newsletter_event_items e ON i.id=e.item_id;
DROP TRIGGER IF EXISTS newsletter_item_owner_immutable;
DROP TRIGGER IF EXISTS unique_newsletter_event_insert;
DROP TRIGGER IF EXISTS unique_newsletter_event_update;
DROP TRIGGER IF EXISTS unique_newsletter_initiative_insert;
DROP TRIGGER IF EXISTS unique_newsletter_initiative_update;
DROP TRIGGER IF EXISTS unique_newsletter_campaign_insert;
DROP TRIGGER IF EXISTS unique_newsletter_campaign_update;
DROP TRIGGER IF EXISTS clean_newsletter_event_item;
DROP TRIGGER IF EXISTS clean_newsletter_initiative_item;
DROP TRIGGER IF EXISTS clean_newsletter_campaign_item;
DROP TABLE newsletter_event_items;
DROP TABLE newsletter_initiative_items;
DROP TABLE newsletter_campaign_items;
DROP TABLE newsletter_items;
DROP TABLE campaign_initiatives;
DROP TABLE campaign_events;
DROP TABLE initiative_events;
DROP TABLE campaigns;
DROP TABLE initiatives;
UPDATE gcf_schema SET version=2 WHERE id=1;
COMMIT;
