# Greater Change Foundation design principles

These principles guide all future website design and implementation. They do not
expand the current scope: the public website remains **GCF UNDER DEVELOPMENT**
until further content or functionality is requested.

## An open page, not a collection of cards

Build layouts around content, typography, imagery, spacing, alignment, and clear
section boundaries. Do not use cards or bordered containers as the default way
to group everything. A section does not need a box to be understandable.

Cards are an exception for content that genuinely behaves as a self-contained
unit. Placing one card inside another is strongly discouraged. Any exception
must have a concrete functional reason that cannot be expressed clearly with a
flatter layout; decoration or convenient grouping is not enough.

## Show, don’t tell

Let the actual content, preview, controls, icons, hierarchy, and visual feedback
communicate what the workspace does. Do not narrate an interface the user can
already see. Avoid repeated section names, explanatory headers, instructional
empty-state paragraphs, and labels describing an obvious icon or action.

Keep essential text: field labels, accessible names, errors, save/upload
feedback, meaningful empty/search states, and publication state. Icon controls
need accessible names and tooltips; color must never be the only status cue.
Use the requested compact publication stoplight: left-aligned Hidden, Draft,
and Published labels alongside vertically stacked red, blue, and green lights,
with the actual state clearly active. Never imply publication has occurred when
it has not.

Previews show the generated output directly. Empty fields should not be filled
with instructions. Collections paginate lazily in bounded batches as users scroll. Never show page
number selectors or Previous/Next page controls. Preserve loaded content,
selection and scroll position, and provide concise loading/end feedback only
where it helps.

## Keep the document structure shallow

Use semantic HTML and the fewest wrappers needed for layout, behavior, and
accessibility. Avoid heavy `div` nesting, redundant wrapper components, and
repeated container-inside-container structures. Do not add a wrapper simply to
carry another border, background, shadow, or corner radius.

This is a rule against unnecessary structure, not a ban on useful `main`,
`section`, `nav`, or other semantic elements. Keep the DOM understandable and
make layout ownership clear.

## Choose UX primitives through an independently briefed subagent

Before implementing a new or materially changed interaction, have a dedicated
subagent choose the UX primitives. This applies to decisions such as whether a
use case needs tabs, a disclosure, a dropdown, a sidebar, or a plain visible
section.

Give that subagent only an abstract description of the user problem and the
context needed to solve it:

- Who the users are and what they are trying to accomplish.
- What information or actions are involved, their relative importance, and any
  relationships or dependencies between them.
- Relevant constraints, including charity context, mobile and desktop use,
  accessibility, and information that must remain visible.

Do not supply a proposed component, preferred primitive, existing JSX/DOM tree,
or a layout to imitate. Avoid leading briefs such as “design an accordion for
this.” Ask the subagent to recommend the simplest suitable primitive, explain
what stays visible and what can be revealed, and describe its mobile and desktop
behavior. Plain visible content is a valid recommendation.

The implementing agent applies that recommendation within these principles. If
new constraints invalidate it, return an updated abstract brief to the subagent
rather than silently substituting a preferred interaction.

## Reveal information progressively without hiding the charity

Layer information through interaction and hierarchy rather than nested boxes.
Use collapsible sidebars, expandable sections, dropdowns, or tabs when they help
people move between related material or reveal secondary detail. Avoid massive,
undifferentiated lists when meaningful grouping or progressive disclosure would
make them easier to use.

Be selective about what is hidden. This is a charity website: most public
information should be visible by default. When such content is introduced,
visitors should be able to understand the mission, who the charity helps, its
work and impact, and how to support or contact it without opening a sequence of
controls. Important trust information and primary actions must remain easy to
find. These are visibility priorities, not instructions to invent or add content.

Reserve disclosure for supplementary explanations, optional detail, genuinely
alternative views, or long supporting material. Do not put every section behind
an accordion, use dropdowns for ordinary reading, or hide essential information
merely to make a page look shorter. Label revealed content clearly and make its
relationship to the visible information obvious.

## Design mobile and desktop together

Treat both as first-class experiences throughout design and implementation.
The website must be highly responsive, with layouts, typography, imagery,
navigation, and interactions adapted thoughtfully to the available space.

