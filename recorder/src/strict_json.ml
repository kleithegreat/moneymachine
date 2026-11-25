open Core

let max_depth = 64

let check_depth text =
  let len = String.length text in
  let rec go pos depth in_string escaped =
    if pos >= len
    then Ok ()
    else if in_string
    then
      if escaped
      then go (pos + 1) depth true false
      else (
        match text.[pos] with
        | '\\' -> go (pos + 1) depth true true
        | '"' -> go (pos + 1) depth false false
        | _ -> go (pos + 1) depth true false)
    else (
      match text.[pos] with
      | '"' -> go (pos + 1) depth true false
      | '[' | '{' ->
        let next = depth + 1 in
        if next > max_depth
        then Error "nested deeper than 64"
        else go (pos + 1) next false false
      | ']' | '}' ->
        if depth = 0
        then Error "unbalanced closing bracket"
        else go (pos + 1) (depth - 1) false false
      | _ -> go (pos + 1) depth false false)
  in
  go 0 0 false false
;;

let check text =
  match check_depth text with
  | Error _ as err -> err
  | Ok () ->
    (match Jsont_bytesrw.decode_string' Jsont.ignore text with
     | Ok () -> Ok ()
     | Error _ -> Error "not valid strict JSON")
;;
