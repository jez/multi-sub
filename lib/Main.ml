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

let switchFile file filename =
  (close_in file; open_in filename)

let streamFromFile file =
  Stream.from (fun _ -> try Some (input_line file) with End_of_file -> None)

let containsMatch re line =
  try
    let _ = Str.search_forward re line 0 in
    true
  with Not_found -> false

exception Break

let main arg0 argv =
  let Options.{
    pattern = inputPattern;
    input;
    invert;
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
  let openFilename = ref None in
  let openFile = ref None in
  let currLineno = ref 0 in

  let processLine inputLine =
    let (filename, lineno) = parseInputLine inputLine in

    (* We go through great effort to reuse a file that's already open. *)
    let file =
      match !openFile with
      | None -> open_in filename
      | Some f ->
          if !openFilename != Some filename then
            (currLineno := 0;
             switchFile f filename)
          else if !currLineno < lineno then
            f
          else
            (* Close and reopen the same file to reset the stream. *)
            (prerr_endline @@ "warning: lines for "^filename^" do not strictly increase";
             switchFile f filename)
    in

    let fileStream = streamFromFile file in

    let _ = openFilename := Some filename in
    let _ = openFile := Some file in

    let checkForMatch line =
      currLineno := !currLineno + 1;
      if !currLineno = lineno; then
        let line' =
          if caseSensitive
          then line
          else String.map Char.lowercase_ascii line
        in

        (* Using <> to simulate XOR. *)
        if containsMatch re line' <> invert
        then print_endline @@ filename^":"^(string_of_int lineno)
        else ();

        raise Break
      else
        ()
    in

    try
      Stream.iter checkForMatch fileStream
    with Break -> ()
  in

  Stream.iter processLine inputFileStream;
  0