Preserve the same essential content and capabilities on both. Mobile should not
be a squeezed desktop layout, and desktop should not be a stretched phone page.
Reflow and prioritize content before hiding it. A collapsible navigation sidebar
may suit a narrow screen, but the charity's core public information should still
be visible in the page.

Check narrow phones, larger phones, tablets, and desktop widths while building.
Prevent unintended horizontal scrolling; preserve readable text, comfortable
touch targets, visible keyboard focus, and accessible navigation. Revealed
sections must remain usable by touch, keyboard, and assistive technology.

## Use supplied graphics creatively and purposefully

Let supplied photography, illustrations, logos, and other graphics contribute to
the composition and the story. Use considered scale, placement, cropping,
rhythm, and relationships with text instead of putting every graphic in an
identical card or treating it as generic decoration.

Preserve the meaning and integrity of the supplied material. Adapt artwork and
image crops to mobile and desktop without distorting logos or obscuring important
subjects. Protect text contrast and legibility, provide appropriate alternative
text, and optimize assets for loading performance.

## Review before shipping

- Does the page have a clear content hierarchy without relying on boxes?
- Are there unnecessary wrappers, nested containers, or cards within cards?
- Were interaction primitives chosen by an independently briefed subagent?
- Is the charity's essential information visible and easy to find?
- Does each hidden section have a user-centered reason to be hidden?
- Do mobile and desktop both feel deliberately designed?
- Do the supplied graphics strengthen the composition and communicate meaning?

Resolve violations by simplifying the design, not by adding another container.

## Administration workspace

The user selected a shadcn left navigation sidebar, a primary work area, and a
resizable right inspector/preview. Search and the primary section action belong
in the workspace header. The right panel opens only when relevant content is
selected; closing it restores the full work area. Do not reserve an empty preview
panel while browsing. On phones, use the sidebar drawer and Edit/Preview views
when an inspector is open. The left sidebar is navigation, not a work panel.

The shared image library is a photo-led, responsive masonry surface. Preserve
portrait and landscape proportions; avoid uniform cropped cards or repeated
captions and missing-description warnings beneath every photo. Image metadata,
caption and accessibility editing belong in the selected image's inspector.
Use real checkbox state and a visible outline for selection, with accessible
names on icon controls. Keep the selected image, search, page, and scroll position
when opening and closing details. Reflow as the work area is resized.

## Lazy pagination

Paginate every collection at the API boundary. Load further batches lazily as
people scroll; never ask them to choose page numbers or use Previous/Next page
selectors. This applies to the image library, content lists, account lists,
audit history, and pickers. Keep filters and selections intact during loading.

Photo date and location controls summarize recorded metadata once above the
library. Keep masonry gaps and outer gutters tight. Prefer a date-range slider
with exact date inputs, preserve recorded local time, and keep undated images
available. Never infer GPS/place names or replace absent capture dates with an
upload timestamp. Missing metadata belongs in a concise summary or inspector,
not a repeated warning on every image.

## Realtime collaboration

- Never add refresh or reload buttons anywhere on the website. Keep saved data current automatically through authenticated Phoenix Channels and PubSub. Preserve drafts when remote changes arrive.
- Keep gallery search, date range, slider, filters and actions on one compact row; allow horizontal scrolling on narrow screens.
- Assign each account a persistent presence color. Show who is editing which item. Sidebar presence dots are 4 px circles, anchored at the bottom-right, right-aligned and extending left with even spacing. Deduplicate multiple tabs per person; provide accessible names and activity details, never color alone.

- Field presence uses one continuous 2 px outline outside the input, joined to a bottom-right overlay with a concave left join and continuous right edge. Stack editor names vertically without reserving layout space. Each editor row retains its own account-colored background; only the outer outline follows the most recent editor. Do not layer duplicate input, focus, and presence borders.

- When a person leaves a field, collapse only their name row into a 4 px account-colored dot at the field’s bottom-right. Keep active people expanded, retain inactive identities as recent presence, and treat a rich-text editor and its formatting controls as one field.

- Apply unsaved remote changes directly to untouched fields and the preview. Merge compatible text edits, preserve local caret/selection and text composition, and retain explicit conflicts for overlapping edits. Live receipt is not a saved-state confirmation. Show account-colored remote pointers and text carets; hovering near them reveals the name sliding rightward on a lighter tint of that account color.
