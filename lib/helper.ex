defmodule Request.Validator.Helper do
  alias Request.Validator.Rules.Map_

  @doc """
  iex> Request.Validator.Helper.in_list(["male", "female"])
  {:in_list, ~w[male female]}
  iex> Request.Validator.Helper.in_list(~w[tech law finance])
  {:in_list, ["tech", "law", "finance"]}
  iex> Request.Validator.Helper.in_list(~w[doctor nurse nurse midwife specialist midwife doctor])
  {:in_list, ~w[doctor nurse midwife specialist]}
  """
  @spec in_list(list(any())) :: {:in_list, list(any())}
  def in_list(items) when is_list(items), do: {:in_list, Enum.uniq(items)}

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
  iex> Request.Validator.Helper.required(:string)
  ~w[required string]a
  iex> Request.Validator.Helper.required([:string, :email, {:max, 100}])
  [:required, :string, :email, {:max, 100}]
  iex> Request.Validator.Helper.required({:max, 100})
  [:required, {:max, 100}]
  """
  def required(rule) when is_atom(rule), do: required([rule])
  def required(rule) when is_tuple(rule), do: required([rule])
  def required(rules) when is_list(rules), do: [:required] ++ rules

  @doc """
  iex> Request.Validator.Helper.size(30)
  {:size, 30}
  iex> Request.Validator.Helper.size(40)
  {:size, 40}
  """
  @spec size(number()) :: {:size, number()}
  def size(boundary), do: {:size, boundary}

  @doc """
  iex> alias Request.Validator.{Helper, Rules}
  [Request.Validator.Helper, Request.Validator.Rules]
  iex> Helper.nullable(Rules.map(name: ~w[required string]a))
  %Rules.Map_{attrs: [name: ~w[required string]a], nullable: true}
  iex> Rules.map(name: ~w[required string]a)
  %Rules.Map_{attrs: [name: ~w[required string]a], nullable: false}
  """
  def nullable(%Map_{} = map), do: struct!(map, %{nullable: true})

  @doc """
  iex> alias Request.Validator.Helper
  Request.Validator.Helper
  iex> {:unique, _} = Helper.unique(&(&1 == 10))
  """
  def unique(callback), do: {:unique, callback}
end
