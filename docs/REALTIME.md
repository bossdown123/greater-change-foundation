# Realtime editing

The React workspace uses authenticated Phoenix Channels and Presence. An authenticated HTTP request issues a two-minute socket ticket bound to the account session version and cookie expiry. The channel rechecks the account on activity, committed changes and every 30 seconds. Password, role and access changes revoke existing sockets. Reconnection obtains a new ticket. Credentials are never broadcast; unsaved content is shared only with authenticated workspace peers. Production accepts the GCF domain; development accepts localhost.

Every successful audited database batch publishes an invalidation after COMMIT. Reads and pagination do not publish or enter the audit log. Clients retain search, loaded pages and selection while refreshing affected saved data. Editors merge untouched fields, retain local fields, and require explicit choices for competing saved values. An atomic revision check rejects a stale content save before changing data or writing an audit action. Presence does not lock a field. Transient draft messages expose competing unsaved edits without overwriting either draft.

Sidebar indicators use saved account colors, 4 px circles, 4 px gaps, and bottom-right alignment extending left. Field presence includes names and a 2 px outline using the last interactor’s color, with a joined lower-right tab. Keyboard focus remains independently visible. Password fields are excluded from field presence. Presence uses transient Phoenix processes, not database or audit records.

## Migration 6 normalization and recovery

`user_colors(user_id PK/FK users, color)` stores one independent presentation fact per account. The only nontrivial functional dependency is `user_id -> color`; it satisfies 3NF/BCNF and is an irreducible unary fact relation suitable for 6NF. Color need not be unique: different people may share a palette color, so names remain authoritative. Existing users are backfilled deterministically. New account creation inserts the color in the same audited transaction. Guards prevent untracked writes and changes appear in the immutable scalar audit history.

Sqitch deploy/revert/verify covers the color relation. Revert drops only colors and returns schema version 5; accounts, content and audit history survive. Deployments back up database and Sqitch state first.

## Five-minute autosave

Events, initiatives, campaigns, newsletters and image descriptions save automatically five minutes after they become dirty. Additional typing does not postpone the deadline. Clean records do not write or generate audit entries. A successful manual save satisfies the pending deadline. Saves use the existing authenticated Ash endpoint and revision guard.

Manual and automatic requests share a lock. The response only acknowledges the submitted snapshot; text entered while the request runs stays in the draft for the next save. Remote updates are deferred during a save to avoid treating the acknowledgement as a conflicting edit. Unresolved conflicts, an active request, a disconnected channel or an offline browser pause autosave. Browser timers may be suspended in the background; focus, visibility and reconnection recheck any overdue deadline. Existing leave-with-unsaved-changes checks remain.

Field presence stays attached when switching windows and expires after five minutes without interaction. The current editor is included in its colored field frame. Each connection has a server-generated ID; multiple tabs are distinguishable while account names remain deduplicated. Changes to unsaved content fields are shared as transient channel messages, restricted to an allowlist and size limit. They never enter the audit log. Competing unsaved values produce immediate explicit conflict choices; unresolved conflicts pause autosave. Saved changes still use atomic revision checks. Conflict controls sit outside the scrolling document so they remain visible.
