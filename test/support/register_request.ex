defmodule RequestValidatorTest.RegisterRequest do
  use Request.Validator

  import Request.Validator.Rules

  @impl Request.Validator
  def rules(_) do
    # TODO: update rules
    %{
      "email" => ~V[required|email],
      "name" => ~V[required|string],
      "password" => ~V[required|string|confirmed],
      "gender" => ~V[required|allowed:male,female],
      "age" => ~V[required|numeric|min:2|max:32],
      "year" => ~V[required|numeric|min:1990|max:2000],
      # "mother_age" => ~V[required|numeric|gt:age],
      # "address" => ~V[required|map],
      "address.line1" => ~V[required|string],
      "address.line2" => ~V[string],
      "address.city" => ~V[required|string],
      "address.state" => ~V[required_if:address.country,NG|string],
      "address.country" => ~V[required|string],
      "documents" => ~V[required],
      "documents.*.file" => ~V[string],
      "documents.*.name" => ~V[required|string],
      "documents.*.type" => ~V[required|allowed:certificate,memart],
      "documents.*.tags" => ~V[required],
      "documents.*.tags.*" => ~V[string]
    }
  end

  @impl Request.Validator
  def authorize?(_), do: true

  def unique_email?("test@gmail.com", _opts), do: true
  def unique_email?(_val, _opts), do: false
end
