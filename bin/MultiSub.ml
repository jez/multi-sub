match Array.to_list Sys.argv with
| arg0 :: argv -> exit (Lib.Main.main arg0 argv)
| [] -> failwith "Missing required argument (arg0)"
