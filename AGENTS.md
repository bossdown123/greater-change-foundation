# Greater Change Foundation

- Commit frequently after meaningful, verified checkpoints.
- Keep the public page limited to “GCF UNDER DEVELOPMENT” until requested otherwise.
- Backend: Elixir and Ash; frontend: React TSX, Tailwind CSS, shadcn/ui.
- Database: Turso/libSQL; all schema changes use Sqitch deploy/revert/verify scripts.
- Keep credentials, database files, backups, and deployment state out of Git.
- Prefer Docker Compose for reproducible tooling and deployment.
- Keep the GitHub Project empty until charity members add their own work.

## Website design

Read and follow [DESIGN_PRINCIPLES.md](DESIGN_PRINCIPLES.md) before making website
design or interaction decisions. Its requirements include:

- Open, content-led layouts; cards and bordered containers are not the default.
- Shallow semantic markup with minimal wrappers. Strongly discourage cards
  inside cards and avoid repeated container nesting.
- A dedicated subagent must choose UX primitives for new or materially changed
  interactions. Give it only an abstract use case and necessary context, not a
  proposed component, existing markup, or preferred layout.
- Progressive information reveal through appropriate disclosures, sidebars,
  dropdowns, or tabs, while keeping most charity information visible by default.
- Joint mobile and desktop design, with high responsiveness and accessible
  interactions on both.
- Creative, purposeful use of supplied graphics.

## Database normalization

- Every persistent database schema must meet **third normal form (3NF) at a minimum**. Document keys, functional dependencies, and intentional exceptions before accepting a migration.
- Strive for **5NF and 6NF** where independent relationships, join dependencies, temporal facts, or sparsity warrant the additional decomposition. Review the applicable meaning of **7NF** when a design calls for it; 7NF has no single universally accepted definition, so state the definition and demonstrate its benefit rather than claiming it by name alone.
- Use relational tables and foreign keys for repeatable facts and relationships. Do not put event dates, locations, gallery assignments, custom-field values, or newsletter event selections in JSON blobs or comma-separated columns.
- Store each fact once; derive displays and calculated values. Preserve explicit ordering through relationship attributes, and enforce applicable uniqueness, type, and referential constraints.
- A higher normal form must improve integrity for the actual data; avoid speculative decomposition that adds joins without resolving a real dependency.
- All schema changes require Sqitch deploy, revert, and verify scripts plus a normalization review.
