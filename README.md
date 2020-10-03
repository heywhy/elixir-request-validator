# RequestValidator

A blazing fast request validator for your phoenix app, which validates a request body before hitting the request handler in the controller.

## Installation

The package can be installed by adding `request_validator` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:request_validator, "~> 0.1.1"}
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
    @behaviour Request.Validator

    @impl Request.Validator
    @spec rules(Plug.Conn.t()) :: map()|keyword()
    def rules(_) do
      %{
        age: [:required, :numeric],
        email: [:required, :email],
        name: [:required, :string],
        password: [:required, :string],
      }
    end

    @impl Request.Validator
    @spec authorize(Plug.Conn.t()) :: boolean()
    def authorize(_), do: true
  end

  defmodule App.Requests.Login do
    @behaviour Request.Validator

    @impl Request.Validator
    @spec rules(Plug.Conn.t()) :: map()|keyword()
    def rules(_) do
      %{
        email: [:required, :email],
        password: [:required, :string],
      }
    end

    @impl Request.Validator
    @spec authorize(Plug.Conn.t()) :: boolean()
    def authorize(_), do: true
  end
```

Full documentation can be found at [https://hexdocs.pm/request_validator](https://hexdocs.pm/request_validator).

## License

RequestValidator is released under the MIT License - see the [LICENSE](LICENSE) file.
