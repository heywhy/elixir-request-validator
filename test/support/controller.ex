defmodule Controller do
  use Phoenix.Controller, formats: []
  use Request.Validator.Plug

  @validate RequestValidatorTest.RegisterRequest
  def index(conn, _params) do
    send_resp(conn, 200, "OK")
  end
end
