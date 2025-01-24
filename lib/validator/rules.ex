defmodule Request.Validator.Rules do
  alias EmailChecker.Check.Format
  alias EmailChecker.Check.MX
  alias Request.Validator.Utils

  import Gettext.Macros, only: [gettext_with_backend: 3]

  require Decimal

  @type validator :: (... -> :ok | {:error, String.t()})
  @type rule ::
          validator()
          | %{
              required(:validator) => validator(),
              optional(:implicit?) => boolean()
            }

  @backend Application.compile_env(
             :request_validator,
             :gettext_backend,
             Request.Validator.Gettext
           )

  defmacrop gettext(msgid, opts) do
    quote do
      gettext_with_backend(@backend, unquote(msgid), unquote(opts))
    end
  end

  @doc """
  ## Examples

  iex> import Request.Validator.Rules
  iex> %{validator: fun} = required()
  iex> fun.("name", "")
  {:error, "The name field is required."}
  iex> fun.("gender", nil)
  {:error, "The gender field is required."}
  iex> fun.("coordinates", [])
  {:error, "The coordinates field is required."}
  iex> fun.("metadata", %{})
  {:error, "The metadata field is required."}
  iex> fun.("message", "hello world")
  :ok
  iex> fun.("products", [1, 2])
  :ok
  iex> fun.("metadata", %{"hello" => "world"})
  :ok
  """
  @spec required() :: rule()
  def required do
    # TODO: check for empty `Plug.Upload`.
    validator_fn = fn attr, value ->
      message = gettext("The %{attribute} field is required.", attribute: attr)

      cond do
        is_nil(value) -> {:error, message}
        is_binary(value) and String.trim(value) == "" -> {:error, message}
        Enumerable.impl_for(value) != nil and Enum.empty?(value) -> {:error, message}
        true -> :ok
      end
    end

    %{implicit?: true, validator: validator_fn}
  end

  @doc """
  ## Examples

  iex> import Request.Validator.Rules
  iex> %{validator: fun} = required_if(true)
  iex> fun.("description", "")
  {:error, "The description field is required."}
  iex> fun.("age", nil)
  {:error, "The age field is required."}
  iex> %{validator: fun} = required_if(fn -> false end)
  iex> fun.("key", "")
  :ok
  iex> fun.("state", nil)
  :ok
  iex> %{validator: fun} = required_if(["passenger", "kid"])
  iex> data = %{"passenger" => "kid"}
  iex> fun.("parent", nil, data)
  {:error, "The parent field is required when passenger is kid."}
  """
  @spec required_if((... -> boolean()) | boolean() | [term()]) :: rule()
  def required_if(condition) when is_function(condition) or is_boolean(condition) do
    %{validator: required} = required()

    validator_fn = fn
      false, _, _, _ -> :ok
      true, attr, value, _fun -> required.(attr, value)
      cond_fn, attr, value, fun when is_function(cond_fn) -> fun.(cond_fn.(), attr, value, fun)
    end

    %{
      implicit?: true,
      validator: &validator_fn.(condition, &1, &2, validator_fn)
    }
  end

  def required_if([other, value]) do
    required_if(other, value, &Kernel.==/2)
  end

  # TODO: allow other operators and tailor error appropriately.
  defp required_if(other, value, op) do
    %{validator: required} = required()

    validator_fn = fn
      false, _, _, _, _ ->
        :ok

      true, attr, value, other, cond ->
        message =
          gettext(
            "The %{attribute} field is required when %{other} is %{value}.",
            attribute: attr,
            other: other,
            value: cond
          )

        check(required.(attr, value) == :ok, message)
    end

    %{
      implicit?: true,
      validator: &(op.(&3[other], value) |> validator_fn.(&1, &2, other, value))
    }
  end

  @doc """
  ## Examples

  iex> import Request.Validator.Rules
  iex> fun = string()
  iex> fun.("content", "")
  :ok
  iex> fun.("content", 1)
  {:error, "The content field must be a string."}
  iex> fun.("content", nil)
  {:error, "The content field must be a string."}
  iex> fun.("content", %{})
  {:error, "The content field must be a string."}
  iex> fun.("content", [])
  {:error, "The content field must be a string."}
  """
  @spec string() :: rule()
  def string do
    validator_fn = fn attr, value ->
      message = gettext("The %{attribute} field must be a string.", attribute: attr)

      check(is_binary(value), message)
    end

    &validator_fn.(&1, &2)
  end

  @doc """
  ## Examples

  iex> import Request.Validator.Rules
  iex> fun = alpha()
  iex> fun.("uid", "abcde")
  :ok
  iex> fun.("uid", 1)
  {:error, "The uid field must only contain letters."}
  iex> fun.("uid", nil)
  {:error, "The uid field must only contain letters."}
  iex> fun.("uid", %{})
  {:error, "The uid field must only contain letters."}
  iex> fun.("uid", [])
  {:error, "The uid field must only contain letters."}
  """
  @spec alpha() :: rule()
  def alpha do
    validator_fn = fn attr, value ->
      message = gettext("The %{attribute} field must only contain letters.", attribute: attr)

      value
      |> is_binary()
      |> Kernel.and(String.match?(value, ~r/^[a-zA-Z]+$/))
      |> check(message)
    end

    &validator_fn.(&1, &2)
  end

  @doc """
  ## Examples

  iex> import Request.Validator.Rules
  iex> fun = alpha_num()
  iex> fun.("ref", "1ab2de3")
  :ok
  iex> fun.("ref", 1)
  {:error, "The ref field must only contain letters and numbers."}
  iex> fun.("ref", "abc_de2")
  {:error, "The ref field must only contain letters and numbers."}
  iex> fun.("ref", nil)
  {:error, "The ref field must only contain letters and numbers."}
  iex> fun.("ref", %{})
  {:error, "The ref field must only contain letters and numbers."}
  iex> fun.("ref", [])
  {:error, "The ref field must only contain letters and numbers."}
  """
  @spec alpha_num() :: rule()
  def alpha_num do
    validator_fn = fn attr, value ->
      message =
        gettext("The %{attribute} field must only contain letters and numbers.",
          attribute: attr
        )

      value
      |> is_binary()
      |> Kernel.and(String.match?(value, ~r/^[a-zA-Z0-9]+$/))
      |> check(message)
    end

    &validator_fn.(&1, &2)
  end

  @doc """
  ## Examples

  iex> import Request.Validator.Rules
  iex> fun = alpha_dash()
  iex> fun.("username", "abcde2")
  :ok
  iex> fun.("username", "ab_d-2")
  :ok
  iex> fun.("username", 1)
  {:error, "The username field must only contain letters, numbers, dashes, and underscores."}
  iex> fun.("username", nil)
  {:error, "The username field must only contain letters, numbers, dashes, and underscores."}
  iex> fun.("username", %{})
  {:error, "The username field must only contain letters, numbers, dashes, and underscores."}
  iex> fun.("username", [])
  {:error, "The username field must only contain letters, numbers, dashes, and underscores."}
  """
  @spec alpha_dash() :: rule()
  def alpha_dash do
    validator_fn = fn attr, value ->
      message =
        gettext(
          "The %{attribute} field must only contain letters, numbers, dashes, and underscores.",
          attribute: attr
        )

      value
      |> is_binary()
      |> Kernel.and(String.match?(value, ~r/^[a-zA-Z0-9-_]+$/))
      |> check(message)
    end

    &validator_fn.(&1, &2)
  end

  @doc """
  ## Examples

  iex> import Request.Validator.Rules
  iex> fun = integer()
  iex> fun.("age", 1)
  :ok
  iex> fun.("age", 2.0)
  {:error, "The age field must be an integer."}
  iex> fun.("age", "abcde2")
  {:error, "The age field must be an integer."}
  iex> fun.("age", nil)
  {:error, "The age field must be an integer."}
  iex> fun.("age", %{})
  {:error, "The age field must be an integer."}
  iex> fun.("age", [])
  {:error, "The age field must be an integer."}
  """
  @spec integer() :: rule()
  def integer do
    validator_fn = fn attr, value ->
      message = gettext("The %{attribute} field must be an integer.", attribute: attr)

      check(is_integer(value), message)
    end

    &validator_fn.(&1, &2)
  end

  @doc """
  ## Examples

  iex> import Request.Validator.Rules
  iex> fun = decimal()
  iex> fun.("amount", 2.0)
  :ok
  iex> fun.("amount", Decimal.new("9.999"))
  :ok
  iex> fun.("amount", 1)
  {:error, "The amount field must be a decimal."}
  iex> fun.("amount", "abcde2")
  {:error, "The amount field must be a decimal."}
  iex> fun.("amount", nil)
  {:error, "The amount field must be a decimal."}
  iex> fun.("amount", %{})
  {:error, "The amount field must be a decimal."}
  iex> fun.("amount", [])
  {:error, "The amount field must be a decimal."}
  """
  @spec decimal() :: rule()
  def decimal do
    # TODO: support decimal places validation.
    validator_fn = fn attr, value ->
      message = gettext("The %{attribute} field must be a decimal.", attribute: attr)

      check(is_float(value) or Decimal.is_decimal(value), message)
    end

    &validator_fn.(&1, &2)
  end

  @doc """
  ## Examples

  iex> import Request.Validator.Rules
  iex> fun = numeric()
  iex> fun.("width", 2.0)
  :ok
  iex> fun.("width", 1)
  :ok
  iex> fun.("width", "abcde2")
  {:error, "The width field must be a number."}
  iex> fun.("width", nil)
  {:error, "The width field must be a number."}
  iex> fun.("width", %{})
  {:error, "The width field must be a number."}
  iex> fun.("width", [])
  {:error, "The width field must be a number."}
  """
  @spec numeric() :: rule()
  def numeric do
    validator_fn = fn attr, value ->
      message = gettext("The %{attribute} field must be a number.", attribute: attr)

      check(is_number(value), message)
    end

    &validator_fn.(&1, &2)
  end

  @doc """
  ## Examples

  iex> import Request.Validator.Rules
  iex> fun = email()
  iex> fun.("email", "test@gmail.com")
  :ok
  iex> fun = email([:format])
  iex> fun.("email", "a@b.com")
  :ok
  iex> fun = email(["mx"])
  iex> fun.("email", "a@b.com")
  {:error, "The email field must be a valid email address."}
  iex> fun.("email", 2.0)
  {:error, "The email field must be a valid email address."}
  iex> fun.("email", nil)
  {:error, "The email field must be a valid email address."}
  iex> fun.("email", %{})
  {:error, "The email field must be a valid email address."}
  iex> fun.("email", [])
  {:error, "The email field must be a valid email address."}
  """
  @email_checks %{format: Format, mx: MX}
  @spec email([:format | :mx | String.t()]) :: rule()
  def email(validations \\ []) do
    validations =
      case validations do
        [] -> [Format, MX]
        validations -> validations |> Enum.map(&Utils.to_atom/1) |> Enum.map(&@email_checks[&1])
      end

    validator_fn = fn validations, attr, value ->
      message = gettext("The %{attribute} field must be a valid email address.", attribute: attr)

      check(is_binary(value) and EmailChecker.valid?(value, validations), message)
    end

    &validator_fn.(validations, &1, &2)
  end

  @doc """
  ## Examples

  iex> alias Request.Validator.Fields
  iex> import Request.Validator.Rules
  iex> data = Fields.new(%{
  ...>   "password" => 12345678,
  ...>   "password_confirmation" => 12345678,
  ...>   "list" => [%{"a" => 1, "a_confirmation" => 1}]
  ...> })
  iex> fun = confirmed()
  iex> fun.("password", 12345678, data)
  :ok
  iex> fun.("list.0.a", 1, data)
  :ok
  iex> fun.("password", "yikes!", data)
  {:error, "The password field confirmation does not match."}
  iex> fun.("list.0.a", 10, data)
  {:error, "The list.0.a field confirmation does not match."}
  """
  @spec confirmed(nil | String.t()) :: rule()
  def confirmed(confirmation \\ nil) do
    validator_fn = fn confirmation, attr, value, data ->
      confirmation =
        case confirmation do
          nil -> attr <> "_confirmation"
          confirmation -> confirmation
        end

      message = gettext("The %{attribute} field confirmation does not match.", attribute: attr)

      check(data[confirmation] == value, message)
    end

    &validator_fn.(confirmation, &1, &2, &3)
  end

  @doc """
  ## Examples

  iex> import Request.Validator.Rules
  iex> fun = allowed(["male", "female"])
  iex> fun.("gender", "male")
  :ok
  iex> fun.("gender", "female")
  :ok
  iex> fun.("gender", "child")
  {:error, "The selected gender is invalid."}
  iex> fun.("gender", "goat")
  {:error, "The selected gender is invalid."}
  """
  @spec allowed([term()]) :: rule()
  def allowed(options) do
    validator_fn = fn options, attr, value ->
      message = gettext("The selected %{attribute} is invalid.", attribute: attr)

      options
      |> Enum.member?(value)
      |> check(message)
    end

    &validator_fn.(options, &1, &2)
  end

  defp check(cond, message) do
    case cond do
      true -> :ok
      false -> {:error, message}
    end
  end
end
