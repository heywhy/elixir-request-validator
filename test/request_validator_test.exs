defmodule RequestValidatorTest do
  use ExUnit.Case
  use Plug.Test

  alias Plug.Conn
  alias Request.Validator.Plug, as: ValidationPlug
  alias RequestValidatorTest.RegisterRequest
  alias RequestValidatorTest.StrictRequest

  doctest(Request.Validator)

  @opts ValidationPlug.init(
          register: RegisterRequest,
          strict: StrictRequest
        )

  test "fails request validations" do
    conn =
      conn(:post, "/api/hello", %{})
      |> Conn.put_req_header("content-type", "application/json")
      |> Conn.put_private(:phoenix_action, :register)
      |> ValidationPlug.call(@opts)

    assert conn.state == :sent
    assert conn.status == 422
    assert conn.resp_body =~ "email"
    assert conn.resp_body =~ "field is required"
  end

  test "fails map validation" do
    params = %{
      address: %{
        country: "US"
      },
      documents: [
        "hello",
        %{tags: [1, 2, 3]},
        %{tags: ["v", "i", "n"]},
        %{}
      ]
    }

    conn =
      conn(:post, "/api/hello", params)
      |> Conn.put_req_header("content-type", "application/json")
      |> Conn.put_private(:phoenix_action, :register)
      |> ValidationPlug.call(@opts)

    assert conn.state == :sent
    assert conn.status == 422
    assert conn.resp_body =~ "field is required"
    assert conn.resp_body =~ "address.line1"
    refute conn.resp_body =~ "address.country"
    assert conn.resp_body =~ "The documents.0.name field is required."
    assert conn.resp_body =~ "The documents.1.tags.0 field must be a string."
    refute conn.resp_body =~ "The documents.2.tags.0 field must be a string."
    assert conn.resp_body =~ "The documents.3.tags field is required."
  end

  test "passes request validations" do
    params = %{
      password_confirmation: "password",
      email: "test@gmail.com",
      password: "password",
      name: "john doe",
      age: 31,
      year: 1995,
      mother_age: 32,
      gender: "male",
      address: %{
        line1: "anywhere on earth",
        city: "Lagos",
        country: "NGA"
      },
      documents: [
        %{name: "document.pdf", type: "certificate", tags: ["poi"]}
      ]
    }

    conn =
      conn(:post, "/api/hello", params)
      |> Conn.put_private(:phoenix_action, :register)
      |> ValidationPlug.call(@opts)

    assert conn.state == :unset
    assert conn.resp_body == nil
    assert conn.status == nil
  end

  test "fails request validation when undeclared fields are passed to a strict request" do
    conn =
      :post
      |> conn("/api/hello", %{email: 123, random_field: "Lorem"})
      |> Conn.put_private(:phoenix_action, :strict)
      |> ValidationPlug.call(@opts)

    assert conn.state == :sent
    assert conn.resp_body =~ "This field is unknown"
    assert conn.resp_body =~ "random_field"
    assert conn.status == 422
  end

  test "pass ecto validation support" do
    params = %{
      email: "test@gmail.com",
      password: "password",
      name: "john doe",
      age: 31
    }

    conn =
      conn(:post, "/api/hello", params)
      |> Conn.put_req_header("content-type", "application/json")
      |> Conn.put_private(:phoenix_action, :ecto_rules)
      |> ValidationPlug.call(@opts)

    assert conn.state == :unset
    assert conn.resp_body == nil
    assert conn.status == nil
  end
end
