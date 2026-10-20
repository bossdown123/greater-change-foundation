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
with instructions. Collections use numbered pagination and a concise result
range, with pagination omitted when there is only one page.

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

The user selected a shadcn left sidebar with two resizable work panels: the
configuration/details editor in the middle, and the live generated output
preview on the right. Keep this structure. On phones, use the sidebar drawer
and Edit/Preview views so both work areas remain usable. The sidebar is
navigation, not one of the two resizable work panels.
