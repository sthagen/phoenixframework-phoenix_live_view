defmodule Phoenix.LiveView.HelpersTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveView.Helpers
  import Phoenix.HTML.Form

  defp render(template) do
    template
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end

  describe "link patch" do
    test "basic usage" do
      assigns = %{}
      dom = render(~H|<.link patch="/home">text</.link>|)

      assert dom =~ ~s|data-phx-link="patch"|
      assert dom =~ ~s|data-phx-link-state="push"|
      assert dom =~ ~s|text</a>|
      refute dom =~ ~s|to="/|
    end

    test "forwards global dom attributes" do
      assigns = %{}
      dom = render(~H|<.link patch="/" class="btn btn-large" data={[page_number: 2]}>next</.link>|)

      assert dom =~ ~s|class="btn btn-large"|
      assert dom =~ ~s|data-page-number="2"|
      assert dom =~ ~s|data-phx-link="patch"|
      assert dom =~ ~s|data-phx-link-state="push"|
    end
  end

  describe "link navigate" do
    test "basic usage" do
      assigns = %{}
      dom = render(~H|<.link navigate="/">text</.link>|)

      assert dom =~ ~s|data-phx-link="redirect"|
      assert dom =~ ~s|data-phx-link-state="push"|
      assert dom =~ ~s|text</a>|
      refute dom =~ ~s|to="/|
    end

    test "forwards global dom attributes" do
      assigns = %{}
      dom = render(~H|<.link navigate="/" class="btn btn-large" data={[page_number: 2]}>text</.link>|)

      assert dom =~ ~s|class="btn btn-large"|
      assert dom =~ ~s|data-page-number="2"|
      assert dom =~ ~s|data-phx-link="redirect"|
      assert dom =~ ~s|data-phx-link-state="push"|
    end
  end

  describe "live_title/2" do
    test "prefix only" do
      assigns = %{}
      assert render(~H|<.live_title prefix="MyApp – ">My Title</.live_title>|) ==
               ~s|<title data-prefix="MyApp – ">MyApp – My Title</title>|
    end

    test "suffix only" do
      assigns = %{}
      assert render(~H|<.live_title suffix=" – MyApp">My Title</.live_title>|) ==
               ~s|<title data-suffix=" – MyApp">My Title – MyApp</title>|
    end

    test "prefix and suffix" do
      assigns = %{}
      assert render(~H|<.live_title prefix="Welcome: " suffix=" – MyApp">My Title</.live_title>|) ==
               ~s|<title data-prefix="Welcome: " data-suffix=" – MyApp">Welcome: My Title – MyApp</title>|
    end

    test "without prefix or suffix" do
      assigns = %{}
      assert render(~H|<.live_title>My Title</.live_title>|) ==
               ~s|<title>My Title</title>|
    end
  end

  defp parse(template) do
    template
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
    |> Phoenix.LiveViewTest.DOM.parse()
  end

  describe "form" do
    test "raises when missing required assigns" do
      assert_raise ArgumentError, ~r/missing :for assign/, fn ->
        assigns = %{}

        parse(~H"""
        <.form :let={f}>
          <%= text_input f, :foo %>
        </.form>
        """)
      end
    end

    test "generates form with no options" do
      assigns = %{}

      html =
        parse(~H"""
        <.form :let={f} for={:myform}>
          <%= text_input f, :foo %>
        </.form>
        """)

      assert [
               {"form", [],
                [
                  {"input", [{"id", "myform_foo"}, {"name", "myform[foo]"}, {"type", "text"}], []}
                ]}
             ] = html
    end

    test "does not generate csrf_token if method is not post or if no action" do
      assigns = %{}

      html =
        parse(~H"""
        <.form :let={f} for={:myform} method="get" action="/">
          <%= text_input f, :foo %>
        </.form>
        """)

      assert [
               {"form", [{"action", "/"}, {"method", "get"}],
                [
                  {"input", [{"id", "myform_foo"}, {"name", "myform[foo]"}, {"type", "text"}], []}
                ]}
             ] = html

      html =
        parse(~H"""
        <.form :let={f} for={:myform}>
          <%= text_input f, :foo %>
        </.form>
        """)

      assert [
               {"form", [],
                [
                  {"input", [{"id", "myform_foo"}, {"name", "myform[foo]"}, {"type", "text"}], []}
                ]}
             ] = html
    end

    test "generates form with available options and custom attributes" do
      assigns = %{}

      html =
        parse(~H"""
        <.form :let={user_form}
          for={%Plug.Conn{}}
          id="form"
          action="/"
          method="put"
          multipart
          csrf_token="123"
          as="user"
          errors={[name: "can't be blank"]}
          data-foo="bar"
          class="pretty"
          phx-change="valid"
        >
          <%= text_input user_form, :foo %>
          <%= inspect(user_form.errors) %>
        </.form>
        """)

      assert [
               {"form",
                [
                  {"enctype", "multipart/form-data"},
                  {"action", "/"},
                  {"method", "post"},
                  {"class", "pretty"},
                  {"data-foo", "bar"},
                  {"id", "form"},
                  {"phx-change", "valid"}
                ],
                [
                  {"input", [{"name", "_method"}, {"type", "hidden"}, {"value", "put"}], []},
                  {"input", [{"name", "_csrf_token"}, {"type", "hidden"}, {"value", "123"}], []},
                  {"input", [{"id", "form_foo"}, {"name", "user[foo]"}, {"type", "text"}], []},
                  "\n  [name: \"can't be blank\"]\n\n"
                ]}
             ] = html
    end
  end

  test "assigns_to_attributes/2" do
    assert assigns_to_attributes(%{}) == []
    assert assigns_to_attributes(%{}, [:non_exists]) == []
    assert assigns_to_attributes(%{one: 1, two: 2}) == [one: 1, two: 2]
    assert assigns_to_attributes(%{one: 1, two: 2}, [:one]) == [two: 2]
    assert assigns_to_attributes(%{__changed__: %{}, one: 1, two: 2}, [:one]) == [two: 2]
    assert assigns_to_attributes(%{__changed__: %{}, inner_block: fn -> :ok end, a: 1}) == [a: 1]
    assert assigns_to_attributes(%{__slot__: :foo, inner_block: fn -> :ok end, a: 1}) == [a: 1]
  end
end
