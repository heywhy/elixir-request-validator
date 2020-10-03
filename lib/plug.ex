defmodule Request.Validation.Plug do

  alias Plug.Conn
  alias Request.Validation
  alias Request.Validator.Rules

  import Plug.Conn

  @doc ~S"""
  Init the Plug.Validator with an error callback
  ```elixir
  plug Plug.validator, on_error: fn conn, errors -> IO.puts("Handle your errors: #{inspect errors}") end
  ```
  """
  def init([] = opts) do
    opts
    |> Keyword.put_new(:on_error, &Validation.Plug.on_error/2)
  end
  def init(%{} = opts) do
    opts
    |> Map.put_new(:on_error, &Validation.Plug.on_error/2)
  end

  def on_error(conn, errors) do
    json_resp(conn, 422, %{message: "Unprocessable entity", errors: errors})
  end

  @doc ~S"""
  Performs validations on `conn.params`
  If all validations are successful returns an empty map
  Otherwise returns an error map in the following structure: `%{param: "some error",....}`
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
    rules = if function_exported?(module, :rules, 1), do: module.rules(conn), else: module
    errors = collect_errors(conn, rules)

    if Enum.empty?(errors) do
      conn
    else
      on_error.(conn, errors) |> halt
    end
  end

  defp collect_errors(conn, validations) do
    Enum.reduce(validations, %{}, errors_collector(conn))
  end

  defp errors_collector(conn) do
    fn {field, vf}, acc ->
      value = Map.get(conn.params, Atom.to_string(field))

      case run_rules(field, vf, value) do
        {:error, rules} -> Map.put(acc, field, rules)
        _ -> acc
      end
    end
  end

  def format_rule(rule) do
    cond do
      is_tuple(rule) -> {_method, _opts} = rule
      true -> {rule, nil}
    end
  end

  defp run_rules(field, rules, value) do
    results = Enum.map(rules, fn rule ->
      {method, opts} = format_rule(rule)
      case function_exported?(Rules, method, 3) do
        true ->
          result = apply(Rules, method, [value, opts, field])
          if is_binary(result), do: result, else: nil

        _ -> raise ArgumentError, message: "invalid validation rule [#{method}] provided"
      end
    end)
    |> Enum.filter(&(!!&1))

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
end
