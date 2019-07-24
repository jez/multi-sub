(* TODO(jez) Audit for snek_case *)

(* Input lines look like
 *
 *   file.txt:20
 *
 * and since they're coming from TextIO.inputLine, they're guaranteed to have
 * a trailing newline.
 *)
let parseInputLine inputLine =
  let parseFailure () =
    ( prerr_endline @@ "Couldn't parse input line: "^inputLine
    ; exit 1)
  in
  match Str.split (Str.regexp "[:\n\r]") inputLine with
  | [filename; linenoStr] ->
      (match int_of_string_opt linenoStr with
       | Some lineno -> (filename, lineno)
       | _ -> parseFailure ())
  | _ -> parseFailure ()

let streamFromFile file =
  Stream.from (fun _ -> try Some (input_line file) with End_of_file -> None)

let containsMatch re line =
  try
    let _ = Str.search_forward re line 0 in
    true
  with Not_found -> false

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
    pattern = inputPattern;
    replace;
    input;
    global;
    caseSensitive;
  } = Options.parseArgs argv in

  let re =
    if caseSensitive
    then Str.regexp inputPattern
    else Str.regexp_case_fold inputPattern
  in

  let inputFile =
    match input with
    | Options.FromStdin ->
        ( if Unix.isatty Unix.stdin
          then prerr_endline "Warning: reading from stdin, which is a tty."
          else ()
        ; stdin
        )
    | Options.FromFile inputFilename -> open_in inputFilename
  in
  let inputFileStream = streamFromFile inputFile in

  (* We keep three pieces of state, to avoid reopening files and rereading
   * lines that we've already seen. *)
  let sourceSink = ref None in
  let currLineno = ref 0 in

  let openSourceSink filename =
    (* Always reset lineno when opening a file, because
     * we'll always start seeking from the file start. *)
    let _ = currLineno := 0 in

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

  let closeSourceSink ss =
    try
      while true; do
        Printf.fprintf ss.sink "%s\n" (input_line ss.source)
      done
    with End_of_file -> ();

    Sys.rename ss.tmpfile ss.filename;

    close_in ss.source;
    close_out ss.sink
  in

  let processLine inputLine =
    try
      let (filename, lineno) = parseInputLine inputLine in

      (* We go through great effort to reuse a file that's already open. *)
      let (tmpfile, source, sink) =
        match !sourceSink with
        | None -> openSourceSink filename
        | Some ss ->
            if ss.filename != filename then begin
              closeSourceSink ss;
              openSourceSink filename
            end
            else if !currLineno < lineno then
              (ss.tmpfile, ss.source, ss.sink)
            else begin
              Printf.eprintf "error: lines for %s do not strictly increase (skipping %s)\n" filename inputLine;
              raise Return
            end
      in

      let fileStream = streamFromFile source in

      let _ = sourceSink := Some {filename; tmpfile; source; sink} in

      let updateLine line =
        currLineno := !currLineno + 1;
        let atRelevantLine = !currLineno = lineno in
        let line' =
          if atRelevantLine
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

        if atRelevantLine then raise Break else ()
      in

      try
        Stream.iter updateLine fileStream
      with Break -> ()
    with Return -> ()
  in

  Stream.iter processLine inputFileStream;

  begin
    match !sourceSink with
    | Some ss -> closeSourceSink ss
    | _ -> ()
  end;

  0

