defmodule Request.Validator do
  @doc ~S"""
  Get the validation rules that apply to the request.
  """
  @callback rules(Plug.Conn.t()) :: Norm.Core.Schema.t()

  @doc ~S"""
  Determine if the user is authorized to make this request.
  ```elixir
  def authorize(conn) do
    user(conn).is_admin
  end
  ```
  """
  @callback authorize(Plug.Conn.t()) :: boolean()

  defmacro __using__(_) do
    quote do
      use Norm
      import Request.Validator.Rules

      @before_compile Request.Validator
      @behaviour Request.Validator
    end
  end

  defmacro __before_compile__(_) do
    mod = __CALLER__.module

    quote bind_quoted: [mod: mod] do
      if not Module.defines?(mod, {:authorize, 1}) do
        def authorize(_), do: true
      end
    end
  end
end
