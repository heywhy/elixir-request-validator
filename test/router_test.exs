defmodule RouterTest do
  use ExUnit.Case, async: true

  import Plug.Test

  @opts Router.init([])

  test "/hello" do
    conn = conn(:get, "/hello") |> Router.call(@opts)

    assert conn.state == :sent
    assert conn.status == 200
    assert conn.resp_body == "world"
  end

  test "/echo" do
    conn =
      :post
      |> conn("/echo", %{message: "hi!"})
      |> Router.call(@opts)

    assert conn.state == :sent
    assert conn.status == 200
    assert conn.resp_body == "hi!"

    conn =
      :post
      |> conn("/echo", %{})
      |> Router.call(@opts)

    assert conn.state == :sent
    assert conn.status == 422
    assert conn.resp_body =~ "The message field is required."
  end

  test "/send/:message" do
    conn =
      :post
      |> conn("/send/hi!")
      |> Router.call(@opts)

    assert conn.state == :sent
    assert conn.status == 200
    assert conn.resp_body == "hi!"
  end
end
