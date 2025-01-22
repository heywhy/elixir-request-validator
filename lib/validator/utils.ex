defmodule Request.Validator.Utils do
  @spec to_atom(term()) :: atom()
  def to_atom(val) when is_atom(val), do: val

  def to_atom(val) when is_binary(val) do
    String.to_existing_atom(val)
  rescue
    ArgumentError -> String.to_atom(val)
  end

  @spec convert_to_path(String.t()) :: [term()]
  def convert_to_path(path, acc \\ [])

  def convert_to_path(path, acc) when is_binary(path) do
    path
    |> String.split(".")
    |> convert_to_path(acc)
  end

  def convert_to_path([], acc), do: Enum.reverse(acc)

  def convert_to_path([h | rest], acc) do
    h =
      case Integer.parse(h) do
        {num, ""} -> Access.at(num)
        _ -> h
      end

    convert_to_path(rest, [h] ++ acc)
  end
end
