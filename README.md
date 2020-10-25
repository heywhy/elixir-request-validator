# RequestValidator

A blazing fast request validator for your phoenix app, which validates a request body before hitting the request handler in the controller.

## Installation

The package can be installed by adding `request_validator` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:request_validator, "~> 0.3"}
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
        "email" => [:required, :email],
        "name" => [:required, :string],
        "password" => [:required, :string],
        "age" => [:required, :numeric, {:min, 18}]
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
        "email" => [:required, :email],
        "password" => [:required, :string]
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

## Custom Error Messages

In most cases you will probably specify your custom error messages in a language file with the help of [gettext](https://hexdocs.pm/gettext/). First of all, you will need to provide your own translator module.

```elixir
# lib/gettext.ex
defmodule App.Gettext do
  @moduledoc false
  use Gettext, otp_app: :web_app
end

# lib/validations/messages.ex
defmodule App.Validation.Messages do
  @moduledoc false
  use Request.Validator.Messages, gettext: App.Gettext
end

# config/config.exs
use Mix.Config

config :request_validator, :translator, App.Validation.Messages
```

## Custom Validation Rules

This library provides a variety of helpful rules, however, you might want to define some rules to house your validation logic. To achieve this, you need to create your own rules and validation messages module, see example/steps below;

```elixir
# lib/validations/rules.ex
defmodule App.Validation.Rules do
  use Request.Validator.Rules
  use App.Repo

  alias App.Repo

  def exists(value, {model, field}, fields) do
    from model, where: [{field, value}]
    |> Repo.exists
  end
end

# lib/validations/messages.ex
defmodule App.Validation.Messages do
  @moduledoc false
  use Request.Validator.Messages, gettext: App.Gettext

  ...

  def exists(attr, params) do
    dgettext("validations", "This %{field} doesn't exists.", field: attr)
  end
end
```

After the modules have been defined you will to set some configs to override the default modules used by the library.

```elixir
# config/config.exs
use Mix.Config

config :request_validator,
  rules: App.Validation.Rules,
  translator: App.Validation.Messages
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
        "email" => [:required, :email],
        "name" => [:required, :string],
        "age" => [:required, :numeric, {:min, 18}],
        "course" => [:required, :string, {:exists, {App.Course, :id}}]
      }
    end

    @impl Request.Validator
    @spec authorize(Plug.Conn.t()) :: boolean()
    def authorize(_), do: true
  end
```

## Rules

Below is a list of all available validation rules and their function:

### email

The field under validation must be formatted as an e-mail address

### {gt, *field*}

The field under validation must be greater than the given field. The two fields must be of the same type

### {lt, *field*}

The field under validation must be less than the given *field*. The two fields must be of the same type

### {max, *value*}

The field under validation must be less than or equal to a maximum *value*. Supported types are strings, numerics and list.

### {min, *value*}

The field under validation must have a minimum *value*. Supported types are strings, numerics and list.

### numeric

The field under validation must be numeric.

### required

The field under validation must be present in the input data and not empty. A field is considered "empty" if one of the following conditions are true:

- The value is nil.
- The value is an empty string.
- The value is an empty list or map.

### string

The field under validation must be a string.

## TODOS

- [] Include more validation rules
- [] Norm validation support
- [x] Ecto schema support

## License

RequestValidator is released under the MIT License - see the [LICENSE](LICENSE) file.
