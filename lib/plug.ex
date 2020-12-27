defmodule Request.Validator.Plug do
  alias Plug.Conn
  alias Ecto.Changeset
  alias Request.Validator

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
      value = Map.get(conn.params, to_string(field))

      case run_rules(vf, value, field, conn.params) do
        {:error, rules} -> Map.put(acc, field, rules)
        _ -> acc
      end
    end
  end

  defp run_rules(rules, value, field, fields) do
    results = Enum.map(rules, fn callback ->
      extra = [field: field, fields: fields]
      case apply(callback, [value, extra]) do
        :ok -> true
        {:error, msg} -> msg
      end
    end)
    |> Enum.filter(&is_binary/1)

    if Enum.empty?(results), do: nil, else: {:error, results}
  end

  defp json_resp(conn, status, body) do
    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(status, json_library().encode_to_iodata!(body))
  end

  defp json_library do
    Application.get_env(:request_validator, :json_library, Jason)
  end

  defp load_module(module) do
    case Code.ensure_loaded(module) do
      {:module, mod} -> mod
      {:error, reason} -> raise ArgumentError, "Could not load #{module}, reason: #{reason}"
    end
  end
end
