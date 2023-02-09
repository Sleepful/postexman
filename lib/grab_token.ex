defmodule PX.TokenStore do
  use GenServer

  # Start with atom name
  def start_link(token_callback, opts) when is_function(token_callback) do
    genserver_opts = Keyword.get(opts, :name) && [name: Keyword.get(opts, :name)] || []
    GenServer.start_link(__MODULE__, {token_callback, opts}, genserver_opts)
  end

  def grab(pid) do
    GenServer.call(pid, :grab)
  end

  def stop(pid) do
    GenServer.stop(pid)
  end

  def refresh(pid, %{callback: token_callback, timeout: timeout} = state) do
    token = token_callback.()
    timer = Process.send_after(pid, :trigger_refresh, timeout)
    Map.merge(state, %{token: token, timer: timer, callback: token_callback, timeout: timeout})
  end

  @impl true
  def init({token_callback, opts}) do
    five_mins = :timer.minutes(5)
    timeout = Keyword.get(opts, :timeout, five_mins)
    debug = Keyword.get(opts, :debug, false)

    state =
      refresh(self(),
        %{
        callback: token_callback,
        timeout: timeout,
        debug: debug
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
    %{token: token, debug: debug} = state
    if(debug) do
      IO.inspect(token, label: "New token")
    end
    {:noreply, state}
  end

  @impl true
  def terminate(reason, %{debug: debug} = state) do
    if(debug) do
      IO.puts("Terminating token manager")
      IO.inspect(state, label: "State")
      IO.inspect(self(), label: "PID")
      IO.inspect(reason, label: "reason")
      IO.puts("Terminated")
    end
  end
end
