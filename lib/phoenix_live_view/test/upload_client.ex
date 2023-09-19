defmodule Phoenix.LiveViewTest.UploadClient do
  @moduledoc false
  use GenServer
  require Phoenix.ChannelTest

  alias Phoenix.LiveViewTest.{Upload, ClientProxy}

  def child_spec(opts) do
    %{
      id: make_ref(),
      start: {__MODULE__, :start_link, [opts]},
      restart: :temporary
    }
  end

  def channel_pids(%Upload{pid: pid}) do
    GenServer.call(pid, :channel_pids)
  end

  def fetch_allow_acknowledged(%Upload{pid: pid}, entry_name) do
    GenServer.call(pid, {:fetch_allow_acknowledged, entry_name})
  end

  def chunk(%Upload{pid: pid, element: element}, name, percent, proxy_pid) do
    GenServer.call(pid, {:chunk, name, percent, proxy_pid, element})
  catch
    :exit, {{:shutdown, :closed}, _} -> {:ok, :closed}
  end

  def simulate_attacker_chunk(%Upload{pid: pid}, name, chunk) do
    GenServer.call(pid, {:simulate_attacker_chunk, name, chunk})
  end

  def allowed_ack(%Upload{pid: pid, entries: entries}, ref, config, name, entries_resp, errors) do
    GenServer.call(pid, {:allowed_ack, ref, config, name, entries, entries_resp, errors})
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, Keyword.merge(opts, caller: self()))
  end

  def init(opts) do
    cid = Keyword.fetch!(opts, :cid)
    socket = Keyword.get(opts, :socket)
    socket = socket && put_in(socket.transport_pid, self())
    {:ok, %{socket: socket, cid: cid, upload_ref: nil, config: %{}, entries: %{}}}
  end

  def handle_call({:fetch_allow_acknowledged, entry_name}, _from, state) do
    case Map.fetch(state.entries, entry_name) do
      {:ok, {:error, reason}} -> {:reply, {:error, reason}, state}
      {:ok, token} -> {:reply, {:ok, token}, state}
      :error -> {:reply, {:error, :nopreflight}, state}
    end
  end

  def handle_call(
        {:allowed_ack, upload_ref, config, name, entries, entries_resp, errors},
        _from,
        state
      ) do
    new_entries =
      Enum.reduce(entries, state.entries, fn %{"ref" => ref, "name" => name} = client_entry,
                                             acc ->
        case Map.fetch(entries_resp, ref) do
          {:ok, token} ->
            Map.put(acc, name, build_and_join_entry(state, client_entry, token))

          :error ->
            Map.put(acc, name, {:error, Map.get(errors, ref, :not_allowed)})
        end
      end)

    new_state = %{state | upload_ref: upload_ref, config: config, entries: new_entries}

    case new_entries do
      %{^name => {:error, reason}} -> {:reply, {:error, reason}, new_state}
      %{^name => _} -> {:reply, :ok, new_state}
      %{} -> raise_unknown_entry!(state, name)
    end
  end

  def handle_call(:channel_pids, _from, state) do
    pids = Enum.into(state.entries, %{}, fn {name, entry} -> {name, entry.socket.channel_pid} end)
    {:reply, pids, state}
  end

  def handle_call({:chunk, entry_name, percent, proxy_pid, element}, from, state) do
    {:noreply, chunk_upload(state, from, entry_name, percent, proxy_pid, element)}
  end

  def handle_call({:simulate_attacker_chunk, entry_name, chunk}, _from, state) do
    Process.flag(:trap_exit, true)
    entry = get_entry!(state, entry_name)
    ref = Phoenix.ChannelTest.push(entry.socket, "chunk", {:binary, chunk})

    receive do
      %Phoenix.Socket.Reply{ref: ^ref, status: status, payload: payload} ->
        {:stop, :normal, {status, payload}, state}
    after
      get_chunk_timeout(state) -> exit(:timeout)
    end
  end

  defp build_and_join_entry(%{socket: nil} = _state, client_entry, token) do
    %{
      "name" => name,
      "content" => content,
      "size" => _,
      "type" => type,
      "ref" => ref
    } = client_entry

    %{
      name: name,
      content: content,
      size: byte_size(content),
      type: type,
      ref: ref,
      token: token,
      chunk_start: 0
    }
  end

  defp build_and_join_entry(state, client_entry, token) do
    %{
      "name" => name,
      "content" => content,
      "size" => _,
      "type" => type,
      "ref" => ref
    } = client_entry

    {:ok, _resp, entry_socket} =
      Phoenix.ChannelTest.subscribe_and_join(state.socket, "lvu:123", %{"token" => token})

    %{
      name: name,
      content: content,
      size: byte_size(content),
      type: type,
      socket: entry_socket,
      ref: ref,
      token: token,
      chunk_start: 0
    }
  end

  defp progress_stats(entry, percent) do
    chunk_size = trunc(entry.size * (percent / 100))
    start = entry.chunk_start
    new_start = start + chunk_size
    new_percent = trunc(new_start / entry.size * 100)

    %{chunk_size: chunk_size, start: start, new_start: new_start, new_percent: new_percent}
  end

  defp chunk_upload(state, from, entry_name, percent, proxy_pid, element) do
    entry = get_entry!(state, entry_name)

    if entry.chunk_start >= entry.size do
      state
    else
      do_chunk(state, from, entry, proxy_pid, element, percent)
    end
  end

  defp do_chunk(%{socket: nil, cid: cid} = state, from, entry, proxy_pid, element, percent) do
    stats = progress_stats(entry, percent)

    :ok =
      ClientProxy.report_upload_progress(
        proxy_pid,
        from,
        element,
        entry.ref,
        stats.new_percent,
        cid
      )

    update_entry_start(state, entry, stats.new_start)
  end

  defp do_chunk(state, from, entry, proxy_pid, element, percent) do
    stats = progress_stats(entry, percent)

    chunk =
      if stats.start + stats.chunk_size > entry.size do
        :binary.part(entry.content, stats.start, entry.size - stats.start)
      else
        :binary.part(entry.content, stats.start, stats.chunk_size)
      end

    ref = Phoenix.ChannelTest.push(entry.socket, "chunk", {:binary, chunk})

    receive do
      %Phoenix.Socket.Reply{ref: ^ref, status: :ok} ->
        :ok =
          ClientProxy.report_upload_progress(
            proxy_pid,
            from,
            element,
            entry.ref,
            stats.new_percent,
            state.cid
          )

        update_entry_start(state, entry, stats.new_start)

      %Phoenix.Socket.Reply{ref: ^ref, status: :error} ->
        :ok =
          ClientProxy.report_upload_progress(
            proxy_pid,
            from,
            element,
            entry.ref,
            %{"error" => "failure"},
            state.cid
          )

        update_entry_start(state, entry, stats.new_start)
    after
      get_chunk_timeout(state) -> exit(:timeout)
    end
  end

  defp update_entry_start(state, entry, new_start) do
    new_entries =
      Map.update!(state.entries, entry.name, fn entry -> %{entry | chunk_start: new_start} end)

    %{state | entries: new_entries}
  end

  defp get_entry!(state, name) do
    case Map.fetch(state.entries, name) do
      {:ok, entry} -> entry
      :error -> raise_unknown_entry!(state, name)
    end
  end

  defp raise_unknown_entry!(state, name) do
    raise "no file input with name \"#{name}\" found in #{inspect(state.entries)}"
  end

  defp get_chunk_timeout(state) do
    state.socket.assigns[:chunk_timeout] || 10_000
  end

  def handle_info(:garbage_collect, state) do
    {:noreply, state}
  end
end
