# RequestValidator

A blazing fast request validator for your phoenix app, which validates a request body before hitting the request handler in the controller.

- [Why RequestValidator](#why-request-validator)
- [Installation](#installation)
- [Usage](#usage)
- [Ecto Support](#ecto-support)
- [Custom Validation Rules](#custom-validation-rules)

## Why RequestValidator

It's common for a web service to validate incoming data. The most common layer where this is done is at the controller level and this sometimes leads to having a bloated controller. But with RequestValidator, you move the validation logic to a layer just before the controller and your controller is now free from doing validation.

## Installation

The package can be installed by adding `request_validator` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:request_validator, "~> 0.5"}
  ]
end
```

## Usage

First of all, you need to define a validation schema to be used against the incoming data.

```elixir
defmodule App.Requests.Registration do
  use Request.Validator
  
  # Get the validation rules that apply to the incoming request.
  @impl Request.Validator
  def rules(_) do
    [
      email: ~w[required email]a,
      first_name: ~w[required string]a,
      last_name: ~w[required string]a,
      password: [:required, :string, {:min, 8}, :confirmed]
    ]
  end

  # Determine if the user is authorized to make this request.
  @impl Request.Validator
  def authorize(_), do: true
end
```

The above validation schema can now be used;

```elixir
defmodule App.UserController do
  use AppWeb, :controller

  plug Request.Validation.Plug,
    register: App.Requests.Registration

  def register(conn, params) do
    case App.UserService.create(params) do
      :ok ->
        conn
        |> put_status(201)
        |> json(%{message: "Account created successfully"})
      {:error, msg} ->
        conn
        |> put_status(500)
        |> json(%{message: msg})
    end
  end
end
```

As you can see in the controller, the `register` handler does not need to worry about validating the incoming request because `RequestValidator` will handle that automatically and send the right response if the request fails validation based on the given validation schema.

You can specify validation schema for each of the handlers in a controller:

```elixir
defmodule App.UserController do
  use AppWeb, :controller

  plug Request.Validation.Plug,
    login: App.Requests.Login,
    register: App.Requests.Registration

  ...
end
```

Full documentation can be found at [https://hexdocs.pm/request_validator](https://hexdocs.pm/request_validator).

## Ecto Support

In some cases, your application already makes use of the ecto library. I'm glad to tell you that this library has support when the rule method returns an `Ecto.Changeset` struct so that you can
make use of the advantages provided by this library without rewriting your validation logic. See the example below:

```elixir
defmodule App.SomeEctoSchema do
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field(:name, :string)
    field(:email, :string)
    field(:age, :integer)
    field(:password, :string)
  end

  @doc false
  def changeset(attrs), do: changeset(%__MODULE__{}, attrs)

  @doc false
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:name, :email, :age, :password])
    |> validate_required([:name, :email, :age, :password])
    |> validate_number(:age, less_than_or_equal_to: 32)
  end
end

defmodule App.Requests.TestRequest do
  use Request.Validator

  alias App.SomeEctoSchema

  @impl Request.Validator
  def rules(conn), do: SomeEctoSchema.changeset(conn.params)

  @impl Request.Validator
  def authorize(_), do: true
end
```

## Custom Validation Rules

This library provides a variety of helpful rules, however, you might want to define some rules to house your validation logic. To achieve this, you need to create your own rules module, extend the default rules and update the library configuration;

```elixir
defmodule App.Validation.Rules do
  use Request.Validator.Rules # grab default rules provided by the library

  @spec uppercase(binary(), keyword()) :: :ok | {:error, binary()}
  def uppercase(value, fields: _fields, field: _field) do
    case String.upcase(value) do
      ^value ->
        :ok
      _ ->
        {:error, "This field must be uppercase."}
    end
  end
end
```

After defining a module with your custom rules, you will need to update your application configuration:

```elixir
config :request_validator, rules_module: App.Validation.Rules
```

Once the new rule has been added and configuration updated, it can now be used:

```elixir
# ...
  def rules(_) do
    [
      name: ~w[required string uppercase]a
    ]
  end
# ...
```

Note that if your rule accepts options/parameters, its function definition should have an arity of 3, and the second argument will be the option provided when the rule is used, ex: `{:custom_rule, options}`

## TODOS

- [ ] Include more validation rules
- [ ] Norm validation support
- [x] Ecto schema support

## License

RequestValidator is released under the MIT License - see the [LICENSE](LICENSE) file.
