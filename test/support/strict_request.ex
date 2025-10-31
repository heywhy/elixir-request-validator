defmodule RequestValidatorTest.StrictRequest do
  use Request.Validator, strict?: true

  import Request.Validator.Rules

  @impl Request.Validator
  def rules(_), do: %{"email" => [email()], "docs.*.type" => [string()]}
end
