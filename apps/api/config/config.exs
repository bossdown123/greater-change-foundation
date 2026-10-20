import Config
config :gcf, ash_domains: [Gcf.Foundation]
config :ash, :allow_forbidden_field_for_relationships_by_default?, true
config :ash, :include_embedded_source_by_default?, false
config :ash, :default_page_type, :keyset
config :ash, :policies, show_policy_breakdowns?: false
config :logger, level: :info
