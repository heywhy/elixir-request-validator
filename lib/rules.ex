defmodule Request.Validator.Rules do
  defmodule Bail do
    defstruct rules: []
  end

  defmodule Map_ do
    defstruct attrs: []
  end

  defmodule Array do
    defstruct attrs: []
  end

  def bail(rules), do: %__MODULE__.Bail{rules: rules}
  def map(attrs), do: %__MODULE__.Map_{attrs: attrs}
  def array(attrs), do: %__MODULE__.Array{attrs: attrs}

  defmacro __using__(_opts) do
    quote do
      def email(value, _) do
        validate(EmailChecker.valid?(value || ""), "This field must be a valid email address.")
      end

      def required(value, _) do
        result =
          is_list(value) ||
            is_number(value) ||
            (!is_nil(value) && String.length(value) > 0)

        validate(result, "This field is required")
      end

      def string(value, _) do
        validate(is_binary(value), "This field must be a string.")
      end

      def numeric(value, _) do
        validate(is_number(value), "This field must be a number.")
      end

      def max(value, boundary, opts) do
        cond do
          is_binary(value) ->
            validate(
              String.length(value) <= boundary,
              "This field must be greater than #{boundary} characters."
            )

          is_list(value) ->
            validate(
              Enum.count(value) <= boundary,
              "This field must be more than #{boundary} items."
            )

          true ->
            validate(value <= boundary, "This field must be greater than #{boundary} characters.")
        end
      end

      def min(value, boundary, opts) do
        cond do
          is_binary(value) ->
            validate(
              String.length(value) >= boundary,
              "This field must be at least #{boundary} characters."
            )

          is_list(value) ->
            validate(
              Enum.count(value) >= boundary,
              "This field must be at least #{boundary} items."
            )

          true ->
            validate(value >= boundary, "This field must be at least #{boundary}.")
        end
      end

      def gt(value, boundary, opts) do
        min =
          opts
          |> Keyword.get(:fields)
          |> Map.get(to_string(boundary))

        msg =
          cond do
            is_list(value) ->
              "This field must have more items than #{boundary}."

            true ->
              "This field must be greater than #{boundary}."
          end

        validate(value > min, msg)
      end

      def lt(value, boundary, opts) do
        min =
          opts
          |> Keyword.get(:fields)
          |> Map.get(to_string(boundary))

        msg =
          cond do
            is_list(value) ->
              "This field must have less items than #{boundary}."

            true ->
              "This field must be less than #{boundary}."
          end

        validate(value < min, msg)
      end

      def confirmed(value, field: field, fields: fields) do
        path = "#{field}_confirmation"

        validate(value == fields[path], "This field confirmation does not match")
      end

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
