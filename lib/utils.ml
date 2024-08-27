let directory_stack : string Stack.t = Stack.create ()

let cp ~args ~src ~dst =
  let cmd = Filename.quote_command "cp" (args @ [ src; dst ]) in
  Format.printf "%s\n%!" cmd;
  match Sys.command cmd with
  | 0 -> ()
  | _ -> failwith "copy failed with nonzero exit code"

let rm ~args ~file =
  let cmd = Filename.quote_command "rm" (args @ [ file ]) in
  Format.printf "%s\n%!" cmd;
  match Sys.command cmd with
  | 0 -> ()
  | _ -> failwith "remove failed with nonzero exit code"

let mkdir dir =
  Format.printf "Creating directory %s\n%!" dir;
  if not (Sys.file_exists dir) then Sys.mkdir dir 0o755

let pushd dir =
  Format.printf "Entering directory %s\n%!" dir;
  Stack.push (Sys.getcwd ()) directory_stack;
  Sys.chdir dir

let popd () =
  let dir = Stack.pop directory_stack in
  Format.printf "Returning to directory %s\n%!" dir;
  Sys.chdir dir

let ls ~args ~dir =
  let cmd = Filename.quote_command "ls" (args @ [ dir ]) in
  Format.printf "%s\n%!" cmd;
  match Sys.command cmd with
  | 0 -> ()
  | _ -> failwith "ls failed with nonzero exit code"

let time cmd =
  let tmp = Filename.temp_file "time" "" in
  let cmd = Filename.quote_command "time" ~stdout:tmp [ cmd ] in
  Format.printf "%s\n%!" cmd;
  (match Sys.command cmd with
  | 0 -> ()
  | _ -> failwith "time failed with nonzero exit code");
  let _output = In_channel.with_open_text tmp In_channel.input_all in
  Format.printf "output = '%s'\n%!" _output;
  ()

let pwd () = 
  let dir = Sys.getcwd () in
  Format.printf "Current directory is %s\n%!" dir

let pp_list ~sep pp_item =
  Format.pp_print_list ~pp_sep:(fun ppf () -> Format.fprintf ppf sep) pp_item
