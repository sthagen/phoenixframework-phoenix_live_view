defmodule Phoenix.LiveViewTest.LayoutView do
  use Phoenix.View, root: ""
  use Phoenix.Component

  use Phoenix.VerifiedRoutes,
    router: Phoenix.LiveViewTest.Router,
    endpoint: Phoenix.LiveViewTest.Endpoint,
    statics: ~w(css)

  def render("app.html", assigns) do
    # Assert those assigns are always available
    _ = assigns.live_module
    _ = assigns.live_action

    ["LAYOUT", assigns.inner_content]
  end

  def render("live.html", assigns) do
    ~H"""
    LIVELAYOUTSTART-<%= @val %>-<%= @inner_content %>-LIVELAYOUTEND
    """
  end

  def render("live_override.html", assigns) do
    ~H"""
    LIVEOVERRIDESTART-<%= @val %>-<%= @inner_content %>-LIVEOVERRIDEEND
    """
  end

  def render("widget.html", assigns) do
    ~H"""
    WIDGET:<%= live_render(@conn, Phoenix.LiveViewTest.ClockLive) %>
    """
  end

  def render("with-function-component.html", assigns) do
    ~H"""
    RENDER:<Phoenix.LiveViewTest.FunctionComponent.render value="from component" />
    """
  end

  def render("layout-with-function-component.html", assigns) do
    ~H"""
    LAYOUT:<Phoenix.LiveViewTest.FunctionComponent.render value="from layout" />
    <%= @inner_content %>
    """
  end

  def render("hello.html", assigns) do
    ~H"""
    Hello
    """
  end

  def render("styled.html", assigns) do
    ~H"""
    <html>
      <head>
        <title>Styled</title>
        <link rel="stylesheet" href="/css/custom.css" />
        <link rel="stylesheet" href={~p"/css/app.css"} />
        <link rel="stylesheet" href="//example.com/a.css" />
        <link rel="stylesheet" href="https://example.com/b.css" />
        <style>
          body { background-color: #eee; }
        </style>
        <script>
          console.log("script")
        </script>
      </head>
      <body>
        <%= @inner_content %>
      </body>
    </html>
    """
  end

  def on_mount_layout(assigns) do
    ~H"""
    <div id="on-mount">
      <%= @inner_content %>
    </div>
    """
  end
end

defmodule Phoenix.LiveViewTest.AssignsLayoutView do
  use Phoenix.View, root: ""

  def render("app.html", assigns) do
    ["title: #{assigns.title}", assigns.inner_content]
  end
end
