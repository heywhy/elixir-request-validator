defmodule RequestValidatorTest.RegisterRequest do
  use Request.Validator

  @impl Request.Validator
  def rules(_) do
    [
      email: [:required, :email, unique(&unique_email?/2)],
      name: required(:string),
      password: required(~w[string confirmed]a),
      gender: required(in_list(~w[male female])),
      age: required([:numeric, min(2), max(32)]),
      year: [:required, :numeric, min(1990), max(2000)],
      mother_age: [:required, :numeric, gt(:age)],
      address:
        map(
          line1: required(:string),
          line2: ~w[string]a,
          country: required(:string)
        ),
      documents:
        array(
          file: [:string],
          name: required(:string),
          type: [:required, {:in_list, ~w[certificate memart]}]
        )
    ]
  end

  @impl Request.Validator
  def authorize(_), do: true

  def unique_email?("test@gmail.com", _opts), do: true
  def unique_email?(_val, _opts), do: false
end
