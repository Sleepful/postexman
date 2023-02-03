defmodule PX.TokenStore do
  use GenServer

  # Start with atom name
  def start_link(token_callback, name, opts) when is_atom(name) and is_function(token_callback) do
    GenServer.start_link(__MODULE__, {token_callback, opts}, name: name)
  end

  # Start
  def start_link(token_callback, opts \\ []) when is_function(token_callback) do
    GenServer.start_link(__MODULE__, {token_callback, opts})
  end

  def grab(pid) do
    GenServer.call(pid, :grab)
  end

  def stop(pid) do
    GenServer.stop(pid)
  end

  def refresh(pid, %{callback: token_callback, timeout: timeout}) do
    token = token_callback.()
    timer = Process.send_after(pid, :trigger_refresh, timeout)
    %{token: token, timer: timer, callback: token_callback, timeout: timeout}
  end

  @impl true
  def init({token_callback, opts}) do
    five_mins = :timer.minutes(5)
    timeout = Keyword.get(opts, :timeout, five_mins)

    state =
      refresh(self(),
        %{
        callback: token_callback,
        timeout: timeout
      })

    {:ok, state}
  end

  @impl true
  def handle_call(:grab, _from, state) do
    %{token: token} = state
    {:reply, token, state}
  end

  @impl true
  def handle_info(:trigger_refresh, state) do
    genserver = self()

    Task.start_link(fn ->
      new_state = refresh(genserver, state)
      Kernel.send(genserver, {:new_token, new_state})
    end)

    {:noreply, state}
  end

  @impl true
  def handle_info({:new_token, state}, _old_state) do
    IO.puts("New token")
    {:noreply, state}
  end

  @impl true
  def terminate(reason, state) do
    IO.puts("Terminating token manager")
    IO.inspect(state, label: "State")
    IO.inspect(self(), label: "PID")
    IO.inspect(reason, label: "reason")
    IO.puts("Terminated")
  end
end
