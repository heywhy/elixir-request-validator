defmodule RequestValidatorTest.EctoRulesRequest do
  use Request.Validator
  use Ecto.Schema

  import Ecto.Changeset

  embedded_schema do
    field(:name, :string)
    field(:email, :string)
    field(:age, :integer)
    field(:password, :string)
  end

  @doc false
  defp changeset(contact, attrs) do
    contact
    |> cast(attrs, [:name, :email, :age, :password])
    |> validate_required([:name, :email, :age, :password])
    |> validate_number(:age, less_than_or_equal_to: 32)
  end

  @impl Request.Validator
  def rules(conn) do
    %RequestValidatorTest.EctoRulesRequest{}
    |> changeset(conn.params)
  end

  @impl Request.Validator
  @spec authorize(Plug.Conn.t()) :: boolean()
  def authorize(_), do: true
end
