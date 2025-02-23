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

  @doc ~S"""
  ## Examples

      iex> import Request.Validator.Rules, only: [required: 0]
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

  @doc ~S"""
  ## Examples

      iex> import Request.Validator.Rules, only: [required_if: 1]
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

  @doc ~S"""
  ## Examples

      iex> import Request.Validator.Rules, only: [string: 0]
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

  @doc ~S"""
  ## Examples

      iex> import Request.Validator.Rules, only: [alpha: 0]
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

  @doc ~S"""
  ## Examples

      iex> import Request.Validator.Rules, only: [alpha_num: 0]
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

  @doc ~S"""
  ## Examples

      iex> import Request.Validator.Rules, only: [alpha_dash: 0]
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

  @doc ~S"""
  ## Examples

      iex> import Request.Validator.Rules, only: [integer: 0]
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

  @doc ~S"""
  ## Examples

      iex> import Request.Validator.Rules, only: [decimal: 0]
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

  @doc ~S"""
  ## Examples

      iex> import Request.Validator.Rules, only: [numeric: 0]
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

  @doc ~S"""
  ## Examples

      iex> import Request.Validator.Rules, only: [email: 0, email: 1]
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

  @doc ~S"""
  ## Examples

      iex> alias Request.Validator.Fields
      iex> import Request.Validator.Rules, only: [confirmed: 0, confirmed: 1]
      iex> fields = Fields.new(%{
      ...>   "password" => 12345678,
      ...>   "password_confirmation" => 12345678,
      ...>   "list" => [%{"a" => 1, "a_confirmation" => 1}]
      ...> })
      iex> fun = confirmed()
      iex> fun.("password", 12345678, fields)
      :ok
      iex> fun.("list.0.a", 1, fields)
      :ok
      iex> fun.("password", "yikes!", fields)
      {:error, "The password field confirmation does not match."}
      iex> fun.("list.0.a", 10, fields)
      {:error, "The list.0.a field confirmation does not match."}
  """
  @spec confirmed(nil | String.t()) :: rule()
  def confirmed(confirmation \\ nil) do
    validator_fn = fn confirmation, attr, value, fields ->
      confirmation =
        case confirmation do
          nil -> attr <> "_confirmation"
          confirmation -> confirmation
        end

      message = gettext("The %{attribute} field confirmation does not match.", attribute: attr)

      check(fields[confirmation] == value, message)
    end

    &validator_fn.(confirmation, &1, &2, &3)
  end

  @doc ~S"""
  ## Examples

      iex> import Request.Validator.Rules, only: [allowed: 1]
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
  def allowed(options) when is_list(options) do
    validator_fn = fn options, attr, value ->
      message = gettext("The selected %{attribute} is invalid.", attribute: attr)

      options
      |> Enum.member?(value)
      |> check(message)
    end

    &validator_fn.(options, &1, &2)
  end

  @doc ~S"""
  ## Examples

      iex> import Request.Validator.Rules, only: [min: 1]
      iex> fun = min([30])
      iex> fun.("age", 40)
      :ok
      iex> fun.("age", 10)
      {:error, "The age field must be at least 30."}
      iex> fun = min(6)
      iex> fun.("password", "pass")
      {:error, "The password field must be at least 6 characters."}
      iex> fun.("password", "password")
      :ok
      iex> fun = min(1)
      iex> fun.("tags", [])
      {:error, "The tags field must be at least 1 items."}
      iex> fun.("tags", [1, 3])
      :ok
  """
  def min([bound]), do: min(bound)

  def min(bound) when is_number(bound) do
    # TODO: check for `Plug.Upload` size.
    validator_fn = fn bound, attr, value ->
      messages = %{
        numeric:
          gettext("The %{attribute} field must be at least %{min}.",
            attribute: attr,
            min: bound
          ),
        string:
          gettext("The %{attribute} field must be at least %{min} characters.",
            attribute: attr,
            min: bound
          ),
        list:
          gettext("The %{attribute} field must be at least %{min} items.",
            attribute: attr,
            min: bound
          )
      }

      check_size_with_op(value, bound, &Kernel.>=/2, messages)
    end

    &validator_fn.(bound, &1, &2)
  end

  @doc ~S"""
  ## Examples

      iex> import Request.Validator.Rules, only: [max: 1]
      iex> fun = max([30])
      iex> fun.("age", 20)
      :ok
      iex> fun.("age", 30)
      :ok
      iex> fun.("age", 40)
      {:error, "The age field must not be greater than 30."}
      iex> fun = max(6)
      iex> fun.("otp", "1611675")
      {:error, "The otp field must not be greater than 6 characters."}
      iex> fun.("otp", "955764")
      :ok
      iex> fun = max(2)
      iex> fun.("tags", [1, 2, 3])
      {:error, "The tags field must not be greater than 2 items."}
      iex> fun.("tags", [1, 3])
      :ok
  """
  def max([bound]), do: max(bound)

  def max(bound) when is_number(bound) do
    # TODO: check for `Plug.Upload` size.
    validator_fn = fn bound, attr, value ->
      messages = %{
        numeric:
          gettext("The %{attribute} field must not be greater than %{max}.",
            attribute: attr,
            max: bound
          ),
        list:
          gettext("The %{attribute} field must not be greater than %{max} items.",
            attribute: attr,
            max: bound
          ),
        string:
          gettext("The %{attribute} field must not be greater than %{max} characters.",
            attribute: attr,
            max: bound
          )
      }

      check_size_with_op(value, bound, &Kernel.<=/2, messages)
    end

    &validator_fn.(bound, &1, &2)
  end

  @doc ~S"""
  ## Examples

      iex> alias Request.Validator.Fields
      iex> import Request.Validator.Rules, only: [gt: 1]
      iex> fields = Fields.new(%{
      ...>   "age" => 30,
      ...>   "items" => [0, 1],
      ...>   "passphrase" => "tango"
      ...> })
      iex> fun = gt("age")
      iex> fun.("mother_age", 25, fields)
      {:error, "The mother_age field must be greater than 30."}
      iex> fun.("mother_age", 45, fields)
      :ok
      iex> fun = gt(30)
      iex> fun.("mother_age", 20, fields)
      {:error, "The mother_age field must be greater than 30."}
      iex> fun.("mother_age", "20", fields)
      {:error, "The mother_age field must be greater than 30 characters."}
      iex> fun.("mother_age", 50, fields)
      :ok
      iex> fun = gt("passphrase")
      iex> fun.("passphrase_hash", "milk", fields)
      {:error, "The passphrase_hash field must be greater than 5 characters."}
      iex> fun.("passphrase_hash", "aHsychxUY", fields)
      :ok
      iex> fun = gt("items")
      iex> fun.("sub_items", [2, 3, 4], fields)
      :ok
      iex> fun.("sub_items", [1], fields)
      {:error, "The sub_items field must have more than 2 items."}
      iex> fun.("sub_items", "milk", fields)
      {:error, "The sub_items field must be greater than 2 characters."}
  """
  def gt([bound]), do: gt(bound)

  def gt(bound) when is_binary(bound) or is_number(bound) do
    validator_fn = fn bound, attr, value, fields ->
      compared_value = fields[bound]
      v = get_size(compared_value) || bound

      messages = %{
        numeric:
          gettext("The %{attribute} field must be greater than %{value}.",
            attribute: attr,
            value: v
          ),
        list:
          gettext("The %{attribute} field must have more than %{value} items.",
            attribute: attr,
            value: v
          ),
        string:
          gettext("The %{attribute} field must be greater than %{value} characters.",
            attribute: attr,
            value: v
          )
      }

      cond do
        is_nil(compared_value) and (is_number(value) and is_number(bound)) ->
          check_size_with_op(value, bound, &Kernel.>/2, messages)

        is_number(bound) ->
          {:error, messages.string}

        same_type?(value, compared_value) ->
          check_size_with_op(value, compared_value, &Kernel.>/2, messages)

        true ->
          {:error, messages.string}
      end
    end

    &validator_fn.(bound, &1, &2, &3)
  end

  @doc ~S"""
  ## Examples

      iex> alias Request.Validator.Fields
      iex> import Request.Validator.Rules, only: [lt: 1]
      iex> fields = Fields.new(%{
      ...>   "mother_age" => 30,
      ...>   "items" => [0, 1],
      ...>   "essay" => "lorem ipsum"
      ...> })
      iex> fun = lt("mother_age")
      iex> fun.("child_age", 30, fields)
      {:error, "The child_age field must be less than 30."}
      iex> fun.("child_age", 18, fields)
      :ok
      iex> fun = lt(30)
      iex> fun.("child_age", 50, fields)
      {:error, "The child_age field must be less than 30."}
      iex> fun.("child_age", "20", fields)
      {:error, "The child_age field must be less than 30 characters."}
      iex> fun.("child_age", 20, fields)
      :ok
      iex> fun = lt("essay")
      iex> fun.("comment", "lorem ipsum dolor sit amet", fields)
      {:error, "The comment field must be less than 11 characters."}
      iex> fun.("comment", "lorem", fields)
      :ok
      iex> fun = lt("items")
      iex> fun.("sub_items", [], fields)
      :ok
      iex> fun.("sub_items", [2, 3, 4], fields)
      {:error, "The sub_items field must have less than 2 items."}
      iex> fun.("sub_items", "milk", fields)
      {:error, "The sub_items field must be less than 2 characters."}
  """
  def lt([bound]), do: lt(bound)

  def lt(bound) when is_binary(bound) or is_number(bound) do
    validator_fn = fn bound, attr, value, fields ->
      compared_value = fields[bound]
      v = get_size(compared_value) || bound

      messages = %{
        numeric:
          gettext("The %{attribute} field must be less than %{value}.",
            attribute: attr,
            value: v
          ),
        list:
          gettext("The %{attribute} field must have less than %{value} items.",
            attribute: attr,
            value: v
          ),
        string:
          gettext("The %{attribute} field must be less than %{value} characters.",
            attribute: attr,
            value: v
          )
      }

      cond do
        is_nil(compared_value) and (is_number(value) and is_number(bound)) ->
          check_size_with_op(value, bound, &Kernel.</2, messages)

        is_number(bound) ->
          {:error, messages.string}

        same_type?(value, compared_value) ->
          check_size_with_op(value, compared_value, &Kernel.</2, messages)

        true ->
          {:error, messages.string}
      end
    end

    &validator_fn.(bound, &1, &2, &3)
  end

  @doc ~S"""
  ## Examples

      iex> alias Request.Validator.Fields
      iex> import Request.Validator.Rules, only: [gte: 1]
      iex> fields = Fields.new(%{
      ...>   "age" => 30,
      ...>   "items" => [0, 1],
      ...>   "passphrase" => "tango"
      ...> })
      iex> fun = gte("age")
      iex> fun.("mother_age", 25, fields)
      {:error, "The mother_age field must be greater than or equal to 30."}
      iex> fun.("mother_age", 45, fields)
      :ok
      iex> fun = gte(30)
      iex> fun.("mother_age", 20, fields)
      {:error, "The mother_age field must be greater than or equal to 30."}
      iex> fun.("mother_age", "20", fields)
      {:error, "The mother_age field must be greater than or equal to 30 characters."}
      iex> fun.("mother_age", 50, fields)
      :ok
      iex> fun = gte("passphrase")
      iex> fun.("passphrase_hash", "milk", fields)
      {:error, "The passphrase_hash field must be greater than or equal to 5 characters."}
      iex> fun.("passphrase_hash", "aHsychxUY", fields)
      :ok
      iex> fun = gte("items")
      iex> fun.("sub_items", [2, 3], fields)
      :ok
      iex> fun.("sub_items", [1], fields)
      {:error, "The sub_items field must have 2 items or more."}
      iex> fun.("sub_items", "milk", fields)
      {:error, "The sub_items field must be greater than or equal to 2 characters."}
  """
  def gte([bound]), do: gte(bound)

  def gte(bound) when is_binary(bound) or is_number(bound) do
    validator_fn = fn bound, attr, value, fields ->
      compared_value = fields[bound]
      v = get_size(compared_value) || bound

      messages = %{
        numeric:
          gettext("The %{attribute} field must be greater than or equal to %{value}.",
            attribute: attr,
            value: v
          ),
        list:
          gettext("The %{attribute} field must have %{value} items or more.",
            attribute: attr,
            value: v
          ),
        string:
          gettext("The %{attribute} field must be greater than or equal to %{value} characters.",
            attribute: attr,
            value: v
          )
      }

      cond do
        is_nil(compared_value) and (is_number(value) and is_number(bound)) ->
          check_size_with_op(value, bound, &Kernel.>=/2, messages)

        is_number(bound) ->
          {:error, messages.string}

        same_type?(value, compared_value) ->
          check_size_with_op(value, compared_value, &Kernel.>=/2, messages)

        true ->
          {:error, messages.string}
      end
    end

    &validator_fn.(bound, &1, &2, &3)
  end

  @doc ~S"""
  ## Examples

      iex> alias Request.Validator.Fields
      iex> import Request.Validator.Rules, only: [lte: 1]
      iex> fields = Fields.new(%{
      ...>   "mother_age" => 30,
      ...>   "items" => [0, 1],
      ...>   "essay" => "lorem ipsum"
      ...> })
      iex> fun = lte("mother_age")
      iex> fun.("child_age", 31, fields)
      {:error, "The child_age field must be less than or equal to 30."}
      iex> fun.("child_age", 18, fields)
      :ok
      iex> fun = lte(30)
      iex> fun.("child_age", 50, fields)
      {:error, "The child_age field must be less than or equal to 30."}
      iex> fun.("child_age", "20", fields)
      {:error, "The child_age field must be less than or equal to 30 characters."}
      iex> fun.("child_age", 20, fields)
      :ok
      iex> fun = lte("essay")
      iex> fun.("comment", "lorem ipsum dolor sit amet", fields)
      {:error, "The comment field must be less than or equal to 11 characters."}
      iex> fun.("comment", "lorem", fields)
      :ok
      iex> fun = lte("items")
      iex> fun.("sub_items", [6, 7], fields)
      :ok
      iex> fun.("sub_items", [2, 3, 4], fields)
      {:error, "The sub_items field must not have more than 2 items."}
      iex> fun.("sub_items", "milk", fields)
      {:error, "The sub_items field must be less than or equal to 2 characters."}
  """
  def lte([bound]), do: lte(bound)

  def lte(bound) when is_binary(bound) or is_number(bound) do
    validator_fn = fn bound, attr, value, fields ->
      compared_value = fields[bound]
      v = get_size(compared_value) || bound

      messages = %{
        numeric:
          gettext("The %{attribute} field must be less than or equal to %{value}.",
            attribute: attr,
            value: v
          ),
        list:
          gettext("The %{attribute} field must not have more than %{value} items.",
            attribute: attr,
            value: v
          ),
        string:
          gettext("The %{attribute} field must be less than or equal to %{value} characters.",
            attribute: attr,
            value: v
          )
      }

      cond do
        is_nil(compared_value) and (is_number(value) and is_number(bound)) ->
          check_size_with_op(value, bound, &Kernel.<=/2, messages)

        is_number(bound) ->
          {:error, messages.string}

        same_type?(value, compared_value) ->
          check_size_with_op(value, compared_value, &Kernel.<=/2, messages)

        true ->
          {:error, messages.string}
      end
    end

    &validator_fn.(bound, &1, &2, &3)
  end

  @doc ~S"""
  ## Examples

      iex> import Request.Validator.Rules, only: [size: 1]
      iex> fun = size(5)
      iex> fun.("age", 10)
      {:error, "The age field must be 5."}
      iex> fun.("age", 5)
      :ok
      iex> fun.("username", "chic")
      {:error, "The username field must be 5 characters."}
      iex> fun.("username", "chick")
      :ok
      iex> fun.("tags", ["chic"])
      {:error, "The tags field must contain 5 items."}
      iex> fun.("tags", Enum.to_list(1..5))
      :ok
  """
  def size([bound]), do: size(bound)

  def size(bound) when is_number(bound) do
    # TODO: check for file size
    validator_fn = fn bound, attr, value ->
      messages = %{
        numeric: gettext("The %{attribute} field must be %{size}.", attribute: attr, size: bound),
        list:
          gettext("The %{attribute} field must contain %{size} items.",
            attribute: attr,
            size: bound
          ),
        string:
          gettext("The %{attribute} field must be %{size} characters.",
            attribute: attr,
            size: bound
          )
      }

      check_size_with_op(value, bound, &Kernel.==/2, messages)
    end

    &validator_fn.(bound, &1, &2)
  end

  @doc ~S"""
  ## Examples

      iex> import Request.Validator.Rules, only: [url: 0]
      iex> fun = url()
      iex> fun.("url", "https://google.com")
      :ok
      iex> fun.("url", "invalid_url")
      {:error, "The url field must be a valid URL."}
  """
  def url do
    fn attr, value ->
      message = gettext("The %{attribute} field must be a valid URL.", attribute: attr)

      value
      |> is_binary()
      |> Kernel.and(
        match?(
          %URI{host: <<_::binary>>, scheme: <<_::binary>>, port: port} when is_integer(port),
          URI.parse(value)
        )
      )
      |> check(message)
    end
  end

  @doc ~S"""
  ## Examples

      iex> import Request.Validator.Rules, only: [active_url: 0]
      iex> fun = active_url()
      iex> fun.("url", "https://google.com")
      :ok
      iex> fun.("url", "invalid_url")
      {:error, "The url field must be a valid URL."}
      iex> fun.("url", "https://dummy.test")
      {:error, "The url field must be a valid URL."}
  """
  def active_url do
    url_fn = url()

    fn attr, value ->
      message = gettext("The %{attribute} field must be a valid URL.", attribute: attr)

      case url_fn.(attr, value) do
        :ok ->
          %URI{host: host} = URI.parse(value)

          host
          |> String.to_charlist()
          |> :inet.gethostbyname()
          |> then(&check(match?({:ok, _}, &1), message))

        error ->
          error
      end
    end
  end

  @doc ~S"""
  ## Examples

      iex> import Request.Validator.Rules, only: [list: 0]
      iex> fun = list()
      iex> fun.("emails", 4)
      {:error, "The emails field must be a list."}
      iex> fun.("emails", ["a@b.com"])
      :ok
  """
  def list do
    fn attr, value ->
      message = gettext("The %{attribute} field must be a list.", attribute: attr)

      check(is_list(value), message)
    end
  end

  @doc ~S"""
  ## Examples

      iex> import Request.Validator.Rules, only: [map: 0, map: 1]
      iex> fun = map()
      iex> metadata = %{"a" => "b", "c" => "d"}
      iex> fun.("metadata", 4)
      {:error, "The metadata field must be a map."}
      iex> fun.("metadata", metadata)
      :ok
      iex> fun = map(["a", "c"])
      iex> fun.("metadata", metadata)
      :ok
      iex> fun.("metadata", Map.put(metadata, "e", "f"))
      {:error, "The metadata field must be a map."}
  """
  def map(keys \\ []) when is_list(keys) do
    validator_fn = fn keys, attr, value ->
      message = gettext("The %{attribute} field must be a map.", attribute: attr)

      cond =
        case keys do
          [] -> is_map(value)
          keys -> is_map(value) and diff_keys_empty?(value, keys)
        end

      check(cond, message)
    end

    &validator_fn.(keys, &1, &2)
  end

  @doc ~S"""
  ## Examples

      iex> import Request.Validator.Rules, only: [boolean: 0]
      iex> fun = boolean()
      iex> fun.("notify_me", true)
      :ok
      iex> fun.("notify_me", 2)
      {:error, "The notify_me field must be true or false."}
  """
  def boolean do
    acceptables = [true, false, "1", "0", 1, 0]

    fn attr, value ->
      message = gettext("The %{attribute} field must be true or false.", attribute: attr)

      check(value in acceptables, message)
    end
  end

  defp diff_keys_empty?(map, keys) when is_map(map) and is_list(keys) do
    map
    |> Map.keys()
    |> MapSet.new()
    |> MapSet.difference(MapSet.new(keys))
    |> Enum.empty?()
  end

  defp check_size_with_op(first, second, op, messages) do
    message =
      case messages do
        %{} -> messages[get_type(first)]
      end

    first
    |> get_size()
    |> op.(get_size(second))
    |> check(message)
  end

  defp check(cond, message) do
    case cond do
      true -> :ok
      false -> {:error, message}
    end
  end

  defp same_type?(a, b), do: get_type(a) == get_type(b)

  defp get_size(num) when is_number(num), do: num
  defp get_size(value) when is_binary(value), do: String.length(value)
  defp get_size(list) when is_list(list), do: Enum.count(list)
  defp get_size(nil), do: nil

  defp get_type(num) when is_number(num), do: :numeric
  defp get_type(value) when is_binary(value), do: :string
  defp get_type(list) when is_list(list), do: :list
  defp get_type(nil), do: nil
end
