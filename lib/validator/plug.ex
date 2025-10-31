defmodule Request.Validator.Plug do
  import Plug.Conn

  alias Plug.Conn
  alias Plug.Router
  alias Request.Validator

  @behaviour Plug

  defmacro __using__(_) do
    quote do
      @on_definition Request.Validator.Plug
      @before_compile Request.Validator.Plug

      Module.register_attribute(__MODULE__, :validate, [])
      Module.register_attribute(__MODULE__, :validators, accumulate: true)

      plug(Request.Validator.Plug, __MODULE__)
    end
  end

  @doc false
  def __on_definition__(
        env,
        :defp,
        :do_match,
        [{:conn, [], Router} | _] = args,
        _guards,
        _body
      ) do
    path =
      case Enum.at(args, 2) do
        {:_path, [], nil} ->
          nil

        path when is_list(path) ->
          Enum.map_join(path, fn
            sub when is_binary(sub) -> "/#{sub}"
            {sub, [], nil} when is_atom(sub) -> "/#{inspect(sub)}"
          end)
      end

    validator = Module.get_attribute(env.module, :validate)

    store_in_module(env.module, path, validator)
  end

  def __on_definition__(env, :def, name, _args, _guards, _body) do
    validator = Module.get_attribute(env.module, :validate)

    store_in_module(env.module, name, validator)
  end

  def __on_definition__(_env, _kind, _name, _args, _guards, _body), do: :ok

  defp store_in_module(module, name, validator) do
    Module.delete_attribute(module, :validate)
    Module.put_attribute(module, :validators, {name, Macro.escape(validator)})
  end

  defmacro __before_compile__(env) do
    validators =
      env.module
      |> Module.get_attribute(:validators, [])
      |> Enum.reject(fn {_action, mod} -> is_nil(mod) end)

    quote do
      def __validators__, do: unquote(validators)
    end
  end

  @doc ~S"""
  Init the Request.Validator.Plug with an optional error callback

  and handlers with their corresponding request validator module.
  ```elixir
  plug Request.Validator.Plug,
    register: App.Requests.RegisterRequest,
    on_error: fn conn, errors -> json_resp(conn, "Handle your errors: #{inspect errors}") end
  ```
  """
  @impl Plug
  def init(opts) when is_list(opts) do
    {on_error, spec} =
      opts
      |> Keyword.put_new(:on_error, &__MODULE__.on_error/2)
      |> Keyword.pop(:on_error)

    {spec, on_error}
  end

  def init(mod) when is_atom(mod) do
    {&mod.__validators__/0, &__MODULE__.on_error/2}
  end

  @doc ~S"""
  The default callback to be invoked when there is a param that fails validation.
  """
  def on_error(conn, errors) do
    json_resp(conn, 422, %{message: "Unprocessable entity", errors: errors}) |> halt()
  end

  defp unauthorized(conn) do
    json_resp(conn, 403, %{message: "Forbidden"}) |> halt
  end

  @doc ~S"""
  Performs validations on `conn.params`
  If all validations are successful returns the connection struct
  Otherwise returns an error map in the following structure: `%{param: ["some error", ...]}`
  Will call the given `on_error` callback in case some validation failed
  """
  @impl Plug
  def call(%Conn{} = conn, {fun, on_error}) when is_function(fun) do
    call(conn, {fun.(), on_error})
  end

  def call(%Conn{private: %{phoenix_action: _}} = conn, {spec, on_error}) do
    %Conn{private: %{phoenix_action: phoenix_action}} = conn

    case spec[phoenix_action] do
      nil -> conn
      rules_or_module -> do_call(conn, rules_or_module, on_error)
    end
  end

  def call(%Conn{} = conn, {spec, on_error}) do
    matched = Router.match_path(conn)

    case Enum.find(spec, &match?({^matched, _}, &1)) do
      nil -> conn
      {^matched, rules_or_module} -> do_call(conn, rules_or_module, on_error)
    end
  end

  defp do_call(conn, module, on_error) when is_atom(module) do
    case module.authorize?(conn) do
      false ->
        unauthorized(conn)

      true ->
        rules = module.rules(conn)

        do_call(conn, rules, on_error)
    end
  end

  defp do_call(conn, rules, on_error) when is_map(rules) and is_function(on_error, 2) do
    params = conn.query_params |> Map.merge(conn.body_params) |> Map.merge(conn.path_params)

    case Validator.validate(rules, params) do
      :ok ->
        conn

      {:error, errors} when is_map(errors) ->
        on_error.(conn, errors)
    end
  end

  defp json_resp(conn, status, body) do
    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(status, json_library().encode_to_iodata!(body))
  end

  defp json_library do
    Application.get_env(:request_validator, :json_library, Jason)
  end
end
