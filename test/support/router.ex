defmodule Router do
  use Plug.Router

  import Request.Validator
  import Request.Validator.Rules

  plug(:match)

  plug(Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Jason
  )

  use Request.Validator.Plug

  plug(:dispatch)

  get "/hello" do
    send_resp(conn, 200, "world")
  end

  defmodule EchoRequest do
    use Request.Validator

    import Request.Validator.Rules

    def rules(_), do: %{"message" => ~V[required|string]}
  end

  @validate EchoRequest

  post "/echo" do
    %{"message" => message} = conn.params

    send_resp(conn, 200, message)
  end

  @validate %{"message" => ~V[required|string|min:2]}

  post "/send/:message" do
    %{"message" => message} = conn.params

    send_resp(conn, 200, message)
  end

  match _ do
    send_resp(conn, 404, "oops")
  end
end
