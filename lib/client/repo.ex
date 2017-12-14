defmodule Example.User do
  use Ecto.Schema

  schema "users" do
    field :name, :string
    field :public_key, :string
    field :private_key, :string
  end
end

defmodule Example.Repo do
  use Ecto.Repo, otp_app: :example
end
