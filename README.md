# RequestValidator

A blazing fast request validator for your phoenix and bared plug app, which validates a request body before hitting the request handler in the controller.

- [Why RequestValidator](#why-request-validator)
- [Installation](#installation)
- [Usage](#usage)
- [Custom Validation Rules](#custom-validation-rules)

## Why RequestValidator

It's common for a web service to validate incoming data. The most common layer where this is done is at the controller level and this sometimes leads to having a bloated controller. But with RequestValidator, you move the validation logic to a layer just before the controller and your controller is now free from doing validation.

## Installation

The package can be installed by adding `request_validator` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:request_validator, "~> 1.0.0-rc.0"}
  ]
end
```

## Usage

First of all, you need to define a validation schema to be used against the incoming data.

```elixir
defmodule App.Requests.Registration do
  use Request.Validator

  import Request.Validator.Rules

  # Get the validation rules that apply to the incoming request.
  @impl Request.Validator
  def rules(_) do
    %{
      "email" => ~V[required|email],
      "first_name" => ~V[required|string],
      "last_name" => ~V[required|string],
      "password" => ~V[required|string|min:8|confirmed]
    }
  end

  # Determine if the user is authorized to make this request.
  @impl Request.Validator
  def authorize?(_), do: true
end
```

The above validation schema can now be used;

```elixir
defmodule App.UserController do
  use AppWeb, :controller
  use Request.Validator.Plug

  @validate App.Requests.Registration
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
  use Request.Validator.Plug

  @validate App.Requests.Login
  def login(conn, params) do
    # ...
  end

  @validate App.Requests.Registration
  def register(conn, params) do
    # ...
  end
end
```

Full documentation can be found at [https://hexdocs.pm/request_validator](https://hexdocs.pm/request_validator).

## Custom Validation Rules

This library provides a variety of helpful rules, however, you might want to define some rules to house your validation logic. To achieve this, you need to create your own rules module;

```elixir
defmodule App.Validation.Rules do
  import Request.Validator.Rules

  alias Request.Validator.Rules

  @spec uppercase() :: Rules.validator()
  def uppercase do
    fn attr, value ->
      message = gettext("The %{attribute} field must be uppercase.", attribute: attr)

      case String.upcase(value) == value do
        true -> :ok
        false -> {:error, message}
      end
    end
  end
end
```

To use, you simply import your custom rules and;

```elixir
import Request.Validator.Rules
import App.Validation.Rules

# ...
  def rules(_) do
    %{
      "name" => ~V[required|string|uppercase],
      "age" => ~V[required|integer],
      "parent" => [required_if("age", 18, &Kernel.<=/2), upppercase()]
    }
  end
# ...
```

## Available Rules

Find rules [here](#Request.Validator.Rules).

## Validating Nested Input

Validating nested map input shouldn't be a problem. For example the HTTP request contains `address` field which is a map with nested attributes (`line1`, `line2`...), you may validate it like so:

```elixir
%{
  "address.line1" => ~V[required|string|max:100],
  "address.city" => ~V[required|string|max:50],
  "address.zip_code" => ~V[required|string|max:10],
  "address.country" => ~V[required|string|max:60],
  "address.line2" => ~V[string|max:100],
  "address.state" => ~V[string|max:50]
}
```

In the case where you want to validate elements nested in a list, you should use the `*` character;

```elixir
# request
%{
  "likes" => ["epl", "laliga"],
  "documents" => [%{"type" => "selfie"}, %{"type" => "id", "issuing_country" => "US"}]
}

# rules
%{
  "likes" => ~V[required|list|min:1],
  "likes.*" => ~V[required|allowed:epl,laliga],
  "document" => ~V[required|list|min:2],
  "documents.*.type" => ~V[required|allowed:selfie,id]
}
```

## TODOS

- [ ] Include more validation rules
- [ ] Norm validation support

## License

RequestValidator is released under the MIT License - see the [LICENSE](LICENSE) file.
