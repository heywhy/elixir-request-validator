defmodule Request.Validator.Helper do
  @doc """
  iex> Request.Validator.Helper.gt(:age)
  {:gt, :age}
  iex> Request.Validator.Helper.gt(:year)
  {:gt, :year}
  """
  @spec gt(atom()) :: {:gt, atom()}
  def gt(field), do: {:gt, field}

  @doc """
  iex> Request.Validator.Helper.lt(:age)
  {:lt, :age}
  iex> Request.Validator.Helper.lt(:year)
  {:lt, :year}
  """
  @spec lt(atom()) :: {:lt, atom()}
  def lt(field), do: {:lt, field}

  @doc """
  iex> Request.Validator.Helper.max(30)
  {:max, 30}
  iex> Request.Validator.Helper.max(40)
  {:max, 40}
  """
  @spec max(number()) :: {:max, number()}
  def max(boundary) when is_number(boundary), do: {:max, boundary}

  @doc """
  iex> Request.Validator.Helper.min(30)
  {:min, 30}
  iex> Request.Validator.Helper.min(40)
  {:min, 40}
  """
  @spec min(number()) :: {:min, number()}
  def min(boundary), do: {:min, boundary}

  @doc """
  iex> Request.Validator.Helper.size(30)
  {:size, 30}
  iex> Request.Validator.Helper.size(40)
  {:size, 40}
  """
  @spec size(number()) :: {:size, number()}
  def size(boundary), do: {:size, boundary}
end
