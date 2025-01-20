defmodule Request.Validator.Rulex do
  alias EmailChecker.Check.Format
  alias EmailChecker.Check.MX
  alias Request.Validator.Utils

  require Decimal

  @type rule :: %{
          required(:name) => atom(),
          required(:validator) => (... -> boolean()),
          optional(:implicit?) => boolean()
        }

  @doc """
  ## Examples

  iex> import Request.Validator.Rulex
  iex> %{validator: fun} = required()
  iex> fun.("")
  false
  iex> fun.(nil)
  false
  iex> fun.([])
  false
  iex> fun.(%{})
  false
  iex> fun.("hello world")
  true
  iex> fun.([1, 2])
  true
  iex> fun.(%{"hello" => "world"})
  true
  """
  @spec required() :: rule()
  def required do
    # TODO: check for empty `Plug.Upload`.
    validator_fn = fn value ->
      cond do
        is_nil(value) -> false
        is_binary(value) and String.trim(value) == "" -> false
        Enumerable.impl_for(value) != nil and Enum.empty?(value) -> false
        true -> true
      end
    end

    %{
      name: :required,
      implicit?: true,
      validator: validator_fn
    }
  end

  @doc """
  ## Examples

  iex> import Request.Validator.Rulex
  iex> %{validator: fun} = required_if(true)
  iex> fun.("")
  false
  iex> fun.(nil)
  false
  iex> %{validator: fun} = required_if(fn -> false end)
  iex> fun.("")
  true
  iex> fun.(nil)
  true
  """
  @spec required_if((... -> boolean()) | boolean()) :: rule()
  def required_if(condition) when is_function(condition) or is_boolean(condition) do
    %{validator: required} = required()

    validator_fn = fn
      false, _, _ -> true
      true, value, _fun -> required.(value)
      cond_fn, value, fun when is_function(cond_fn) -> fun.(cond_fn.(), value, fun)
    end

    %{
      name: :required_if,
      implicit?: true,
      validator: &validator_fn.(condition, &1, validator_fn)
    }
  end

  @doc """
  ## Examples

  iex> import Request.Validator.Rulex
  iex> %{validator: fun} = string()
  iex> fun.("")
  true
  iex> fun.(1)
  false
  iex> fun.(nil)
  false
  iex> fun.(%{})
  false
  iex> fun.([])
  false
  """
  @spec string() :: rule()
  def string, do: %{name: :string, validator: &is_binary/1}

  @doc """
  ## Examples

  iex> import Request.Validator.Rulex
  iex> %{validator: fun} = alpha()
  iex> fun.("abcde")
  true
  iex> fun.(1)
  false
  iex> fun.(nil)
  false
  iex> fun.(%{})
  false
  iex> fun.([])
  false
  """
  @spec alpha() :: rule()
  def alpha do
    %{name: :alpha, validator: &(is_binary(&1) and String.match?(&1, ~r/^[a-zA-Z]+$/))}
  end

  @doc """
  ## Examples

  iex> import Request.Validator.Rulex
  iex> %{validator: fun} = alpha_num()
  iex> fun.("1ab2de3")
  true
  iex> fun.(1)
  true
  iex> fun.("abc_de2")
  false
  iex> fun.(nil)
  false
  iex> fun.(%{})
  false
  iex> fun.([])
  false
  """
  @spec alpha_num() :: rule()
  def alpha_num do
    validator_fn = fn
      value when is_number(value) -> true
      value when is_binary(value) -> String.match?(value, ~r/^[a-zA-Z0-9]+$/)
      _value -> false
    end

    %{name: :alpha_num, validator: &validator_fn.(&1)}
  end

  @doc """
  ## Examples

  iex> import Request.Validator.Rulex
  iex> %{validator: fun} = alpha_dash()
  iex> fun.("abcde2")
  true
  iex> fun.("ab_d-2")
  true
  iex> fun.(1)
  true
  iex> fun.(nil)
  false
  iex> fun.(%{})
  false
  iex> fun.([])
  false
  """
  @spec alpha_dash() :: rule()
  def alpha_dash do
    validator_fn = fn
      value when is_number(value) -> true
      value when is_binary(value) -> String.match?(value, ~r/^[a-zA-Z0-9-_]+$/)
      _value -> false
    end

    %{name: :alpha_dash, validator: &validator_fn.(&1)}
  end

  @doc """
  ## Examples

  iex> import Request.Validator.Rulex
  iex> %{validator: fun} = integer()
  iex> fun.(1)
  true
  iex> fun.(2.0)
  false
  iex> fun.("abcde2")
  false
  iex> fun.(nil)
  false
  iex> fun.(%{})
  false
  iex> fun.([])
  false
  """
  @spec integer() :: rule()
  def integer, do: %{name: :integer, validator: &is_integer/1}

  @doc """
  ## Examples

  iex> import Request.Validator.Rulex
  iex> %{validator: fun} = decimal()
  iex> fun.(2.0)
  true
  iex> fun.(Decimal.new("9.999"))
  true
  iex> fun.(1)
  false
  iex> fun.("abcde2")
  false
  iex> fun.(nil)
  false
  iex> fun.(%{})
  false
  iex> fun.([])
  false
  """
  @spec decimal() :: rule()
  def decimal, do: %{name: :decimal, validator: &(is_float(&1) or Decimal.is_decimal(&1))}

  @doc """
  ## Examples

  iex> import Request.Validator.Rulex
  iex> %{validator: fun} = numeric()
  iex> fun.(2.0)
  true
  iex> fun.(1)
  true
  iex> fun.("abcde2")
  false
  iex> fun.(nil)
  false
  iex> fun.(%{})
  false
  iex> fun.([])
  false
  """
  @spec numeric() :: rule()
  def numeric, do: %{name: :numeric, validator: &is_number/1}

  @doc """
  ## Examples

  iex> import Request.Validator.Rulex
  iex> %{validator: fun} = email()
  iex> fun.("test@gmail.com")
  true
  iex> %{validator: fun} = email([:format])
  iex> fun.("a@b.com")
  true
  iex> %{validator: fun} = email(["mx"])
  iex> fun.("a@b.com")
  false
  iex> fun.(2.0)
  false
  iex> fun.(nil)
  false
  iex> fun.(%{})
  false
  iex> fun.([])
  false
  """
  @email_checks %{format: Format, mx: MX}
  @spec email([:format | :mx | String.t()]) :: rule()
  def email(validations \\ []) do
    validations =
      case validations do
        [] -> [Format, MX]
        validations -> validations |> Enum.map(&Utils.to_atom/1) |> Enum.map(&@email_checks[&1])
      end

    %{name: :email, validator: &(is_binary(&1) and EmailChecker.valid?(&1, validations))}
  end
end
