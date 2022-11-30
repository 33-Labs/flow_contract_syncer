defmodule FlowContractSyncer.Repo.Migrations.AddContractCodeIndex do
  use Ecto.Migration

  def up do
    # For full text search
    execute("CREATE EXTENSION pg_trgm")
    execute("CREATE INDEX IF NOT EXISTS contracts_code_index ON contracts USING GIN (to_tsvector('english', uuid || ' ' || coalesce(code, ' ')))")
  end

  def down do
    execute("DROP INDEX contracts_code_index")
    execute("DROP EXTENSION pg_trgm")
  end
end
