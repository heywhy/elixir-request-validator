defmodule Request.Validation.RegisterRequest do

  @behaviour Request.Validator

  @impl Request.Validator
  def rules(_) do
    %{
      email: [:required, :email],
      name: [:required, :string],
      age: [:required, :numeric]
    }
  end

  @impl Request.Validator
  @spec authorize(Plug.Conn.t())::boolean()
  def authorize(_), do: true
end
