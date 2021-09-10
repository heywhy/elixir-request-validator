defmodule Request.Validator.Rules do
  defmodule Bail do
    defstruct rules: []

    @type t :: %__MODULE__{rules: list(atom() | tuple())}
  end

  defmodule Map_ do
    defstruct attrs: []

    @type t :: %__MODULE__{attrs: maybe_improper_list()}
  end

  defmodule Array do
    defstruct attrs: []
    @type t :: %__MODULE__{attrs: list(atom() | tuple())}
  end

  @spec bail(list(atom() | tuple())) :: Request.Validator.Rules.Bail.t()
  def bail(rules), do: %__MODULE__.Bail{rules: rules}

  @spec map(maybe_improper_list()) :: Request.Validator.Rules.Map_.t()
  def map(attrs), do: %__MODULE__.Map_{attrs: attrs}

  @spec array(maybe_improper_list) :: Request.Validator.Rules.Array.t()
  def array(attrs) when is_list(attrs), do: %__MODULE__.Array{attrs: attrs}

  defmacro __using__(_opts) do
    quote location: :keep do
      @implicit_rules ~w[required]a

      def email(value, opts \\ [])

      def email(value, _) when is_nil(value) or not is_binary(value),
        do: {:error, "This field must be a valid email address."}

      def email(value, _) do
        validate(EmailChecker.valid?(value || ""), "This field must be a valid email address.")
      end

      def required(value, opts \\ [])

      def required(value, _) when is_boolean(value), do: :ok

      def required(value, _) do
        result =
          case value_size(value) do
            nil ->
              false

            length ->
              length > 0
          end

        validate(result, "This field is required.")
      end

      def string(value, opts \\ [])

      def string(value, _) do
        validate(is_binary(value), "This field must be a string.")
      end

      def numeric(value, opts \\ [])

      def numeric(value, _) do
        validate(is_number(value), "This field must be a number.")
      end

      def map(value, opts \\ [])

      def map(value, _) do
        validate(is_map(value), "This field is expected to be a map.")
      end

      def in_list(value, list, opts \\ [])

      def in_list(value, list, _) do
        validate(Enum.member?(list, value), "This field is invalid.")
      end

      def max(value, boundary, opts \\ [])

      def max(value, boundary, _opts) do
        msg =
          cond do
            is_binary(value) ->
              "This field must be less than or equal #{boundary} characters."

            is_list(value) ->
              "This field must be less than or equal #{boundary} items."

            true ->
              "This field must be less than or equal #{boundary}."
          end

        validate(value_size(value) <= boundary, msg)
      end

      def min(value, boundary, opts \\ [])

      def min(value, boundary, _opts) do
        msg =
          cond do
            is_binary(value) ->
              "This field must be at least #{boundary} characters."

            is_list(value) ->
              "This field must be at least #{boundary} items."

            true ->
              "This field must be at least #{boundary}."
          end

        validate(value_size(value) >= boundary, msg)
      end

      def gt(value, boundary, opts) do
        other_field =
          opts
          |> Keyword.get(:fields)
          |> Map.get(to_string(boundary))

        case same_type(value, other_field) do
          true ->
            msg =
              cond do
                is_list(value) ->
                  "This field must have more than #{value_size(other_field)} items."

                is_binary(value) ->
                  "This field must have more than #{value_size(other_field)} characters."

                true ->
                  "This field must be greater than #{value_size(other_field)}."
              end

            validate(value_size(value) > value_size(other_field), msg)

          false ->
            {:error, "This field and #{boundary} has to be of same type."}
        end
      end

      def lt(value, boundary, opts) do
        other_field =
          opts
          |> Keyword.get(:fields)
          |> Map.get(to_string(boundary))

        case same_type(value, other_field) do
          true ->
            msg =
              cond do
                is_list(value) ->
                  "This field must have less than #{value_size(other_field)} items."

                is_binary(value) ->
                  "This field must have less than #{value_size(other_field)} characters."

                true ->
                  "This field must be less than #{value_size(other_field)}."
              end

            validate(value_size(value) < value_size(other_field), msg)

          false ->
            {:error, "This field and #{boundary} has to be of same type."}
        end
      end

      def confirmed(value, field: field, fields: fields) do
        path = "#{field}_confirmation"

        validate(value == fields[path], "This field confirmation does not match.")
      end

      def size(value, boundary, opts \\ [])

      def size(value, boundary, _) do
        msg =
          cond do
            is_list(value) ->
              "This field must contain #{boundary} items."

            is_binary(value) ->
              "This field must be #{boundary} characters."

            true ->
              "This field must be #{boundary}."
          end

        validate(value_size(value) === boundary, msg)
      end

      def boolean(value, opts \\ [])
      def boolean(value, _) when is_number(value) and value in [0, 1], do: :ok
      def boolean(value, _) when is_binary(value) and value in ~w[0 1], do: :ok
      def boolean(value, _), do: validate(is_boolean(value), "This field must be true or false")

      def url(value, opts \\ [])

      def url(value, _) when is_binary(value) do
        case URI.parse(value) do
          %URI{scheme: scheme, host: host, port: port}
          when is_binary(scheme) and is_binary(host) and is_integer(port) ->
            :ok

          _ ->
            {:error, "This field must be a valid URL."}
        end
      end

      def url(_value, _), do: {:error, "This field must be a valid URL."}

      def active_url(value, opts \\ [])

      def active_url(value, _) do
        with :ok <- url(value),
             %URI{host: host} <- URI.parse(value),
             {:ok, _} <- :inet.gethostbyname(to_charlist(host)) do
          :ok
        else
          _ ->
            {:error, "This field is not a valid URL."}
        end
      end

      def run_rule(rule, value, opts), do: run_rule(rule, value, nil, opts)

      def run_rule(rule, value, params, opts) do
        case should_validate(rule, value, opts) do
          false ->
            :ok

          true ->
            if function_exported?(__MODULE__, rule, 3) do
              apply(__MODULE__, rule, [value, params, opts])
            else
              apply(__MODULE__, rule, [value, opts])
            end
        end
      end

      defp should_validate(rule, value, field: field, fields: fields) do
        Map.has_key?(fields, to_string(field)) || rule in @implicit_rules
      end

      defp value_size(value) when is_number(value), do: value
      defp value_size(value) when is_list(value) or is_map(value), do: Enum.count(value)
      defp value_size(value) when is_binary(value), do: String.length(value)
      defp value_size(_value), do: nil

      defp same_type(value1, value2) when is_number(value1) and is_number(value2), do: true
      defp same_type(value1, value2) when is_binary(value1) and is_binary(value2), do: true
      defp same_type(value1, value2) when is_list(value1) and is_list(value2), do: true
      defp same_type(_value1, _value2), do: false

      defp validate(condition, msg) do
        if !condition do
          {:error, msg}
        else
          :ok
        end
      end
    end
  end
end
