defmodule RequestValidatorTest.StrictRequest do
  use Request.Validator, strict: true

  @impl Request.Validator
  def rules(_) do
    [
      email: [:email]
    ]
  end

  @impl Request.Validator
  def authorize(_), do: true
end
