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

type 'a file_filename = {
  file : 'a;
  filename : string;
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
    | Options.FromStdin -> stdin
    | Options.FromFile inputFilename -> open_in inputFilename
  in
  let inputFileStream = streamFromFile inputFile in

  (* We keep three pieces of state, to avoid reopening files and rereading
   * lines that we've already seen. *)
  let source = ref None in
  let sink = ref None in
  let currLineno = ref 0 in

  let openSourceSink filename =
    let _ = currLineno := 0 in
    let perms = (Unix.stat filename).st_perm in
    let file = open_in filename in
    let mode = [Open_text; Open_wronly; Open_creat] in
    let prefix = "tmp." in
    let suffix = "" in
    let (tempFilename, tempFile) =
      Filename.open_temp_file ~mode ~perms prefix suffix
    in

    (file, tempFilename, tempFile)
  in

  let closeSourceSink source sink =
    try
      while true; do
        Printf.fprintf sink.file "%s\n" (input_line source.file)
      done
    with End_of_file -> ();

    let _ = close_in source.file in
    let _ = close_out sink.file in

    Sys.rename sink.filename source.filename
  in

  let processLine inputLine =
    try
      let (filename, lineno) = parseInputLine inputLine in

      (* We go through great effort to reuse a file that's already open. *)
      let (file, tempFilename, tempFile) =
        match (!source, !sink) with
        | (None, None) -> openSourceSink filename
        | (Some source, Some sink) ->
            if source.filename != filename then begin
              closeSourceSink source sink;
              openSourceSink filename
            end
            else if !currLineno < lineno then
              (source.file, sink.filename, sink.file)
            else begin
              Printf.eprintf "error: lines for %s do not strictly increase (skipping %s)\n" filename inputLine;
              raise Return
            end
        | _ ->
            failwith "Invariant failed: sourceFile and sinkFile should be in sync."
      in

      let fileStream = streamFromFile file in

      let _ = source := Some {file; filename} in
      let _ = sink := Some {filename = tempFilename; file = tempFile} in

      (* TODO(jez) This still doesn't chomp the newline from the end of the line. *)
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

        Printf.fprintf tempFile "%s\n" line';
        flush tempFile;

        if atRelevantLine then raise Break else ()
      in

      try
        Stream.iter updateLine fileStream
      with Break -> ()
    with Return -> ()
  in

  Stream.iter processLine inputFileStream;

  begin
    match (!source, !sink) with
    | (Some source, Some sink) -> closeSourceSink source sink
    | _ -> ()
  end;

  0

