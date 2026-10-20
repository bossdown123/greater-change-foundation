BEGIN;
CREATE TABLE events (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL CHECK(length(trim(title)) BETWEEN 1 AND 200),
  summary TEXT NOT NULL DEFAULT '',
  participant_count INTEGER CHECK(participant_count >= 0),
  funds_minor INTEGER CHECK(funds_minor >= 0),
  currency TEXT NOT NULL DEFAULT 'USD' CHECK(length(currency)=3),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
) STRICT;
CREATE TABLE event_dates (
  event_id TEXT NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  position INTEGER NOT NULL CHECK(position>=0),
  event_date TEXT NOT NULL,
  PRIMARY KEY(event_id,position),
  UNIQUE(event_id,event_date)
) STRICT;
CREATE TABLE locations (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL UNIQUE CHECK(length(trim(name)) BETWEEN 1 AND 300)
) STRICT;
CREATE TABLE event_locations (
  event_id TEXT NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  location_id TEXT NOT NULL REFERENCES locations(id) ON DELETE RESTRICT,
  position INTEGER NOT NULL CHECK(position>=0),
  PRIMARY KEY(event_id,location_id),
  UNIQUE(event_id,position)
) STRICT;
CREATE TABLE field_definitions (
  id TEXT PRIMARY KEY,
  label TEXT NOT NULL CHECK(length(trim(label)) BETWEEN 1 AND 100),
  kind TEXT NOT NULL CHECK(kind IN ('text','number','date','link')),
  UNIQUE(label,kind)
) STRICT;
CREATE TABLE event_field_values (
  event_id TEXT NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  field_id TEXT NOT NULL REFERENCES field_definitions(id) ON DELETE RESTRICT,
  position INTEGER NOT NULL CHECK(position>=0),
  text_value TEXT,
  number_value REAL,
  date_value TEXT,
  link_value TEXT,
  PRIMARY KEY(event_id,field_id),
  UNIQUE(event_id,position),
  CHECK((text_value IS NOT NULL)+(number_value IS NOT NULL)+(date_value IS NOT NULL)+(link_value IS NOT NULL)=1)
) STRICT;
CREATE TRIGGER validate_event_field_insert BEFORE INSERT ON event_field_values
WHEN NOT EXISTS (SELECT 1 FROM field_definitions f WHERE f.id=NEW.field_id AND
  ((f.kind='text' AND NEW.text_value IS NOT NULL) OR
   (f.kind='number' AND NEW.number_value IS NOT NULL) OR
   (f.kind='date' AND NEW.date_value IS NOT NULL) OR
   (f.kind='link' AND NEW.link_value IS NOT NULL)))
BEGIN SELECT RAISE(ABORT,'Custom field value does not match its definition'); END;
CREATE TRIGGER validate_event_field_update BEFORE UPDATE ON event_field_values
WHEN NOT EXISTS (SELECT 1 FROM field_definitions f WHERE f.id=NEW.field_id AND
  ((f.kind='text' AND NEW.text_value IS NOT NULL) OR
   (f.kind='number' AND NEW.number_value IS NOT NULL) OR
   (f.kind='date' AND NEW.date_value IS NOT NULL) OR
   (f.kind='link' AND NEW.link_value IS NOT NULL)))
BEGIN SELECT RAISE(ABORT,'Custom field value does not match its definition'); END;
CREATE TRIGGER field_kind_immutable BEFORE UPDATE OF kind ON field_definitions
BEGIN SELECT RAISE(ABORT,'Create a new definition to change the field type'); END;
CREATE TABLE media (
  id TEXT PRIMARY KEY,
  filename TEXT NOT NULL,
  mime_type TEXT NOT NULL CHECK(mime_type IN ('image/jpeg','image/png','image/webp')),
  size_bytes INTEGER NOT NULL CHECK(size_bytes > 0),
  storage_key TEXT NOT NULL UNIQUE,
  thumbnail_key TEXT NOT NULL UNIQUE,
  alt TEXT NOT NULL DEFAULT '',
  caption TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL
) STRICT;
CREATE TABLE event_media (
  event_id TEXT NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  media_id TEXT NOT NULL REFERENCES media(id) ON DELETE RESTRICT,
  position INTEGER NOT NULL CHECK(position>=0),
  PRIMARY KEY(event_id,media_id),
  UNIQUE(event_id,position)
) STRICT;
CREATE INDEX event_media_media ON event_media(media_id);
CREATE TABLE newsletters (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL CHECK(length(trim(title)) BETWEEN 1 AND 200),
  subject TEXT NOT NULL,
  introduction TEXT NOT NULL DEFAULT '',
  body TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
) STRICT;
CREATE TABLE newsletter_events (
  newsletter_id TEXT NOT NULL REFERENCES newsletters(id) ON DELETE CASCADE,
  event_id TEXT NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  position INTEGER NOT NULL CHECK(position>=0),
  PRIMARY KEY(newsletter_id,event_id),
  UNIQUE(newsletter_id,position)
) STRICT;
UPDATE gcf_schema SET version = 2 WHERE id = 1;
COMMIT;
