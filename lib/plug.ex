defmodule Request.Validator.Plug do
  alias Plug.Conn
  alias Request.Validator

  import Plug.Conn

  @doc ~S"""
  Init the Request.Validator.Plug with an optional error callback
  and handlers with their corresponding request validator module.
  ```elixir
  plug Request.Validator.Plug,
    register: App.Requests.RegisterRequest,
    on_error: fn conn, errors -> json_resp(conn, "Handle your errors: #{inspect errors}") end
  ```
  """
  def init(opts) when is_map(opts), do: init(Keyword.new(opts))

  def init(opts) do
    opts
    |> Keyword.put_new(:on_error, &Validator.Plug.on_error/2)
  end

  @doc ~S"""
  The default callback to be invoked when there is a param that fails validation.
  """
  def on_error(conn, errors) do
    json_resp(conn, 422, %{message: "Unprocessable entity", errors: errors}) |> halt()
  end

  defp unauthorized(conn) do
    json_resp(conn, 403, %{message: "Forbidden"}) |> halt
  end

  @doc ~S"""
  Performs validations on `conn.params`
  If all validations are successful returns the connection struct
  Otherwise returns an error map in the following structure: `%{param: ["some error", ...]}`
  Will call the given `on_error` callback in case some validation failed
  """
  def call(conn, opts) do
    with action <- Map.get(conn.private, :phoenix_action),
         module <- get_validator(opts, action),
         false <- is_nil(module),
         {:authorized, true} <- {:authorized, module.authorize(conn)},
         :ok <- module.validate(Conn.fetch_query_params(conn)) do
      conn
    else
      {:authorized, false} ->
        unauthorized(conn)

      {:error, errors} when is_map(errors) ->
        opts[:on_error].(conn, errors)

      _ ->
        conn
    end
  end

  defp get_validator(opt, key) when is_map(opt), do: Map.get(opt, key)
  defp get_validator(opt, key) when is_list(opt), do: Keyword.get(opt, key)

  defp json_resp(conn, status, body) do
    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(status, json_library().encode_to_iodata!(body))
  end

  defp json_library do
    Application.get_env(:request_validator, :json_library, Jason)
  end
end
