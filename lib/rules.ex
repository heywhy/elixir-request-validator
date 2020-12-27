defmodule Request.Validator.Rules do
  require Request.Validator.Helper

  import Request.Validator.Helper

  defmodule Bail do
    defstruct rules: []
  end

  def bail(rules), do: %__MODULE__.Bail{rules: rules}

  define_rule(:is_email, fn(value, _) ->
    validate(EmailChecker.valid?(value || ""), "This field must be a valid email address.")
  end)

  define_rule(:is_required, fn(value, _) ->
    result =
      is_list(value) ||
      is_number(value) ||
      !is_nil(value) && String.length(value) > 0

    validate(result, "This field is required")
  end)

  define_rule(:is_string, fn(value, _) ->
    validate(is_binary(value), "This field must be a string.")
  end)

  define_rule(:is_numeric, fn(value, _) ->
    validate(is_number(value), "This field must be a number.")
  end)

  with_param(:is_max, fn(max, value, _) when is_number(max) ->
    cond do
      is_binary(value) ->
        validate(String.length(value) <= max, "This field must be greater than #{max} characters.")
      is_list(value) ->
        validate(Enum.count(value) <= max, "This field must be more than #{max} items.")
      true ->
        validate(value <= max, "This field must be greater than #{max} characters.")
    end
  end)

  with_param(:is_min, fn(min, value, _) when is_number(min) ->
    cond do
      is_binary(value) ->
        validate(String.length(value) >= min, "This field must be at least #{min} characters.")
      is_list(value) ->
        validate(Enum.count(value) >= min, "This field must be at least #{min} items.")
      true ->
        validate(value >= min, "This field must be at least #{min}.")
    end
  end)

  with_param(:is_gt, fn(min, value, _) ->
    msg =
      cond do
        is_binary(value) ->
          "This field must be greater than #{min} characters."
        is_list(value) ->
          "This field must have more than #{min} items."
        true ->
          "This field must be greater than #{min}."
      end

    validate(value > min, msg)
  end)

  with_param(:is_lt, fn(max, value, _) ->
    msg =
      cond do
        is_binary(value) ->
          "This field must be less than #{max} characters."
        is_list(value) ->
          "This field must have more than #{max} items."
        true ->
          "This field must be less than #{max}."
      end

    validate(max > value, msg)
  end)

  define_rule(:is_confirmed, fn(value, field: field, fields: fields) ->
    path = "#{field}_confirmation"

    validate(value == fields[path], "This field and #{path} must match.")
  end)

  defp validate(condition, msg) do
    if !condition do
      {:error, msg}
    else
      :ok
    end
  end
end
