defmodule Request.Validator.Plug do
  alias Plug.Conn
  alias Ecto.Changeset
  alias Request.Validator
  alias Request.Validator.{DefaultRules, Rules, Rules.Map_}

  import Plug.Conn

  @doc ~S"""
  Init the Request.Validator.Plug with an optional error callback
  and handlers with their corresponding request validator module.
  ```elixir
  plug Request.Validator.Plug,
    register: App.Requests.RegisterRequest,
    on_error: fn conn, errors -> json_resp(conn, "Handle your errors: #{inspect errors}") end
  ```
  """
  def init(opts) when is_map(opts), do: init(Keyword.new(opts))

  def init(opts) do
    opts
    |> Keyword.put_new(:on_error, &Validator.Plug.on_error/2)
  end

  @doc ~S"""
  The default callback to be invoked when there is a param that fails validation.
  """
  def on_error(conn, errors) do
    json_resp(conn, 422, %{message: "Unprocessable entity", errors: errors}) |> halt()
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

    rules =
      cond do
        function_exported?(module, :rules, 1) ->
          module.rules(conn)

        function_exported?(module, :rules, 0) ->
          module.rules()
      end

    errors = collect_errors(conn.params, rules)

    cond do
      not module.authorize(conn) -> unauthorized(conn)
      Enum.empty?(errors) -> conn
      true -> on_error.(conn, errors)
    end
  end

  defp collect_errors(_, %Ecto.Changeset{} = changeset) do
    Changeset.traverse_errors(changeset, fn {key, errors} ->
      Enum.reduce(errors, key, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  defp collect_errors(params, validations) do
    Enum.reduce(validations, %{}, errors_collector(params))
  end

  defp errors_collector(params) do
    fn
      {field, %Rules.Bail{rules: rules}}, acc ->
        value = Map.get(params, to_string(field))

        result =
          Enum.find_value(rules, nil, fn callback ->
            case run_rule(callback, value, field, params) do
              :ok ->
                nil

              a ->
                a
            end
          end)

        case is_binary(result) do
          true -> Map.put(acc, field, [result])
          _ -> acc
        end

      {field, %Map_{attrs: rules}}, acc ->
        value = Map.get(params, to_string(field))

        with %{} = value <- value,
             result <- collect_errors(value, rules),
             {true, _} <- {Enum.empty?(result), result} do
          acc
        else
          nil ->
            Map.put(acc, field, ["This field is expected to be a map."])

          {false, result} ->
            result =
              result
              |> Enum.map(fn {key, val} -> {"#{field}.#{key}", val} end)
              |> Enum.into(%{})

            Map.merge(acc, result)
        end

      {field, vf}, acc ->
        value = Map.get(params, to_string(field))

        case run_rules(vf, value, field, params) do
          {:error, errors} -> Map.put(acc, field, errors)
          _ -> acc
        end
    end
  end

  defp run_rule(callback, value, field, fields) do
    opts = [field: field, fields: fields]
    module = rules_module()

    {callback, args} =
      case callback do
        cb when is_atom(cb) ->
          {cb, [value, opts]}

        {cb, params} ->
          {cb, [value, params, opts]}
      end

    case apply(module, callback, args) do
      :ok -> true
      {:error, msg} -> msg
    end
  end

  defp run_rules(rules, value, field, fields) do
    results =
      Enum.map(rules, fn callback ->
        run_rule(callback, value, field, fields)
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

  defp rules_module, do: Application.get_env(:request_validator, :rules_module, DefaultRules)
end
