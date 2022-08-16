defmodule Request.Validator do
  alias Ecto.Changeset
  alias Request.Validator.{DefaultRules, Rules, Rules.Array, Rules.Map_}

  @type validation_result :: :ok | {:error, map()}

  @doc ~S"""
  Get the validation rules that apply to the request.
  """
  @callback rules(Plug.Conn.t()) :: keyword()

  @doc ~S"""
  Determine if the user is authorized to make this request.
  ```elixir
  def authorize(conn) do
    user(conn).is_admin
  end
  ```
  """
  @callback authorize(Plug.Conn.t()) :: boolean()

  @spec validate(module(), map() | keyword(), keyword()) :: validation_result()
  def validate(module, params, opts \\ []) do
    rules =
      cond do
        function_exported?(module, :rules, 1) ->
          module.rules(opts[:conn])

        function_exported?(module, :rules, 0) ->
          module.rules()
      end

    errors = collect_errors(params, rules, opts)

    case Enum.empty?(errors) do
      true ->
        :ok

      false ->
        {:error, errors}
    end
  end

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      import Request.Validator.Rules
      import Request.Validator.Helper

      @before_compile Request.Validator
      @behaviour Request.Validator

      @spec validate(Plug.Conn.t() | map()) :: Request.Validator.validation_result()
      def validate(%Plug.Conn{} = conn) do
        Request.Validator.validate(__MODULE__, conn.params, unquote(opts) ++ [conn: conn])
      end

      def validate(params) when is_map(params) do
        Request.Validator.validate(__MODULE__, params, unquote(opts))
      end

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

  defp collect_errors(_, %Ecto.Changeset{} = changeset, _opts) do
    Changeset.traverse_errors(changeset, fn {key, errors} ->
      Enum.reduce(errors, key, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  defp collect_errors(params, validations, opts) do
    Enum.reduce(validations, %{}, errors_collector(params, opts))
  end

  defp errors_collector(params, opts) do
    fn
      {field, %Rules.Bail{rules: rules}}, acc ->
        value = Map.get(params, to_string(field))

        result =
          Enum.find_value(rules, nil, fn callback ->
            case run_rule(callback, value, field, params, acc, opts) do
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

      {field, %Array{attrs: rules}}, acc ->
        value = Map.get(params, to_string(field))

        with true <- is_list(value),
             result <- Enum.map(value, &collect_errors(&1, rules, opts)) do
          # result <- Enum.reject(result, &Enum.empty?/1) do
          result =
            result
            |> Enum.map(fn val ->
              index = Enum.find_index(result, &(val == &1))

              if Enum.empty?(val) do
                nil
              else
                {index, val}
              end
            end)
            |> Enum.reject(&is_nil/1)
            |> Enum.reduce(%{}, fn {index, errors}, acc ->
              errors =
                errors
                |> Enum.map(fn {key, val} -> {"#{field}.#{index}.#{key}", val} end)
                |> Enum.into(%{})

              Map.merge(acc, errors)
            end)

          Map.merge(acc, result)
        else
          _ ->
            Map.put(acc, field, ["This field is expected to be an array."])
        end

      {field, %Map_{attrs: rules, nullable: nullable}}, acc ->
        value = Map.get(params, to_string(field))

        with %{} <- value,
             result <- collect_errors(value, rules, opts),
             {true, _} <- {Enum.empty?(result), result} do
          acc
        else
          {false, result} ->
            result =
              result
              |> Enum.map(fn {key, val} -> {"#{field}.#{key}", val} end)
              |> Enum.into(%{})

            Map.merge(acc, result)

          val ->
            cond do
              nullable && is_nil(val) ->
                acc

              true ->
                Map.put(acc, field, ["This field is expected to be a map."])
            end
        end

      {field, vf}, acc ->
        value = Map.get(params, to_string(field))

        case run_rules(vf, value, field, params, acc, opts) do
          {:error, errors} -> Map.put(acc, field, errors)
          _ -> acc
        end
    end
  end

  defp run_rule(callback, value, field, fields, errors, opts) do
    module = rules_module(opts)
    opts = [field: field, fields: fields, errors: errors]

    {callback, args} =
      case callback do
        cb when is_atom(cb) ->
          {cb, [value, opts]}

        {cb, params} when is_atom(cb) ->
          {cb, [value, params, opts]}
      end

    case apply(module, :run_rule, [callback] ++ args) do
      :ok -> true
      {:error, msg} -> msg
    end
  end

  defp run_rules(rules, value, field, fields, errors, opts) do
    results =
      Enum.map(rules, fn callback ->
        run_rule(callback, value, field, fields, errors, opts)
      end)
      |> Enum.filter(&is_binary/1)

    if Enum.empty?(results), do: nil, else: {:error, results}
  end

  defp rules_module(opts) do
    from_config = Application.get_env(:request_validator, :rules_module, DefaultRules)
    Keyword.get(opts, :rules_module, from_config)
  end
end
