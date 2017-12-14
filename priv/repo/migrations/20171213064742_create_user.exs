defmodule Example.Repo.Migrations.CreateUser do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :name, :string
      add :public_key, :string
      add :private_key, :string
    end
  end
end
