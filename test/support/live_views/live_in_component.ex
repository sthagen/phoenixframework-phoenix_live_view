defmodule Phoenix.LiveViewTest.LiveInComponent.Root do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"<.live_component module={Phoenix.LiveViewTest.LiveInComponent.Component} id={:nested_component} />"
  end
end

defmodule Phoenix.LiveViewTest.LiveInComponent.Component do
  use Phoenix.LiveComponent

  def render(assigns) do
    ~H"""
    <div>
      <%= live_render(@socket, Phoenix.LiveViewTest.LiveInComponent.Live, id: :nested_live) %>"
    </div>
    """
  end
end

defmodule Phoenix.LiveViewTest.LiveInComponent.Live do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H""
  end
end
