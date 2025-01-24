defmodule Request.Validator do
  alias Ecto.Changeset
  alias Request.Validator.Fields
  alias Request.Validator.Utils

  @type validation_result :: :ok | {:error, map()}

  @doc ~S"""
  Get the validation rules that apply to the request.
  """
  @callback rules(Plug.Conn.t()) :: map() | Changeset.t()

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

    errors =
      params
      |> Fields.new()
      |> collect_errors(rules, set_strict_default(opts))

    case Enum.empty?(errors) do
      true -> :ok
      false -> {:error, errors}
    end
  end

  @doc """
  ## Examples

  iex> import Request.Validator
  iex> import Request.Validator.Rules
  iex> rules = ~V[required|email:format]
  iex> [%{validator: _}, rule] = rules
  iex> is_function(rule, 2)
  true
  """
  defmacro sigil_V({:<<>>, _, [rules]}, []) do
    list =
      rules
      |> String.split("|")
      |> Enum.reverse()
      |> Enum.map(fn rule ->
        {rule, args} =
          case String.split(rule, ":", parts: 2) do
            [rule] -> {rule, nil}
            parts -> List.to_tuple(parts)
          end

        args =
          case args do
            nil -> nil
            args when is_binary(args) -> args |> String.split(",")
          end

        {Utils.to_atom(rule), args}
      end)
      |> Enum.reduce([], fn rule, acc ->
        expr = rule_to_expr(rule)

        Enum.concat([expr], acc)
      end)

    quote do: unquote(list)
  end

  defp rule_to_expr({rule, nil}) do
    quote do: unquote(rule)()
  end

  defp rule_to_expr({rule, arg}) do
    arg = Macro.escape(arg)

    quote do: unquote(rule)(unquote(arg))
  end

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      import Request.Validator, only: [sigil_V: 2]

      @before_compile Request.Validator
      @behaviour Request.Validator

      @spec validate(Plug.Conn.t() | map()) :: Request.Validator.validation_result()
      def validate(%Plug.Conn{} = conn) do
        params = conn.query_params |> Map.merge(conn.body_params) |> Map.merge(conn.path_params)
        Request.Validator.validate(__MODULE__, params, unquote(opts) ++ [conn: conn])
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

  defp collect_errors(fields, validations, opts) do
    validations = maybe_expand_validations(validations, fields)

    case undeclared_fields(fields, validations, opts) do
      [] -> Enum.reduce(validations, %{}, errors_collector(fields, opts))
      fields -> fields |> Enum.map(&{&1, ["This field is unknown."]}) |> Map.new()
    end
  end

  defp maybe_expand_validations(validations, fields) do
    Enum.reduce(validations, %{}, fn {key, rules}, acc ->
      collapse(key, rules, fields, acc)
    end)
  end

  defp collapse(key, rules, fields, acc) when is_binary(key) do
    case String.contains?(key, "*") do
      false -> Map.put(acc, key, rules)
      true -> array_map(key, rules, fields, acc)
    end
  end

  defp array_map(key, rules, fields, acc) when is_binary(key) do
    key
    |> String.split("*", parts: 2)
    |> Enum.map(&String.trim(&1, "."))
    |> array_map(rules, fields, acc)
  end

  defp array_map([h, t], rules, fields, acc) do
    trim_fn = &String.trim(&1, ".")

    result =
      case fields[h] do
        [_ | _] = data ->
          data
          |> Enum.count()
          |> then(&Range.new(0, &1 - 1))
          |> Enum.reduce(%{}, &(trim_fn.("#{h}.#{&1}.#{t}") |> collapse(rules, fields, &2)))

        value when value == [] or is_nil(value) ->
          %{}
      end

    Map.merge(acc, result)
  end

  defp errors_collector(fields, opts) do
    fn
      {field, vf}, acc ->
        value = fields[field]

        case run_rules(vf, value, field, fields, acc, opts) do
          [] -> acc
          [_ | _] = errors -> Map.put(acc, field, errors)
        end
    end
  end

  defp run_rules(rules, value, field, fields, _errors, _opts) do
    rules
    |> Enum.map(&call_rule(&1, field, value, fields))
    |> Enum.reject(&match?(:ok, &1))
    |> Enum.map(&elem(&1, 1))
  end

  defp call_rule(fun, _, nil, _fields) when is_function(fun), do: :ok

  defp call_rule(fun, field, value, fields) when is_function(fun) do
    call_func(fun, field, value, fields)
  end

  defp call_rule(%{implicit?: true, validator: fun}, field, value, fields) do
    call_func(fun, field, value, fields)
  end

  defp call_func(fun, field, value, fields) do
    case fun do
      fun when is_function(fun, 2) -> fun.(field, value)
      fun when is_function(fun, 3) -> fun.(field, value, fields)
    end
  end

  defp set_strict_default(opts) do
    Keyword.put_new(opts, :strict, Application.get_env(:request_validator, :strict, false))
  end

  defp undeclared_fields(fields, rules, opts) do
    opts
    |> Keyword.get(:strict, false)
    |> case do
      false ->
        []

      true ->
        rule_fields = MapSet.new(rules, &elem(&1, 0))

        fields.data
        |> MapSet.new(&elem(&1, 0))
        |> MapSet.difference(rule_fields)
        |> MapSet.to_list()
    end
  end
end
