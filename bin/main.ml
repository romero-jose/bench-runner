open Bench_runner.Lib
open Cmdliner

let dir =
  let default = "./benchmarks" in
  let doc = "The directory containing the benchmarks" in
  Arg.(value & opt string default & info [ "dir" ] ~doc)

let benchmarks =
  let default = [] in
  let doc =
    "The names of the benchmarks to be run. If empty all benchmarks are run"
  in
  Arg.(value & opt_all string default & info [ "benchmark" ] ~doc)

let build_dir =
  let default = "_bench" in
  let doc = "The directory where the benchmarks are built and run" in
  Arg.(value & opt string default & info [ "build-dir" ] ~doc)

let compilers =
  let doc =
    "The names of the compilers to be used and their corresponding commands"
  in
  Arg.(
    non_empty
    & opt_all (pair ~sep:':' string string) [ ("name", "command") ]
    & info [ "compiler" ] ~doc)

let run_benchmarks dir benchmarks build_dir compilers =
  let compilers_env =
    List.map
      (fun (name, command) ->
        let command = String.split_on_char ' ' command in
        match command with
        | [] -> failwith "empty command"
        | command :: options -> (name, Compiler.create ~name ~command ~options))
      compilers
  in
  let found_benchmarks = find_benchmarks ~benchmarks dir in
  let benchmarks =
    found_benchmarks
    |> List.map (fun (compiler_name, benchmarks) ->
           let compiler = List.assoc compiler_name compilers_env in
           let configs =
             benchmarks
             |> List.map (fun (_benchmark_name, programs) ->
                    programs
                    |> List.map (fun programs ->
                           Config.create ~compiler ~programs))
             |> List.flatten
           in
           Benchmark.create ~name:compiler_name ~configs)
  in
  benchmarks
  |> List.iter (fun benchmark ->
         Format.printf "@[Finished configuring benchmark:@;<1 2>%a@;<0 0>@]"
           Benchmark.pp benchmark;
         build ~build_dir benchmark;
         run ~build_dir benchmark;
         ())

let cmd =
  let doc = "run benchmarks" in
  let info = Cmd.info ~doc "bench_runner" in
  Cmd.v info
    Term.(const run_benchmarks $ dir $ benchmarks $ build_dir $ compilers)

let main () = exit (Cmd.eval cmd)
let () = main ()
