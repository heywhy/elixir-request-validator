defmodule Request.Validator.Messages do
  defmacro __using__([gettext: backend] = _opts) do
    quote do
      @before_compile Request.Validator.Messages

      # import Gettext backend
      import unquote(backend)

      def get_message(rule, attr, params \\ [])
      def get_message(rule, attr, params) when is_binary(rule),
        do: String.replace(rule, ":", "") |> String.to_atom

      def get_message(method, attr, params) do
        if function_exported?(__MODULE__, method, 2) do
          apply(__MODULE__, method, [attr, params])
        else
          raise ArgumentError, message: "no provided validation message for rule [#{method}]"
        end
      end
    end
  end

  defmacro __before_compile__(_) do
    mod = __CALLER__.module

    quote bind_quoted: [mod: mod] do
      def required(attr, _) do
        dgettext("validations", "The %{field} is required.", field: attr)
      end

      def numeric(attr, _) do
        dgettext("validations", "The %{field} must be a number.", field: attr)
      end

      def email(attr, params), do: is_email(attr, params)
      def is_email(attr, _) do
        dgettext("validations", "The %{field} is an invalid email or doesn't exists.", field: attr)
      end

      def string(attr, params), do: is_binary(attr, params)
      def is_binary(attr, _) do
        dgettext("validations", "The %{field} must be a string.", field: attr)
      end

      def lt(attr, params), do: is_lt(attr, params)
      def is_lt(attr, params) do
        {value, min} = params
        cond do
          is_binary(value) ->
            dgettext("validations", "The %{field} must be less than %{min} characters.", field: attr, min: min)
          is_list(value) ->
            dgettext("validations", "The %{field} must be less than %{min} items.", field: attr, min: min)
          true ->
            dgettext("validations", "The %{field} must be less than %{min}.", field: attr, min: min)
        end
      end

      def gt(attr, params), do: is_gt(attr, params)
      def is_gt(attr, params) do
        {value, max} = params
        cond do
          is_binary(value) ->
            dgettext("validations", "The %{field} must be greater than %{max} characters.", field: attr, max: max)
          is_list(value) ->
            dgettext("validations", "The %{field} must be more than %{max} items.", field: attr, max: max)
          true ->
            dgettext("validations", "The %{field} must be greater than %{max}.", field: attr, max: max)
        end
      end

      def max(attr, params), do: is_max(attr, params)
      def is_max(attr, params) do
        {value, max} = params
        cond do
          is_binary(value) ->
            dgettext("validations", "The %{field} may not be greater than %{max} characters.", field: attr, max: max)
          is_list(value) ->
            dgettext("validations", "The %{field} may not have more than %{max} items.", field: attr, max: max)
          true ->
            dgettext("validations", "The %{field} may not be greater than %{max}.", field: attr, max: max)
        end
      end

      def min(attr, params), do: is_min(attr, params)
      def is_min(attr, params) do
        {value, min} = params
        cond do
          is_binary(value) ->
            dgettext("validations", "The %{field} must be at least %{min} characters.", field: attr, min: min)
          is_list(value) ->
            dgettext("validations", "The %{field} must be at least %{min} items.", field: attr, min: min)
          true ->
            dgettext("validations", "The %{field} must be at least %{min}.", field: attr, min: min)
        end
      end
    end
  end
end
