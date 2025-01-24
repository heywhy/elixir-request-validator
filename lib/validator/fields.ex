defmodule Request.Validator.Fields do
  alias Request.Validator.Utils

  defstruct data: %{}

  @type t :: %__MODULE__{
          data: map()
        }

  @behaviour Access

  @spec new(map()) :: t()
  def new(data) when is_map(data) do
    struct!(__MODULE__, data: data)
  end

  @impl true
  def fetch(%__MODULE__{data: data}, key) do
    key
    |> Utils.convert_to_path()
    |> then(&get_in(data, &1))
    |> then(&{:ok, &1})
  rescue
    FunctionClauseError -> {:ok, nil}
  end

  @impl true
  def get_and_update(_data, _key, _function), do: throw(:not_implemented)

  @impl true
  def pop(_data, _key), do: throw(:not_implemented)
end
