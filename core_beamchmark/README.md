# Core Beamchmark

This benchmark runs a simple pipeline for 20 seconds and measures performance with [Beamchmark](https://github.com/membraneframework/beamchmark).

Run with `elixir beamchmark.exs` and the result will be in `index.html`. Running another time will generate a comparison with the previous run.

It's crucial to run this benchmark on an empty machine (meaning all other processes have negligible impact on CPU), because
- processes causing CPU spikes may affect BEAM behavior
- Beamchmark measures CPU usage of the whole machine, not only BEAM
