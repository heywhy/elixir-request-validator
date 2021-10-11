defmodule RequestValidator.RulesTest do
  use ExUnit.Case

  alias Request.Validator.DefaultRules, as: Rules

  describe "default rules" do
    test "email/2" do
      assert :ok = Rules.email("person@mail.com")

      assert {:error, "This field must be a valid email address."} = Rules.email(12)
      assert {:error, "This field must be a valid email address."} = Rules.email([])
      assert {:error, "This field must be a valid email address."} = Rules.email(nil)
      assert {:error, "This field must be a valid email address."} = Rules.email("invalid email")
    end

    test "required/2" do
      assert :ok = Rules.required([1])
      assert :ok = Rules.required(%{a: 1})
      assert :ok = Rules.required(1212)
      assert :ok = Rules.required("random")
      assert :ok = Rules.required(false)
      assert {:error, "This field is required."} = Rules.required([])
      assert {:error, "This field is required."} = Rules.required(%{})
      assert {:error, "This field is required."} = Rules.required("")
      assert {:error, "This field is required."} = Rules.required(nil)
    end

    test "string/2" do
      assert :ok = Rules.string("random 12")
      assert {:error, "This field must be a string."} = Rules.string(nil)
      assert {:error, "This field must be a string."} = Rules.string(1212)
    end

    test "numeric/2" do
      assert :ok = Rules.numeric(112)
      assert :ok = Rules.numeric(-112)
      assert {:error, "This field must be a number."} = Rules.numeric("1212")
    end

    test "max/3" do
      assert :ok = Rules.max(112, 120)
      assert :ok = Rules.max("hell", 5)
      assert :ok = Rules.max([1, 2, 3], 5)
      assert {:error, "This field must be less than or equal 50."} = Rules.max(100, 50)

      assert {:error, "This field must be less than or equal 3 characters."} =
               Rules.max("1090", 3)

      assert {:error, "This field must be less than or equal 2 items."} =
               Rules.max([1, 2, 3, 4, 5], 2)
    end

    test "min/3" do
      assert :ok = Rules.min(120, 120)
      assert :ok = Rules.min("hello0", 5)
      assert :ok = Rules.min([1, 2, 3, 4, 6], 3)
      assert {:error, "This field must be at least 50."} = Rules.min(10, 50)
      assert {:error, "This field must be at least 9 characters."} = Rules.min("10b", 9)
      assert {:error, "This field must be at least 5 items."} = Rules.min([1, 2, 3], 5)
    end

    test "gt/3" do
      assert :ok = Rules.gt(120, :age, fields: %{"age" => 20})
      assert :ok = Rules.gt(2002, :year, fields: %{"year" => 2001})
      assert :ok = Rules.gt("hello0", :name, fields: %{"name" => ""})
      assert :ok = Rules.gt(["a", "b", "c"], :name, fields: %{"name" => ["jake", "jude"]})

      assert {:error, "This field and name has to be of same type."} =
               Rules.gt("hello0", :name, fields: %{})

      assert {:error, "This field must have more than 11 characters."} =
               Rules.gt("hello0", :note, fields: %{"note" => "random note"})
    end

    test "lt/3" do
      assert :ok = Rules.lt(12, :age, fields: %{"age" => 20})
      assert :ok = Rules.lt(2000, :year, fields: %{"year" => 2001})
      assert :ok = Rules.lt("35", :name, fields: %{"name" => "johnson"})

      assert {:error, "This field and name has to be of same type."} =
               Rules.lt("hello0", :name, fields: %{})

      assert {:error, "This field must have less than 11 characters."} =
               Rules.lt("lorem ipsum checking things", :note, fields: %{"note" => "random note"})
    end

    test "map/2" do
      assert :ok = Rules.map(%{})
      assert {:error, "This field is expected to be a map."} = Rules.map(12)
      assert {:error, "This field is expected to be a map."} = Rules.map([])
    end

    test "confirmed/2" do
      assert :ok =
               Rules.confirmed("password",
                 field: :password,
                 fields: %{"password_confirmation" => "password"}
               )

      assert :ok = Rules.confirmed(1234, field: :amount, fields: %{"amount_confirmation" => 1234})

      assert {:error, "This field confirmation does not match."} =
               Rules.confirmed(1234, field: :amount, fields: %{})

      assert {:error, "This field confirmation does not match."} =
               Rules.confirmed(1234, field: :amount, fields: %{"amount_confirmation" => 123_423})
    end

    test "size/2" do
      assert :ok = Rules.size("hello", 5)
      assert :ok = Rules.size(1123, 1123)
      assert :ok = Rules.size([1, 2, 3], 3)
      assert {:error, "This field must be 230."} = Rules.size(160, 230)
      assert {:error, "This field must be 4 characters."} = Rules.size("545627", 4)
      assert {:error, "This field must contain 4 items."} = Rules.size([1, 2, 3], 4)
    end

    test "in_list/2" do
      assert :ok = Rules.in_list("hello", ~w[hello world])
      assert :ok = Rules.in_list("business", ~w[law business hospital])
      assert :ok = Rules.in_list(22, [118, 22, 332, 54])
      assert {:error, "This field is invalid."} = Rules.in_list(nil, ~w[a b c])
      assert {:error, "This field is invalid."} = Rules.in_list(11, ~w[a b c 11 d])
    end

    test "boolean/2" do
      assert :ok = Rules.boolean(1)
      assert :ok = Rules.boolean(0)
      assert :ok = Rules.boolean("1")
      assert :ok = Rules.boolean("0")
      assert :ok = Rules.boolean(true)
      assert :ok = Rules.boolean(false)
      assert {:error, "This field must be true or false"} = Rules.boolean("2")
    end

    test "url/2" do
      assert :ok = Rules.url("https://my.app")
      assert :ok = Rules.url("https://test.app/webhook")
      assert :ok = Rules.url("https://test-23.app/webhook")
      assert {:error, "This field must be a valid URL."} = Rules.url(nil)
      assert {:error, "This field must be a valid URL."} = Rules.url("//elixir-lang.com")
    end

    test "active_url/2" do
      assert :ok = Rules.active_url("https://google.com/search")
      assert :ok = Rules.active_url("https://elixir-lang.org")
      assert {:error, "This field is not a valid URL."} = Rules.active_url(nil)
      assert {:error, "This field is not a valid URL."} = Rules.active_url("//elixir-lang.com")
    end

    test "file/2" do
      file = Plug.Upload.random_file!("request_validator_test")

      assert :ok = Rules.file(%Plug.Upload{path: file, filename: "test.png"})
      assert {:error, "This field must be a file."} = Rules.file(nil)
    end
  end
end
