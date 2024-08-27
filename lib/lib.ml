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

let build_dir = "_bench"

let dest_path path = Filename.concat build_dir path
let compiled_path path = Filename.chop_extension (dest_path path)

let find_benchmarks dir =
  let dirs = Sys.readdir dir in
  pushd dir;
  let benchmarks =
    dirs
    |> Array.map (fun bench_name ->
           let subdir = bench_name in
           Format.printf "Benchmark: %s\n%!" subdir;
           let compilers =
             Sys.readdir subdir
             |> Array.map (fun compiler_name ->
                    let compiler_dir = Filename.concat subdir compiler_name in
                    Format.printf "Compiler: %s\n%!" compiler_dir;
                    let files = Sys.readdir compiler_dir in
                    let programs =
                      files |> Array.to_list
                      |> List.filter_map (fun file ->
                             let filename = Filename.concat compiler_dir file in
                             if not (Sys.is_directory filename) then
                               Some (Program.create ~name:file ~filename)
                             else None)
                    in
                    (compiler_name, programs))
             |> Array.to_list
           in
           (bench_name, compilers))
    |> Array.to_list
  in
  popd ();
  benchmarks

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

let build (bench : Benchmark.t) =
  Format.printf "Building benchmark %s\n%!" bench.name;
  mkdir build_dir;
  let src_dir = Filename.concat "benchmarks" bench.name in
  let dst_dir = build_dir in
  cp ~args:[ "-r" ] ~src:src_dir ~dst:dst_dir;
  pushd dst_dir;
  ls ~args:[ "-l" ] ~dir:".";
  List.iter build_config bench.configs;
  popd ();
  ()

let run (bench : Benchmark.t) =
  Format.printf "Running benchmark %s\n%!" bench.name;
  bench.configs |> List.iter (fun (config : Config.t) ->
    config.programs |> List.iter (fun (program : Program.t) ->
      Format.printf "Running %s\n%!" program.name;
      let cmd = Filename.quote_command (compiled_path program.filename) [] in
      Format.printf "%s\n%!" cmd;
      pwd ();
      time cmd
    ));
  ()

let clean (bench : Benchmark.t) =
  Format.printf "Cleaning benchmark %s\n%!" bench.name;
  let dir = Filename.concat build_dir bench.name in
  if Sys.file_exists dir then rm ~args:[ "-r" ] ~file:dir;
  ()
