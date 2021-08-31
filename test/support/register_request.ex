defmodule RequestValidatorTest.RegisterRequest do
  use Request.Validator

  @impl Request.Validator
  def rules(_) do
    [
      email: required(:email),
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
        )
      # documents: array(
      #   name: required(:string),
      #   file: ~w[required file]a,
      #   type: [:required, {:in, ~w[cac_certificate memart]}]
      # )
    ]
  end

  @impl Request.Validator
  def authorize(_), do: true
end
