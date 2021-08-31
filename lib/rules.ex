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
      def email(value, opts \\ [])
      def email(nil, _), do: :ok

      def email(value, _) do
        validate(EmailChecker.valid?(value || ""), "This field must be a valid email address.")
      end

      def required(value, opts \\ [])

      def required(value, _) do
        result =
          is_list(value) ||
            is_map(value) ||
            is_number(value) ||
            (!is_nil(value) && String.length(value) > 0)

        validate(result, "This field is required.")
      end

      def string(value, opts \\ [])
      def string(nil, _), do: :ok

      def string(value, _) do
        validate(is_binary(value), "This field must be a string.")
      end

      def numeric(value, opts \\ [])
      def numeric(nil, _), do: :ok

      def numeric(value, _) do
        validate(is_number(value), "This field must be a number.")
      end

      def map(value, opts \\ [])
      def map(value, _) when is_nil(value) or is_map(value), do: :ok
      def map(value, _), do: {:error, "This field is expected to be a map."}

      def in_list(value, list, opts \\ [])

      def in_list(value, list, _) do
        validate(Enum.member?(list, value), "This field is invalid.")
      end

      def max(value, boundary, opts \\ [])
      def max(nil, _, _), do: :ok

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
      def min(nil, _, _), do: :ok

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

      def gt(nil, _, _), do: :ok

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

      def lt(nil, _, _), do: :ok

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

      defp value_size(value) when is_number(value), do: value
      defp value_size(value) when is_list(value), do: Enum.count(value)
      defp value_size(value) when is_binary(value), do: String.length(value)

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
