SELECT id,title,summary FROM initiatives WHERE 0;
SELECT id,title,target_minor,raised_minor,currency,starts_on,ends_on FROM campaigns WHERE 0;
SELECT initiative_id,event_id,position FROM initiative_events WHERE 0;
SELECT campaign_id,event_id,position FROM campaign_events WHERE 0;
SELECT campaign_id,initiative_id,position FROM campaign_initiatives WHERE 0;
BEGIN;
CREATE TABLE verify_programmes(valid INTEGER NOT NULL CHECK(valid=1));
INSERT INTO verify_programmes SELECT version>=3 FROM gcf_schema WHERE id=1;
INSERT INTO verify_programmes SELECT COUNT(*)=0 FROM pragma_foreign_key_check;
INSERT INTO verify_programmes SELECT COUNT(*)=0 FROM newsletter_items i
LEFT JOIN newsletter_event_items e ON e.item_id=i.id
LEFT JOIN newsletter_initiative_items n ON n.item_id=i.id
LEFT JOIN newsletter_campaign_items c ON c.item_id=i.id
WHERE (e.item_id IS NOT NULL)+(n.item_id IS NOT NULL)+(c.item_id IS NOT NULL)<>1;
DROP TABLE verify_programmes;

ROLLBACK;
