let version = "0.0.0"

let usage () =
  String.concat "\n" [
    "Usage:";
    "  multi-sub [options] <pattern> <replace> [<locs.txt>]";
    "";
    "Substitutes the pattern with the replacement in the mentioned lines.";
    "";
    "Arguments:";
    "  <pattern>      A valid OCaml regular expression[1].";
    "  <replace>      The expression to substitute when a match is found[2].";
    "  <locs.txt>     The name of a file with lines formatted like:";
    "                   filename.ext:20";
    "                 If omitted, reads from stdin.";
    "";
    "Options:";
    "  -i, --ignore-case     Treat the pattern as case insensitive.";
    "  -s, --case-sensitive  Treat the pattern as case sensitive [default].";
    "  -g, --global          Replace all matches on a line, not just the first.";
    "  --version             Print version and exit.";
    "";
    "[1]: https://caml.inria.fr/pub/docs/manual-ocaml/libref/Str.html#VALregexp";
    "[2]: https://caml.inria.fr/pub/docs/manual-ocaml/libref/Str.html#VALglobal_replace";
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
    replace : string;
    input : input;
  }
end

module ExtraOptions = struct
  type t = {
    global : bool;
    caseSensitive : bool;
  }
end

type t = {
  pattern : string;
  replace : string;
  input : input;
  global : bool;
  caseSensitive : bool;
}

let withExtraOptions
  RequiredOptions.{pattern; replace; input}
  ExtraOptions.{global; caseSensitive} =
  {
    pattern;
    replace;
    input;
    global;
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
  | "-g"::argv' ->
      accumulateOptions argv' ExtraOptions.{acc with global = true}
  | "--global"::argv' ->
      accumulateOptions argv' ExtraOptions.{acc with global = true}
  | "-i"::argv' ->
      accumulateOptions argv' ExtraOptions.{acc with caseSensitive = false}
  | "--ignore-case"::argv' ->
      accumulateOptions argv' ExtraOptions.{acc with caseSensitive = false}
  | "-s"::argv' ->
      accumulateOptions argv' ExtraOptions.{acc with caseSensitive = true}
  | "--case-sensitive"::argv' ->
      accumulateOptions argv' ExtraOptions.{acc with caseSensitive = true}
  | [] -> failWithUsage "Missing required <pattern> argument."
  | [pattern; replace] ->
      withExtraOptions {pattern; replace; input = FromStdin} acc
  | [pattern; replace; filename] ->
      withExtraOptions {pattern; replace; input = FromFile filename} acc
  | arg0::_ -> failWithUsage @@ "Unrecognized argument: " ^ arg0

let defaultOptions =
  ExtraOptions.{
    global = false;
    caseSensitive = true;
  }

let parseArgs argv = accumulateOptions argv defaultOptions
