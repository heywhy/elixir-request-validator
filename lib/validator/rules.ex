defmodule Request.Validator.Rulex do
  alias EmailChecker.Check.Format
  alias EmailChecker.Check.MX
  alias Request.Validator.Utils

  import Gettext.Macros

  require Decimal

  @type rule :: %{
          required(:name) => atom(),
          required(:validator) => (... -> boolean()),
          required(:message) => binary(),
          optional(:implicit?) => boolean()
        }

  @backend Application.compile_env(
             :request_validator,
             :gettext_backend,
             Request.Validator.Gettext
           )

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
      validator: validator_fn,
      message: gettext_with_backend(@backend, "The :attribute field is required.")
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
      validator: &validator_fn.(condition, &1, validator_fn),
      message:
        gettext_with_backend(@backend, "The :attribute field is required when :other is :value.")
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
  def string do
    %{
      name: :string,
      validator: &is_binary/1,
      message:
        gettext_with_backend(@backend, "The :attribute field is required when :other is :value.")
    }
  end

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
    %{
      name: :alpha,
      validator: &(is_binary(&1) and String.match?(&1, ~r/^[a-zA-Z]+$/)),
      message: gettext_with_backend(@backend, "The :attribute may only contain letters.")
    }
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

    %{
      name: :alpha_num,
      validator: &validator_fn.(&1),
      message:
        gettext_with_backend(@backend, "The :attribute may only contain letters and numbers.")
    }
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

    %{
      name: :alpha_dash,
      validator: &validator_fn.(&1),
      message:
        gettext_with_backend(
          @backend,
          "The :attribute may only contain letters, numbers, dashes and underscores."
        )
    }
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
  def integer do
    %{
      name: :integer,
      validator: &is_integer/1,
      message: gettext_with_backend(@backend, "The :attribute must be an integer.")
    }
  end

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
  def decimal do
    %{
      name: :decimal,
      validator: &(is_float(&1) or Decimal.is_decimal(&1)),
      message: gettext_with_backend(@backend, "The :attribute must be an decimal.")
    }
  end

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
  def numeric do
    %{
      name: :numeric,
      validator: &is_number/1,
      message: gettext_with_backend(@backend, "The :attribute must be a number.")
    }
  end

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

    %{
      name: :email,
      validator: &(is_binary(&1) and EmailChecker.valid?(&1, validations)),
      message: gettext_with_backend(@backend, "The :attribute must be a valid email address.")
    }
  end

  @doc """
  ## Examples

  iex> import Request.Validator.Rulex
  iex> data = %{
  ...>   "password" => 12345678,
  ...>   "password_confirmation" => 12345678,
  ...>   "list" => [%{"a" => 1, "a_confirmation" => 1}]
  ...> }
  iex> %{validator: fun} = confirmed()
  iex> fun.("password", 12345678, data)
  true
  iex> fun.("list.0.a", 1, data)
  true
  iex> fun.("password", "yikes!", data)
  false
  iex> fun.("list.0.a", 10, data)
  false
  """
  @spec confirmed(nil | String.t()) :: rule()
  def confirmed(attr \\ nil) do
    validator_fn = fn field, value, data ->
      attr =
        case attr do
          nil -> field <> "_confirmation"
          attr -> attr
        end

      # INFO: maybe not convert to path and have the data already flatten?
      attr_path = Utils.convert_to_path(attr)

      get_in(data, attr_path) == value
    end

    %{
      name: :confirmed,
      validator: &validator_fn.(&1, &2, &3),
      message: gettext_with_backend(@backend, "The :attribute confirmation does not match.")
    }
  end

  @doc """
  ## Examples

  iex> import Request.Validator.Rulex
  iex> %{validator: fun} = allowed(["male", "female"])
  iex> fun.("male")
  true
  iex> fun.("female")
  true
  iex> fun.("child")
  false
  iex> fun.("goat")
  false
  """
  @spec allowed([term()]) :: rule()
  def allowed(values) do
    %{
      name: :allowed,
      validator: &Enum.member?(values, &1),
      message: gettext_with_backend(@backend, "The selected :attribute is invalid.")
    }
  end
end
