defmodule Phoenix.LiveViewTest.EventsLive do
  use Phoenix.LiveView, namespace: Phoenix.LiveViewTest

  def render(assigns) do
    ~H"""
    count: <%= @count %>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, events: [], count: 0)}
  end

  def handle_event("reply", %{"count" => new_count, "reply" => reply}, socket) do
    {:reply, reply, assign(socket, :count, new_count)}
  end

  def handle_event("reply", %{"reply" => reply}, socket) do
    {:reply, reply, socket}
  end

  def handle_call({:run, func}, _, socket), do: func.(socket)

  def handle_info({:run, func}, socket), do: func.(socket)
end

defmodule Phoenix.LiveViewTest.EventsInMountLive do
  use Phoenix.LiveView, namespace: Phoenix.LiveViewTest

  defmodule Child do
    use Phoenix.LiveView, namespace: Phoenix.LiveViewTest

    def render(assigns) do
      ~H"hello!"
    end

    def mount(_params, _session, socket) do
      socket =
        if connected?(socket),
          do: push_event(socket, "child-mount", %{child: "bar"}),
          else: socket

      {:ok, socket}
    end
  end

  def render(assigns) do
    ~H"<%= live_render @socket, Child, id: :child_live %>"
  end

  def mount(_params, _session, socket) do
    socket =
      if connected?(socket),
        do: push_event(socket, "root-mount", %{root: "foo"}),
        else: socket

    {:ok, socket}
  end
end

defmodule Phoenix.LiveViewTest.EventsInComponentLive do
  use Phoenix.LiveView, namespace: Phoenix.LiveViewTest

  defmodule Child do
    use Phoenix.LiveComponent

    def render(assigns) do
      ~H"""
      <div>
        <button id="comp-reply"
                phx-click="reply"
                phx-target={@myself}>
          bump reply!
        </button>

        <button id="comp-noreply"
                phx-click="noreply"
                phx-target={@myself}>
          bump no reply!
        </button>
      </div>
      """
    end

    def update(assigns, socket) do
      socket =
        if connected?(socket),
          do: push_event(socket, "component", %{count: assigns.count}),
          else: socket

      {:ok, socket}
    end

    def handle_event("reply", reply, socket) do
      {:reply, %{"comp-reply" => reply}, socket}
    end

    def handle_event("noreply", _reply, socket) do
      {:noreply, socket}
    end
  end

  def render(assigns) do
    ~H"<%= live_component Child, id: :child_live, count: @count %>"
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :count, 1)}
  end

  def handle_event("bump", _, socket) do
    {:noreply, update(socket, :count, &(&1 + 1))}
  end
end
