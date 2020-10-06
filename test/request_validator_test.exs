defmodule RequestValidatorTest do
  use ExUnit.Case
  use Plug.Test

  alias Plug.Conn
  alias Request.Validator.Plug, as: ValidationPlug
  alias RequestValidatorTest.RegisterRequest

  require RequestValidatorTest.RegisterRequest

  Application.put_env(:request_validator, :translator, RequestValidatorTest.Messages)

  @opts ValidationPlug.init(%{register: RegisterRequest})

  test "fails request validations" do
    conn =
      conn(:post, "/api/hello", Jason.encode!(%{}))
      |> Conn.put_req_header("content-type", "application/json")
      |> Conn.put_private(:phoenix_action, :register)
      |> ValidationPlug.call(@opts)

    assert conn.state == :sent
    assert conn.status == 422
  end

  test "passes request validations" do
    params = %{
      email: "test@gmail.com",
      password: "password",
      name: "john doe",
      age: 31
    }
    conn =
      conn(:post, "/api/hello", params)
      |> Conn.put_private(:phoenix_action, :register)
      |> ValidationPlug.call(@opts)

    assert conn.state == :unset
    assert conn.status == nil
  end
end
