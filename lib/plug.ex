defmodule Request.Validator.Plug do

  alias Plug.Conn
  alias Ecto.Changeset
  alias Request.Validator
  alias Request.Validator.Rules
  alias Request.Validator.Translations.Messages

  import Norm
  import Plug.Conn

  @doc ~S"""
  Init the Request.Validation.Plug with an optional error callback
  and handlers with their corresponding request validator module.
  ```elixir
  plug Request.Validation.Plug,
    register: App.Requests.RegisterRequest,
    on_error: fn conn, errors -> json_resp(conn, "Handle your errors: #{inspect errors}") end
  ```
  """
  def init([] = opts) do
    opts
    |> Keyword.put_new(:on_error, &Validator.Plug.on_error/2)
  end
  def init(%{} = opts) do
    opts
    |> Map.put_new(:on_error, &Validator.Plug.on_error/2)
  end

  @doc ~S"""
  The default callback to be invoked when there is a param that fails validation.
  """
  def on_error(conn, errors) do
    json_resp(conn, 422, %{message: "Unprocessable entity", errors: errors}) |> halt
  end

  defp unauthorized(conn) do
    json_resp(conn, 401, %{message: "Unauthorized"}) |> halt
  end

  @doc ~S"""
  Performs validations on `conn.params`
  If all validations are successful returns the connection struct
  Otherwise returns an error map in the following structure: `%{param: ["some error", ...]}`
  Will call the given `on_error` callback in case some validation failed
  """
  def call(conn, opts) do
    with action <- Map.get(conn.private, :phoenix_action),
        request_validator <- get_validator(opts, action) do
      case request_validator do
        nil -> conn
        _ -> validate(Conn.fetch_query_params(conn), request_validator, opts[:on_error])
      end
    end
  end

  defp get_validator(opt, key) when is_map(opt), do: Map.get(opt, key)
  defp get_validator(opt, key) when is_list(opt), do: Keyword.get(opt, key)

  defp validate(conn, module, on_error) do
    module = load_module(module)
    rules = if function_exported?(module, :rules, 1), do: module.rules(conn), else: module
    errors = collect_errors(conn, rules)

    cond do
      not module.authorize(conn) -> unauthorized(conn)
      Enum.empty?(errors) -> conn
      true -> on_error.(conn, errors)
    end
  end

  defp collect_errors(conn, %Norm.Core.Schema{}=spec),
    do: norm_errors(conn.params, conform(conn.params, spec))
  defp collect_errors(conn, %Norm.Core.Selection{}=spec),
    do: norm_errors(conn.params, conform(conn.params, spec))
  defp collect_errors(_, %Ecto.Changeset{} = changeset) do
    Changeset.traverse_errors(changeset, fn ({key, errors}) ->
      Enum.reduce(errors, key, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
  defp collect_errors(conn, validations) do
    Enum.reduce(validations, %{}, errors_collector(conn))
  end

  defp errors_collector(conn) do
    fn {field, vf}, acc ->
      value = Map.get(conn.params, Atom.to_string(field))

      case run_rules(field, vf, value, conn.params) do
        {:error, rules} -> Map.put(acc, field, rules)
        _ -> acc
      end
    end
  end

  defp format_rule(rule) do
    case rule do
      {_method, _opts} -> rule
      _ -> {rule, nil}
    end
  end

  defp run_rules(field, rules, value, fields) do
    results = Enum.map(rules, fn rule ->
      {method, params} = format_rule(rule)
      rules_mod = get_rules_module()
      opts = [value, params, fields]
      args = get_args(rules_mod, method, opts)

      callback = fn (mod, method, args) ->
        if apply(mod, method, args) do
          nil
        else
          translator().get_message(method, field, {value, params})
        end
      end

      case args do
        nil -> raise ArgumentError, message: "invalid validation rule [#{method}] provided"
        _ -> callback.(rules_mod, method, args)
      end
    end)
    |> Enum.filter(&(!!&1))

    if Enum.empty?(results), do: nil, else: {:error, results}
  end

  defp get_args(mod, method, opts) do
    cond do
      function_exported?(mod, method, 3) -> opts
      function_exported?(mod, method, 2) ->
        [value, params, _] = opts
        [value, params]
      true -> nil
    end
  end

  defp parse_norm_spec(spec) do
    case Regex.compile(spec) do
      {:ok, _regex} ->
        [spec, []]
      {:error, err} ->
        [spec, [err]]
    end
  end

  defp norm_errors(_, {:ok, _}), do: []
  defp norm_errors(fields, {:error, inputs}) do
    Enum.reduce(inputs, %{}, fn %{path: path, spec: spec}, acc ->
      field = hd(path)
      [rule, params] = parse_norm_spec(spec)
      msg = translator().get_message(rule, field, {params, fields})
      Map.put(acc, field, [msg])
    end)
  end

  defp json_resp(conn, status, body) do
    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(status, json_library().encode_to_iodata!(body))
  end

  defp json_library do
    Application.get_env(:request_validator, :json_library, Jason)
  end

  defp translator do
    Application.get_env(:request_validator, :translator, Messages)
    |> load_module()
  end

  defp get_rules_module do
    Application.get_env(:request_validator, :rules, Rules)
    |> load_module()
  end

  defp load_module(module) do
    case Code.ensure_loaded(module) do
      {:module, mod} -> mod
      {:error, reason} -> raise ArgumentError, "Could not load #{module}, reason: #{reason}"
    end
  end
end
