defmodule Request.Validator.Helper do
  defmacro with_param(name, callback) do
    quote do
      def unquote(name)(params) do
        func = unquote(callback)
        &(func.(params, &1, &2))
      end
    end
  end

  defmacro define_rule(name, callback) do
    quote do
      def unquote(name)(), do: unquote(callback)
    end
  end

  defmacro validate_request(action, validator, error_callback \\ nil) when is_atom(action) do
    quote do
      plug Request.Validation.Plug, %{
        :on_error => unquote(error_callback),
        unquote(action) => unquote(validator)
      }
    end
  end
end
