defmodule RequestValidatorTest.StrictRequest do
  use Request.Validator, strict: true

  import Request.Validator.Rulex

  @impl Request.Validator
  def rules(_), do: %{"email" => [email()]}

  @impl Request.Validator
  def authorize(_), do: true
end
