defmodule Request.Validator do
  alias Request.Validator.Fields
  alias Request.Validator.Utils

  @type validation_result :: :ok | {:error, map()}

  @doc ~S"""
  Get the validation rules that apply to the request.
  """
  @callback rules(Plug.Conn.t()) :: map()

  @doc ~S"""
  Determine if the user is authorized to make this request.
  ```elixir
  def authorize?(conn) do
    user(conn).is_admin
  end
  ```
  """
  @callback authorize?(Plug.Conn.t()) :: boolean()

  @spec validate(module() | map(), map(), keyword()) :: validation_result()
  def validate(module, params, opts \\ [])

  def validate(module, params, opts) when is_atom(module) do
    rules = module.rules(opts[:conn])
    opts = module.__validator_opts__() |> Keyword.merge(opts)

    validate(rules, params, opts)
  end

  def validate(rules, params, opts) when is_map(rules) do
    opts = set_default_opts(opts)

    errors =
      params
      |> Fields.new()
      |> collect_errors(rules, opts)

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
  iex> [{required, []}, {email, ["format"]}] = rules
  iex> is_function(required, 0)
  true
  iex> match?(%{implicit?: true}, required())
  true
  iex> is_function(email, 1)
  true
  """
  defmacro sigil_V({:<<>>, _, [rules]}, []) do
    env = __CALLER__

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
        rule = Tuple.insert_at(rule, 2, env)
        expr = rule_to_expr(rule)

        Enum.concat([expr], acc)
      end)

    quote do: unquote(list)
  end

  defp find_fun_owner(env, fun, arity) do
    case Macro.Env.lookup_import(env, {fun, arity}) do
      [] -> env.module
      [{ctx, module}] when ctx in ~w[function macro]a -> module
    end
  end

  defp method_to_capture_ast(module, method, args) do
    arity = Enum.count(args)

    {{:&, [], [{:/, [], [{method, [], module}, arity]}]}, args}
  end

  defp rule_to_expr({rule, nil, env}) do
    module = find_fun_owner(env, rule, 0)
    expr = method_to_capture_ast(module, rule, [])

    quote do: unquote(expr)
  end

  defp rule_to_expr({rule, arg, env}) do
    arg = convert_params(arg)
    arg = Macro.escape(arg)
    num = Enum.count(arg)
    module = find_fun_owner(env, rule, num)

    args =
      case function_exported?(module, rule, num) do
        true -> arg
        false -> [arg]
      end

    expr = method_to_capture_ast(module, rule, args)

    quote do: unquote(expr)
  end

  defp convert_params(arg), do: Enum.map(arg, &maybe_convert_to_number/1)

  defp maybe_convert_to_number(param) do
    number_converters = [&Integer.parse/1, &Float.parse/1]

    Enum.reduce_while(number_converters, param, fn fun, acc ->
      case fun.(acc) do
        {num, ""} -> {:halt, num}
        _ -> {:cont, acc}
      end
    end)
  end

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      import Request.Validator, only: [sigil_V: 2]

      @validator_opts opts
      @before_compile Request.Validator
      @behaviour Request.Validator

      @doc false
      def __validator_opts__, do: unquote(opts)
    end
  end

  defmacro __before_compile__(_) do
    mod = __CALLER__.module

    quote bind_quoted: [mod: mod] do
      if not Module.defines?(mod, {:authorize?, 1}) do
        def authorize?(_), do: true
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

  defp expand_data(data) do
    Enum.reduce(data, %{}, fn {k, v}, acc ->
      do_expand_data(k, v, acc)
    end)
  end

  defp do_expand_data(prefix, value, acc) when is_map(value) do
    Enum.reduce(value, acc, fn {k, v}, acc ->
      do_expand_data("#{prefix}.#{k}", v, acc)
    end)
  end

  defp do_expand_data(prefix, value, acc) when is_list(value) do
    count = Enum.count(value)
    range = Range.new(0, count - 1)

    Enum.reduce(range, acc, fn index, acc ->
      el = Enum.at(value, index)

      do_expand_data("#{prefix}.#{index}", el, acc)
    end)
  end

  defp do_expand_data(key, value, acc), do: Map.put(acc, key, value)

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

        value when value == [] or not is_list(value) ->
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

  defp call_rule(%{implicit?: true, validator: fun}, field, value, fields) do
    call_func(fun, field, value, fields)
  end

  defp call_rule({fun, args}, field, value, fields) when is_function(fun) and is_list(args) do
    fun
    |> apply(args)
    |> call_rule(field, value, fields)
  end

  defp call_rule(_fun, _field, nil, _fields), do: :ok

  defp call_rule(fun, field, value, fields) when is_function(fun) do
    call_func(fun, field, value, fields)
  end

  defp call_func(fun, field, value, fields) do
    case fun do
      fun when is_function(fun, 2) -> fun.(field, value)
      fun when is_function(fun, 3) -> fun.(field, value, fields)
    end
  end

  defp set_default_opts(opts) do
    Keyword.put_new_lazy(opts, :strict?, fn ->
      Application.get_env(:request_validator, :strict?, false)
    end)
  end

  defp undeclared_fields(fields, rules, opts) do
    opts
    |> Keyword.fetch!(:strict?)
    |> case do
      false ->
        []

      true ->
        rule_fields = MapSet.new(rules, &elem(&1, 0))
        expanded_data = expand_data(fields.data)

        expanded_data
        |> MapSet.new(&elem(&1, 0))
        |> MapSet.difference(rule_fields)
        |> MapSet.to_list()
    end
  end
end
