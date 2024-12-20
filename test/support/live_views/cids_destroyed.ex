defmodule Phoenix.LiveViewTest.Support.CidsDestroyedLive do
  use Phoenix.LiveView

  defmodule Button do
    use Phoenix.LiveComponent

    def mount(socket) do
      {:ok, assign(socket, counter: 0)}
    end

    def render(assigns) do
      ~H"""
      <div>
        <button type="submit">{@text}</button>
        <div id="bumper" phx-click="bump" phx-target={@myself}>Bump: {@counter}</div>
      </div>
      """
    end

    def handle_event("bump", _, socket) do
      {:noreply, update(socket, :counter, &(&1 + 1))}
    end
  end

  def render(assigns) do
    ~H"""
    <%= if @form do %>
      <form phx-submit="event_1">
        <.live_component module={Button} id="button" text="Hello World" />
      </form>
    <% else %>
      <div class="loader">loading...</div>
    <% end %>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: true)}
  end

  def handle_event("event_1", _params, socket) do
    send(self(), :event_2)
    {:noreply, assign(socket, form: false)}
  end

  def handle_info(:event_2, socket) do
    {:noreply, assign(socket, form: true)}
  end
end
