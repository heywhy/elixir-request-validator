defmodule RequestValidatorTest.RegisterRequest do
  use Request.Validator

  @behaviour Request.Validator

  @impl Request.Validator
  def rules(_) do
    %{
      email: [:required, :email],
      name: [:required, :string],
      password: [:required, :string],
      age: [:required, :numeric, {:max, 32}]
    }
  end

  @impl Request.Validator
  @spec authorize(Plug.Conn.t())::boolean()
  def authorize(_), do: true
end
