let version = "0.2.0"

(* TODO(jez) Update this for OCaml regex. *)
let usage () =
  String.concat "\n" [
    "Usage:";
    "  "^(Sys.executable_name)^" [options] <pattern> [<locs.txt>]";
    "";
    "Searches in the mentioned lines for the pattern and prints the lines";
    "that contain a match.";
    "";
    "Arguments:";
    "  <pattern>      An AWK-compatible[1] regular expression.";
    "  <locs.txt>     The name of a file with lines formatted like:";
    "                   filename.ext:20";
    "                 If omitted, reads from stdin.";
    "";
    "Options:";
    "  -v, --invert-match    Print the location if there isn't a match there.";
    "  --version             Print version and exit.";
    "";
    "[1]: http://www.smlnj.org/doc/smlnj-lib/Manual/parser-sig.html";
  ]

let failWithUsage msg =
  ( prerr_endline @@ msg
  ; prerr_endline @@ ""
  ; prerr_endline @@ usage ()
  ; exit 1
  )

type input =
  | FromFile of string
  | FromStdin

module RequiredOptions = struct
  type t = {
    pattern : string;
    input : input;
  }
end

module ExtraOptions = struct
  type t = {
    invert : bool;
    caseSensitive : bool;
  }
end

type t = {
  pattern : string;
  input : input;
  invert : bool;
  caseSensitive : bool;
}

let withExtraOptions
  RequiredOptions.{pattern; input}
  ExtraOptions.{invert; caseSensitive} =
  {
    pattern;
    input;
    invert;
    caseSensitive;
  }

let rec accumulateOptions argv acc =
  match argv with
  | "--version"::_ ->
      ( print_endline version
      ; exit 0)
  | "-h"::_ ->
      ( print_endline @@ usage ()
      ; exit 0)
  | "--help"::_ ->
      ( print_endline @@ usage ()
      ; exit 0)
  | "-v"::argv' ->
      accumulateOptions argv' ExtraOptions.{acc with invert = true}
  | "--invert-match"::argv' ->
      accumulateOptions argv' ExtraOptions.{acc with invert = true}
  | "-i"::argv' ->
      accumulateOptions argv' ExtraOptions.{acc with caseSensitive = false}
  | "--ignore-case"::argv' ->
      accumulateOptions argv' ExtraOptions.{acc with caseSensitive = false}
  | "-s"::argv' ->
      accumulateOptions argv' ExtraOptions.{acc with caseSensitive = true}
  | "--case-sensitive"::argv' ->
      accumulateOptions argv' ExtraOptions.{acc with caseSensitive = true}
  | [] -> failWithUsage "Missing required <pattern> argument."
  | [pattern] ->
      withExtraOptions {pattern; input = FromStdin} acc
  | [pattern; filename] ->
      withExtraOptions {pattern; input = FromFile filename} acc
  | arg0::_ -> failWithUsage @@ "Unrecognized argument: " ^ arg0

let defaultOptions =
  ExtraOptions.{
    invert = false;
    caseSensitive = true;
  }

let parseArgs argv = accumulateOptions argv defaultOptions
