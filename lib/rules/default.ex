defmodule Request.Validator.DefaultRules do
  @moduledoc false

  defmacro __using__(_) do
    quote do
      @doc """

      ## Examples

          iex> Request.Validator.Rules.is_email("test@mail.com")
          true
          iex> Request.Validator.Rules.is_email("invalid@mail")
          false
      """
      @spec is_email(any()) :: boolean()
      def is_email(value), do: EmailChecker.valid?(value || "")

      @doc """

      ## Examples

          iex> Request.Validator.Rules.is_gt(12, 10)
          true
          iex> Request.Validator.Rules.is_gt(10, 20)
          false
      """
      @spec is_gt(any(), integer()) :: boolean()
      def is_gt(value, num), do: value > num

      @doc """

      ## Examples

          iex> Request.Validator.Rules.is_lt(12, 20)
          true
          iex> Request.Validator.Rules.is_lt(30, 20)
          false
      """
      @spec is_lt(any(), integer()) :: boolean()
      def is_lt(value, num), do: value < num


      @doc """

      ## Examples

          iex> Request.Validator.Rules.is_max(12, 20)
          true
          iex> Request.Validator.Rules.is_max(30, 20)
          false
          iex> Request.Validator.Rules.is_max("short", 6)
          true
          iex> Request.Validator.Rules.is_max("longer string", 6)
          false
          iex> Request.Validator.Rules.is_max(["short list"], 2)
          true
          iex> Request.Validator.Rules.is_max(["longer", "list", "example"], 2)
          false
      """
      @spec is_max(any(), integer()) :: boolean()
      def is_max(value, max) when is_number(value), do: value <= max
      def is_max(value, max) when is_binary(value), do: String.length(value) <= max
      def is_max(value, max) when is_list(value), do: Enum.count(value) <= max


      @doc """

      ## Examples

          iex> Request.Validator.Rules.is_min(12, 10)
          true
          iex> Request.Validator.Rules.is_min(30, 40)
          false
          iex> Request.Validator.Rules.is_min("longer", 6)
          true
          iex> Request.Validator.Rules.is_min("short", 6)
          false
          iex> Request.Validator.Rules.is_min(["longer", "list", "example"], 2)
          true
          iex> Request.Validator.Rules.is_min(["short list"], 2)
          false
      """
      @spec is_min(any(), integer()) :: boolean()
      def is_min(value, min) when is_number(value), do: value >= min
      def is_min(value, min) when is_binary(value), do: String.length(value) >= min
      def is_min(value, min) when is_list(value), do: Enum.count(value) >= min

      @doc """

      ## Examples

          iex> Request.Validator.Rules.lt(nil, :field, %{field: 10})
          true
          iex> Request.Validator.Rules.lt(12, :field, %{field: 20})
          true
          iex> Request.Validator.Rules.lt(30, :field, %{field: 20})
          false
      """
      @spec lt(any(), binary(), map()) :: boolean()
      def lt(nil, _, _), do: true
      def lt(value, field, fields), do: is_lt(value, Map.get(fields, field))

      @doc """

      ## Examples

          iex> Request.Validator.Rules.gt(nil, :field, %{field: 10})
          true
          iex> Request.Validator.Rules.gt(120, :field, %{field: 20})
          true
          iex> Request.Validator.Rules.gt(10, :field, %{field: 20})
          false
      """
      @spec gt(any(), binary(), map()) :: boolean()
      def gt(nil, _, _), do: true
      def gt(value, field, fields), do: is_gt(value, Map.get(fields, field))

      @doc """
      See `is_email/2`.
      """
      @spec email(any(), any()) :: boolean()
      def email(nil, _), do: true
      def email(value, _), do: is_email(value)

      @doc """

      ## Examples

          iex> Request.Validator.Rules.string("test@mail.com")
          true
          iex> Request.Validator.Rules.string(90)
          false
          iex> Request.Validator.Rules.string([])
          false
      """
      @spec string(any(), any()) :: boolean()
      def string(nil, _), do: true
      def string(val), do: string(val, nil)
      def string(value, _), do: is_binary(value)

      @doc """
      See `is_max/2`.
      """
      @spec max(any(), integer()) :: boolean()
      def max(nil, _), do: true
      def max(value, max), do: is_max(value, max)

      @doc """
      See `is_min/2`.
      """
      @spec min(any(), integer()) :: boolean()
      def min(nil, _), do: true
      def min(value, min), do: is_min(value, min)

      @doc """

      ## Examples

          iex> Request.Validator.Rules.numeric(90)
          true
          iex> Request.Validator.Rules.numeric("")
          false
      """
      @spec numeric(any(), any()) :: boolean()
      def numeric(nil, _), do: true
      def numeric(value), do: numeric(value, nil)
      def numeric(value, _), do: is_number(value)

      @doc """

      ## Examples

          iex> Request.Validator.Rules.required("test@mail.com")
          true
          iex> Request.Validator.Rules.required("")
          false
      """
      @spec required(any(), any()) :: boolean()
      def required(nil, _), do: false
      def required(value), do: required(value, nil)
      def required(value, _), do: is_list(value) || is_number(value) || !is_nil(value) && String.length(value) > 0
    end
  end
end
