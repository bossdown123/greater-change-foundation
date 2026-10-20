# Content model and normalization

The baseline schema uses atomic columns and relations rather than JSON records.
Every relation is at least 3NF: a non-key fact depends on its candidate key, not
on another non-key fact. Keys and dependencies are explicit below.

| Relation | Key / candidate keys | Facts depending on that key |
|---|---|---|
| events | id | title, story, participant count, amount in minor currency units, currency, timestamps |
| event_dates | (event_id, position); (event_id, event_date) | a date's position within an event |
| locations | id; name | the reusable location name |
| event_locations | (event_id, location_id); (event_id, position) | display order of a location in an event |
| field_definitions | id; (label, kind) | reusable label and immutable value kind |
| event_field_values | (event_id, field_id); (event_id, position) | one typed atomic value and its display order |
| media | id; storage_key; thumbnail_key | original filename, format, byte size, description, caption, creation time |
| event_media | (event_id, media_id); (event_id, position) | a reusable image's display order within an event |
| newsletters | id | authored draft title, subject, introduction, body, timestamps |
| initiatives | id | initiative name, story, timestamps |
| campaigns | id | fundraising name/story, target and raised minor units, currency, optional dates, timestamps |
| initiative_events | (initiative_id, event_id); (initiative_id, position) | related event order |
| campaign_events | (campaign_id, event_id); (campaign_id, position) | explicitly linked event order |
| campaign_initiatives | (campaign_id, initiative_id); (campaign_id, position) | explicitly linked initiative order |
| newsletter_items | id; (newsletter_id, position) | selected update kind and mixed-type order |
| newsletter_event_items | item_id | source event foreign key, fixed event discriminator |
| newsletter_initiative_items | item_id | source initiative foreign key, fixed initiative discriminator |
| newsletter_campaign_items | item_id | source campaign foreign key, fixed campaign discriminator |

Dates, locations, custom facts and image assignments vary independently. Separate
relations prevent their Cartesian product and avoid multivalued dependencies in
one event row. Shared location names and field definitions are stored once. A
field's kind determines which value column is permitted; triggers enforce this
without duplicating the kind in the value relation. Each fact row contains
exactly one non-null value, never a collection. Currency amounts use integer
minor units; API decimal values are derived. No event totals are cached in other
records.

A newsletter body is an independently authored document, initially generated
from selected events. It is intentionally a snapshot, not a second authoritative
store of event facts. Editing an event does not silently rewrite an edited draft;
the administrator can explicitly regenerate it. Gallery usage counts and image
URLs are derived rather than persisted.

Do not claim a higher normal form without checking actual dependencies. These
small relations have no currently identified non-key join dependency that calls
for a further 5NF decomposition. Temporal histories or independently changing
attributes may justify 6NF relations when introduced. State the precise proposed
meaning of 7NF before designing or asserting it, since that label is not uniform
in database literature.

## Migration safety

All changes use Sqitch deploy/revert/verify scripts. The admin schema is new, so
its initial migration creates normalized relations directly. A future correction
must migrate existing data, not merely rename JSON columns or drop populated
tables. Stage a backup and a lossless transformation, validate row counts,
foreign keys, uniqueness and typed values, and test recovery before switching
application reads. Larger migrations are preferred when necessary to correct
normalization. Revert scripts for initial schema creation remove their data;
production rollback must restore the pre-migration backup when content exists.

## Events, initiatives and fundraising campaigns

An event is a dated activity. An initiative describes ongoing work; a campaign
describes a fundraising effort with its own target and recorded progress. They
are distinct entities, not JSON types in a shared catch-all table. Their names
and stories are different facts even when similar. Many-to-many relations link
existing records without copying them. No implication is stored between an
initiative's events and a campaign's directly selected events: these are
different relationships. Event and campaign amounts are entered independently;
no sum or donation-level accounting is implied.

Newsletter selections have a common ordered parent and three typed association
relations. Composite foreign keys enforce the discriminator; each association
has one real foreign key rather than an unchecked polymorphic identifier.
Triggers prevent selecting the same source twice and clean up a selection when
its source is deleted. The application writes parent and typed child in one
transaction; verification asserts exactly one child per parent. Changing the
owner or type requires rebuilding the selection instead of partial edits. The
constant discriminator in each child exists to enforce the composite foreign
key, not as a second mutable copy of a source fact.

The `programmes` migration transforms old event-only newsletter selections into
this model while preserving original order and authored text. An automated
upgrade-and-reversal test checks that preservation. The initial and admin
verification scripts accept later schema versions; they verify the enduring
objects they introduced rather than requiring the whole schema to remain at an
old version.

## Named identities and audit history (schema 4)

`actors.id` identifies an enduring principal. User actors have one `users` row
(key/foreign key `users.id`); system actors identify bootstrap work and legacy
imports. User names and unique, lower-case email addresses belong only to
`users`. System labels belong only to system actors. Accounts are disabled,
never deleted. Password hashes and session versions are private credentials.

