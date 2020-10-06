defmodule Request.Validator.Rules do
  use Request.Validator.DefaultRules

  defmacro __using__(_) do
    quote do
      use Request.Validator.DefaultRules
    end
  end
end
