open Bench_runner.Lib

let gcc = Compiler.create ~name:"gcc" ~command:"gcc" ~options:[ "-O3" ]
let clang = Compiler.create ~name:"clang" ~command:"clang" ~options:[ "-O2" ]

let () =
  let compilers_env = [ ("clang", clang); ("gcc", gcc) ] in
  let benchmarks = find_benchmarks "benchmarks" in
  let benchmarks =
    benchmarks
    |> List.map (fun (name, compilers) ->
           let compilers =
             compilers
             |> List.map (fun (compiler_name, programs) ->
                    let compiler = List.assoc compiler_name compilers_env in
                    Config.create ~compiler ~programs)
           in
           Benchmark.create ~name ~configs:compilers)
  in
  let first_benchmark = List.hd benchmarks in
  Format.printf "@[Finished configuring benchmark:@;<1 2>%a@;<0 0>@]"
    Benchmark.pp first_benchmark;
  build first_benchmark;
  run first_benchmark;
  ()