Each content table has a one-to-one attribution relation (`events_attribution`,
`initiatives_attribution`, `campaigns_attribution`, `newsletters_attribution`,
`media_attribution`). `record_id` is its primary key and foreign key to the
content record; it determines the creator and most recent modifier actor IDs.
This avoids polymorphic foreign keys. Existing records explicitly reference the
legacy actor, without fabricating a human creator. Changes to ordered facts or
links also update the affected records' modifier attribution.

An Ash action establishes the authenticated actor and a unique action ID. The
SQL boundary puts that context, the domain mutation, and its audit entries in
the same `BEGIN IMMEDIATE` transaction. The transaction-local context relation
is empty after commit, and domain triggers reject writes without it. This uses
SQLite's single writer to prevent concurrent requests sharing an actor context.
A failed batch rolls back both content and audit. A multi-batch action uses one
action ID, so each committed change is attributable even if a subsequent read
fails. External object storage is not part of the SQL transaction: uploads are
compensated if persistence fails, while deletion is recorded when its database
reference is removed.

`audit_actions.id` determines actor, operation, historical resource identity and
title, and timestamp. These are observations at the action's time, not copies
of the resource's current mutable title. `audit_rows.id` determines the action,
table and row operation; `audit_values(row_id,column_name)` determines one
before/after pair and its scalar SQLite types. Composite record keys appear as
individual scalar fields; no relationship lists or JSON snapshots are stored.
Historical observations have their own keys and do not inherit the functional
dependencies of current domain entities. These relations meet 3NF; separate
change/field relations handle their independent repeating facts. No further
join or temporal dependency currently warrants 5NF/6NF decomposition.

Audit tables reject UPDATE and DELETE. This is an application/database integrity
boundary, not a claim of cryptographic tamper evidence against the server's
operator. Passwords, password hashes, cookies, CSRF tokens and session secrets
never enter audit values. Password changes use a non-secret change marker.
There are no endpoints for editing or deleting history. Sign-ins, sign-outs and
generated drafts are recorded as activities without invented database diffs.

The Sqitch upgrade preserves existing content and foreign keys and assigns legacy
attribution. Revert removes the new identity/history structures; production
rollback should restore the pre-deploy database backup if history must be kept.
Migration tests cover existing data, rollback atomicity, no-context rejection,
creator preservation, modifier changes, secrets exclusion and immutable history.

## Photo metadata (schema 5)

Photo dimensions, capture timestamps, geographic coordinates, embedded place
names and scan completion are separate relations keyed by `media_id` (place
names use `(media_id,kind)`). This keeps independently missing facts independent
and avoids a JSON metadata store. Each key determines its scalar attributes;
there are no transitive place hierarchies or inferred geographic identities.
The tables meet 3NF. Splitting these independent facts also provides the useful
6NF-style decomposition for sparse photo metadata without splitting coordinate
components that belong to one observation.

ExifTool reads allow-listed fields from originals; originals are never modified.
Stored dimensions account for EXIF orientation. The original capture time is
preferred, followed by recorded digitization time or GPS time with its explicit
source retained. Local time and optional UTC offset remain separate: missing
time zones, GPS or place names are not guessed, and filesystem/upload times do
not become capture dates. Date filtering uses the recorded local calendar day.
No reverse geocoding or external location lookup is performed.

Uploads persist metadata in the same audited SQL batch as the image record.
Authenticated re-extraction of existing originals also uses the Ash boundary;
metadata rows have the same context guards and immutable audit coverage as
other domain tables. Scan completion is tracked separately so a successfully
read image without EXIF is distinguishable from one still awaiting extraction.

## Reusable photo collections (schema 9)

`media_groups` owns a collection name and identity. `media_group_members` owns the
ordered many-to-many relation between collections and existing images. Its
candidate keys are `(group_id, media_id)` and `(group_id, position)`; the position
is dependent on the membership, never an attribute of the underlying photo.

`event_media_groups`, `initiative_media_groups`, `campaign_media_groups` and
`publication_media_groups` independently relate each real content type to groups.
Each has a real foreign key to its owner and to a collection, unique membership
and unique order per owner. Articles/newsletters share the publications key.
There are no unchecked polymorphic IDs, JSON membership arrays, copied images,
or independent copies of collection names, captions or counts. These relations
are in 3NF/BCNF; the independent memberships are decomposed to avoid multivalued
and join dependencies. No further decomposition would improve these facts.

API JSON arrays are transport representations of these relations. A photo may
belong to multiple groups. A group change is reflected by all links. Deleting a
linked group is restricted; deleting an image used by a group is restricted.
Removing a group or link never deletes a photo. Creator/modifier attribution and
membership changes use the same transaction-scoped actor audit as other content.
Existing data is unchanged. Sqitch reversal refuses to discard nonempty groups;
restore the paired database/registry backup for recovery with retained groups.
