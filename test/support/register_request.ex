defmodule RequestValidatorTest.RegisterRequest do
  use Request.Validator

  @behaviour Request.Validator

  @impl Request.Validator
  def rules(_) do
    %{
      email: [is_required(), is_email()],
      name: [is_required(), is_string()],
      age: [is_required(), is_numeric(), is_min(2), is_max(32)],
      password: [is_required(), is_string(), is_confirmed()],
    }
  end

  @impl Request.Validator
  @spec authorize(Plug.Conn.t())::boolean()
  def authorize(_), do: true
end
