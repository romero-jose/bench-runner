open Utils

module Compiler = struct
  type t = { name : string; command : string; options : string list }

  let create ~name ~command ~options = { name; command; options }

  let pp fmt compiler =
    Format.fprintf fmt "%s with options %a" compiler.name
      (Format.pp_print_list Format.pp_print_string)
      compiler.options
end

module Program = struct
  type t = { name : string; filename : string }

  let create ~name ~filename = { name; filename }

  let pp fmt program =
    Format.fprintf fmt "@[%s (%s)@]" program.name program.filename
end

module Config = struct
  type t = { compiler : Compiler.t; programs : Program.t list }

  let create ~compiler ~programs = { compiler; programs }

  let pp fmt config =
    Format.fprintf fmt "@[<v>compiler %a:@;<0 2>%a@]" Compiler.pp
      config.compiler
      (pp_list ~sep:"@;<1 2>" Program.pp)
      config.programs
end

module Benchmark = struct
  type t = { name : string; configs : Config.t list }

  let create ~name ~configs = { name; configs }

  let pp fmt config =
    Format.fprintf fmt "@[%s:@;<1 2>%a@]" config.name
      (pp_list ~sep:"@;<1 2>" Config.pp)
      config.configs
end

let dest_path ~build_dir path = Filename.concat build_dir path

let compiled_path ~build_dir path =
  Filename.chop_extension (dest_path ~build_dir path)

let find_benchmarks ~benchmarks dir =
  if not (Sys.file_exists dir) then (
    Printf.eprintf "Directory %s does not exist" dir;
    exit 1);
  let dirs = Sys.readdir dir in
  pushd dir;
  let filter =
    if benchmarks = [] then fun _ -> true
    else fun benchmark_name -> List.mem benchmark_name benchmarks
  in
  let compilers =
    dirs |> Array.to_list
    |> List.filter Sys.is_directory
    |> List.map (fun compiler_name ->
           let compiler_dir = Filename.concat "." compiler_name in
           let benchmarks =
             Sys.readdir compiler_dir |> Array.to_list
             |> List.filter (fun benchmark_name ->
                    Sys.is_directory
                      (Filename.concat compiler_dir benchmark_name))
             |> List.filter filter
             |> List.map (fun benchmark_name ->
                    let benchmark_dir =
                      Filename.concat compiler_dir benchmark_name
                    in
                    let programs =
                      Sys.readdir benchmark_dir |> Array.to_list
                      |> List.filter (fun program_name ->
                             Sys.is_directory
                               (Filename.concat benchmark_dir program_name))
                      |> List.map (fun program_name ->
                             let program_dir =
                               Filename.concat benchmark_dir program_name
                             in
                             Sys.readdir program_dir |> Array.to_list
                             |> List.filter (fun file ->
                                    not
                                      (Sys.is_directory
                                         (Filename.concat program_dir file)))
                             |> List.map (fun file ->
                                    let file_path =
                                      Filename.concat program_dir file
                                    in
                                    Program.create ~name:file
                                      ~filename:file_path))
                    in
                    (benchmark_name, programs))
           in
           (compiler_name, benchmarks))
  in
  popd ();
  compilers

let compile (compiler : Compiler.t) (src : string) (dst : string) =
  let cmd =
    Filename.quote_command compiler.command
      (compiler.options @ [ src; "-o"; dst ])
  in
  Format.printf "%s\n%!" cmd;
  match Sys.command cmd with 0 -> () | _ -> assert false

let build_program (compiler : Compiler.t) (program : Program.t) =
  Format.printf "Building %s\n%!" program.name;
  let src = program.filename in
  let dst = Filename.chop_extension src in
  compile compiler src dst;
  ()

let build_config (config : Config.t) =
  Format.printf "Building config\n%!";
  List.iter (build_program config.compiler) config.programs;
  ()

let build ~build_dir (bench : Benchmark.t) =
  Format.printf "Building benchmark %s\n%!" bench.name;
  mkdir build_dir;
  let src_dir = Filename.concat "benchmarks" bench.name in
  let dst_dir = build_dir in
  cp ~args:[ "-r" ] ~src:src_dir ~dst:dst_dir;
  pushd dst_dir;
  List.iter build_config bench.configs;
  popd ();
  ()

let run ~build_dir (bench : Benchmark.t) =
  Format.printf "Running benchmark %s\n%!" bench.name;
  bench.configs
  |> List.iter (fun (config : Config.t) ->
         config.programs
         |> List.iter (fun (program : Program.t) ->
                let path = compiled_path ~build_dir program.filename in
                Format.printf "Running %s\n%!" path;
                let cmd = Filename.quote_command path [] in
                let time_in_seconds = time cmd in
                Format.printf "Time: %fs\n%!" time_in_seconds));
  ()

let clean ~build_dir (bench : Benchmark.t) =
  Format.printf "Cleaning benchmark %s\n%!" bench.name;
  let dir = Filename.concat build_dir bench.name in
  if Sys.file_exists dir then rm ~args:[ "-r" ] ~file:dir;
  ()
