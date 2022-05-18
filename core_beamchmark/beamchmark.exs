Mix.install(
  [
    # uncomment for version without struct optimisations
    # {:membrane_core, github: "membraneframework/membrane_core", branch: "no-fastmap"},
    {:membrane_core, "0.10.1"},
    :beamchmark
  ],
  config: [
    logger: [
      level: :info,
      compile_time_purge_matching: [
        [level_lower_than: :info],
        # ignore warns when killing elements
        [module: Membrane.Core.Element.LifecycleController, function: "handle_shutdown/2"]
      ]
    ]
  ]
)

alias Membrane.{Buffer, ParentSpec, RemoteControlled, Time}

defmodule Source do
  use Membrane.Source

  def_output_pad(:output, mode: :push, caps: Membrane.RemoteStream)

  @impl true
  def handle_prepared_to_playing(_ctx, state) do
    {{:ok,
      caps: {:output, %Membrane.RemoteStream{}}, start_timer: {:timer, Time.milliseconds(200)}},
     state}
  end

  @impl true
  def handle_tick(:timer, _ctx, state) do
    buffers = Enum.map(1..10, fn _i -> %Buffer{payload: :crypto.strong_rand_bytes(1024)} end)
    {{:ok, buffer: {:output, buffers}}, state}
  end

  @impl true
  def handle_playing_to_prepared(_ctx, state) do
    {{:ok, stop_timer: :timer}, state}
  end
end

defmodule Filter do
  use Membrane.Filter

  def_input_pad(:input, demand_mode: :auto, caps: :any)
  def_output_pad(:output, demand_mode: :auto, caps: :any)

  @impl true
  def handle_process(:input, buffer, _ctx, state) do
    <<payload::512-bytes, _rest::binary>> = buffer.payload
    payload = :crypto.strong_rand_bytes(512) <> payload
    {{:ok, buffer: {:output, %Buffer{buffer | payload: payload}}}, state}
  end
end

defmodule Sink do
  use Membrane.Sink

  def_input_pad(:input, caps: :any, demand_unit: :buffers)

  @impl true
  def handle_prepared_to_playing(_ctx, state) do
    {{:ok, demand: :input}, state}
  end

  @impl true
  def handle_write(:input, _buffer, _ctx, state) do
    {{:ok, demand: :input}, state}
  end
end

defmodule Scenario do
  import Membrane.ParentSpec

  @behaviour Beamchmark.Scenario

  @impl true
  def run() do
    filters = 30
    pipelines = 100

    Enum.each(1..pipelines, fn _i ->
      {:ok, pipeline} = RemoteControlled.Pipeline.start_link()

      RemoteControlled.Pipeline.exec_actions(pipeline,
        spec: %ParentSpec{
          links: [
            Enum.reduce(1..filters, link(:source, Source), fn i, acc ->
              to(acc, {:filter, i}, Filter)
            end)
            |> to(:sink, Sink)
          ]
        },
        playback: :playing
      )
    end)

    Process.sleep(:infinity)
  end
end

Beamchmark.run(Scenario,
  duration: 20,
  delay: 5,
  formatters: [
    {Beamchmark.Formatters.HTML, inline_assets?: true, auto_open?: false}
  ]
)
