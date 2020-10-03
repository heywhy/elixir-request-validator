defmodule Request.Validator do
  @moduledoc false

  @doc ~S"""
  Get the validation rules that apply to the request.
  """
  @callback rules(Plug.Conn.t()) :: map()|keyword()

  @doc ~S"""
  Determine if the user is authorized to make this request.
  """
  @callback authorize(Plug.Conn.t()) :: boolean()
end
