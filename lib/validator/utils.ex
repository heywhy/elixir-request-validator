defmodule Request.Validator.Utils do
  @spec to_atom(term()) :: atom()
  def to_atom(val) when is_atom(val), do: val

  def to_atom(val) when is_binary(val) do
    String.to_existing_atom(val)
  rescue
    ArgumentError -> String.to_atom(val)
  end
end
