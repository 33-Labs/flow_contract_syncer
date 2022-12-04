defmodule FlowContractSyncer.Repo.Migrations.AddContractCodeIndex do
  use Ecto.Migration

  def up do
    # For full text search
    execute("CREATE EXTENSION pg_trgm")

    # execute("CREATE INDEX IF NOT EXISTS contracts_code_index ON contracts USING GIN (to_tsvector('english', uuid || ' ' || coalesce(code, ' ')))")
    execute(
      "CREATE INDEX IF NOT EXISTS contracts_code_trgm_index ON contracts USING GIN (code gin_trgm_ops)"
    )

    execute(
      "CREATE INDEX IF NOT EXISTS contracts_uuid_trgm_index ON contracts USING GIN (uuid gin_trgm_ops)"
    )
  end

  def down do
    execute("DROP INDEX contracts_code_trgm_index")
    execute("DROP INDEX contracts_uuid_trgm_index")
    execute("DROP EXTENSION pg_trgm")
  end
end
