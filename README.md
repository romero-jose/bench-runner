# Bench Runner

Simple benchmark runner written in OCaml. Work in progress.

## Usage

To use `bench_runner`, you can run the following command:

```bash
bench_runner [OPTIONS]
```

Here are the available options:

- `--benchmark=VAL`: Specify the names of the benchmarks to be run. If left empty, all benchmarks will be run.
- `--build-dir=VAL` (default: `_bench`): Specify the directory where the benchmarks are built and run.
- `--compiler=VAL` (required): Specify the names of the compilers to be used and their corresponding commands.
- `--dir=VAL` (default: `./benchmarks`): Specify the directory containing the benchmarks.
