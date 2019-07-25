(* Input lines look like
 *
 *   file.txt:20
 *
 * and since they're coming from TextIO.input_line, they're guaranteed to have
 * a trailing newline.
 *)
let parse_input_line input_line =
  let parse_failure () =
    ( prerr_endline @@ "Couldn't parse input line: "^input_line
    ; exit 1)
  in
  match Str.split (Str.regexp "[:\n\r]") input_line with
  | [filename; lineno_str] ->
      (match int_of_string_opt lineno_str with
       | Some lineno -> (filename, lineno)
       | _ -> parse_failure ())
  | _ -> parse_failure ()

let stream_from_file file =
  Stream.from (fun _ -> try Some (input_line file) with End_of_file -> None)

exception Break
exception Return

type source_sink = {
  filename : string;
  tmpfile : string;
  source : in_channel;
  sink : out_channel;
}

let main arg0 argv =
  let Options.{
    pattern = input_pattern;
    replace;
    input;
    global;
    case_sensitive;
  } = Options.parseArgs argv in

  let re =
    if case_sensitive
    then Str.regexp input_pattern
    else Str.regexp_case_fold input_pattern
  in

  let input_file =
    match input with
    | Options.FromStdin ->
        ( if Unix.isatty Unix.stdin
          then prerr_endline "Warning: reading from stdin, which is a tty."
          else ()
        ; stdin
        )
    | Options.FromFile input_filename -> open_in input_filename
  in
  let input_file_stream = stream_from_file input_file in

  (* We keep three pieces of state, to avoid reopening files and rereading
   * lines that we've already seen. *)
  let source_sink = ref None in
  let curr_lineno = ref 0 in

  let open_source_sink filename =
    (* Always reset lineno when opening a file, because
     * we'll always start seeking from the file start. *)
    let _ = curr_lineno := 0 in

    let source = open_in filename in

    let stats = Unix.stat filename in

    let mode = [Open_text; Open_wronly; Open_creat] in
    let perms = stats.st_perm in
    let tmpfile = Printf.sprintf "%s.%d.bak" filename (Unix.getpid ()) in
    let sink = open_out_gen mode perms tmpfile in

    let uid = stats.st_uid in
    let gid = stats.st_gid in
    Unix.chown tmpfile uid gid;

    (tmpfile, source, sink)
  in

  let close_source_sink ss =
    try
      while true; do
        Printf.fprintf ss.sink "%s\n" (input_line ss.source)
      done
    with End_of_file -> ();

    Sys.rename ss.tmpfile ss.filename;

    close_in ss.source;
    close_out ss.sink
  in

  let process_line input_line =
    try
      let (filename, lineno) = parse_input_line input_line in

      (* We go through great effort to reuse a file that's already open. *)
      let (tmpfile, source, sink) =
        match !source_sink with
        | None -> open_source_sink filename
        | Some ss ->
            if ss.filename != filename then begin
              close_source_sink ss;
              open_source_sink filename
            end
            else if !curr_lineno < lineno then
              (ss.tmpfile, ss.source, ss.sink)
            else begin
              Printf.eprintf "error: lines for %s do not strictly increase (skipping %s)\n" filename input_line;
              raise Return
            end
      in

      let file_stream = stream_from_file source in

      let _ = source_sink := Some {filename; tmpfile; source; sink} in

      let update_line line =
        curr_lineno := !curr_lineno + 1;
        let at_relevant_line = !curr_lineno = lineno in
        let line' =
          if at_relevant_line
          then
            if global
            then Str.global_replace re replace line
            else Str.replace_first re replace line
          else
            line
        in

        (* TODO(jez) This will add a newline to a file that doesn't have a trailing newline. *)
        Printf.fprintf sink "%s\n" line';
        flush sink;

        if at_relevant_line then raise Break else ()
      in

      try
        Stream.iter update_line file_stream
      with Break -> ()
    with Return -> ()
  in

  Stream.iter process_line input_file_stream;

  begin
    match !source_sink with
    | Some ss -> close_source_sink ss
    | _ -> ()
  end;

  0

