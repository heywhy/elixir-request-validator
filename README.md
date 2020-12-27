# RequestValidator

A blazing fast request validator for your phoenix app, which validates a request body before hitting the request handler in the controller.

## Installation

The package can be installed by adding `request_validator` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:request_validator, "~> 0.4"}
  ]
end
```

## Basic Usage

```elixir
  defmodule App.UserController do
    use AppWeb, :controller

    plug Request.Validation.Plug, %{
      login: App.Requests.Login,
      register: App.Requests.Registration
    }

    def login(conn, params) do
      ...
    end

    def register(conn, params) do
      ...
    end
  end

  defmodule App.Requests.Registration do
    use Request.Validator
    
    @behaviour Request.Validator

    @impl Request.Validator
    @spec rules(Plug.Conn.t()) :: map()|keyword()
    def rules(_) do
      %{
        "email" => [is_required(), is_email()],
        "name" => [is_required(), is_string()],
        "password" => [is_required(), is_string()],
        "age" => [is_required(), is_numeric(), is_min(18)]
      }
    end

    @impl Request.Validator
    @spec authorize(Plug.Conn.t()) :: boolean()
    def authorize(_), do: true
  end

  defmodule App.Requests.Login do
    use Request.Validator
    
    @behaviour Request.Validator

    @impl Request.Validator
    @spec rules(Plug.Conn.t()) :: map()|keyword()
    def rules(_) do
      %{
        "email" => [is_required(), is_email()],
        "password" => [is_required(), is_string()]
      }
    end

    @impl Request.Validator
    @spec authorize(Plug.Conn.t()) :: boolean()
    def authorize(_), do: true
  end
```

Full documentation can be found at [https://hexdocs.pm/request_validator](https://hexdocs.pm/request_validator).

## Ecto Support

In some cases, your application already makes use of the ecto library. I'm glad to tell you that this library has support when the rule method returns a `Ecto.Changeset` struct, so that you can
make use of the advantages provided by this library without rewritting your validation logic. See example below:

```elixir
defmodule App.Requests.TestRequest do
  use Request.Validator
  use Ecto.Schema

  alias App.Requests.TestRequest

  import Ecto.Changeset

  @behaviour Request.Validator

  embedded_schema do
    field(:name, :string)
    field(:email, :string)
    field(:age, :integer)
    field(:password, :string)
  end

  @doc false
  defp changeset(contact, attrs) do
    contact
    |> cast(attrs, [:name, :email, :age, :password])
    |> validate_required([:name, :email, :age, :password])
    |> validate_number(:age, less_than_or_equal_to: 32)
  end

  @impl Request.Validator
  def rules(conn) do
    %TestRequest{} |> changeset(conn.params)
  end

  @impl Request.Validator
  @spec authorize(Plug.Conn.t())::boolean()
  def authorize(_), do: true
end
```

## Custom Validation Rules

This library provides a variety of helpful rules, however, you might want to define some rules to house your validation logic. To achieve this, you need to create your own rules and validation messages module, see example/steps below;

```elixir
# lib/validations/rules.ex
defmodule App.Validation.Rules do
  alias App.Repo

  require Request.Validator.Helper

  import Ecto.Query
  import Request.Validator.Helper

  with_param(:exists, fn ({model, field}, value, _) ->
    result =
      from(m in model, where: field(m, ^field) == ^value)
      |> Repo.exists?()

    case result do
      true ->
        :ok
      _ ->
        {:error, "This field doesn't exists."}
    end
  end)

  with_param(:unique, fn(params, value, _) ->
    case exists(params).(value, nil) do
      :ok ->
        {:error, "This field has already been taken."}
      {:error, _} ->
        :ok
    end
  end)
end

```

After adding the rule which is a method, then you can make use of the rule in any of your request validator module.

```elixir
  defmodule App.Requests.CourseRegistration do
    use Request.Validator
    
    @behaviour Request.Validator

    @impl Request.Validator
    @spec rules(Plug.Conn.t()) :: map()|keyword()
    def rules(_) do
      %{
        "email" => [is_required(), is_email()],
        "name" => [is_required(), is_string()],
        "age" => [is_required(), is_numeric(), is_min(18)],
        "course" => [is_required(), is_string(), exists({App.Course, :id})]
      }
    end

    @impl Request.Validator
    @spec authorize(Plug.Conn.t()) :: boolean()
    def authorize(_), do: true
  end
```

**NB:** You should use the `define_rule` macro if your validation function doesn't accept argument like the `exists` rule. And you can also define a function directly and reference using *function capturing*, e.g. `&rule_validator/2`.

## Rules

Below is a list of all available validation rules and their function:

### is_confirmed()

The field under validation must have a matching field of `bar_confirmation`. For example, if the field under validation is `password`, a matching `password_confirmation` field must be present in the input.


### is_email

The field under validation must be formatted as an e-mail address

### is_gt(*field*)

The field under validation must be greater than the given field. The two fields must be of the same type

### is_lt(*field*)

The field under validation must be less than the given *field*. The two fields must be of the same type

### is_max(*value*)

The field under validation must be less than or equal to a maximum *value*. Supported types are strings, numerics and list.

### is_min(*value*)

The field under validation must have a minimum *value*. Supported types are strings, numerics and list.

### is_numeric()

The field under validation must be numeric.

### is_required()

The field under validation must be present in the input data and not empty. A field is considered "empty" if one of the following conditions are true:

- The value is nil.
- The value is an empty string.
- The value is an empty list or map.

### is_string()

The field under validation must be a string.

## TODOS

- [ ] Include more validation rules
- [ ] Norm validation support
- [x] Ecto schema support

## License

RequestValidator is released under the MIT License - see the [LICENSE](LICENSE) file.
