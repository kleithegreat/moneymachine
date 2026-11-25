open Core

type t =
  | Trades
  | L2_book
  | L2_book_fast
  | All_dexs_asset_ctxs
  | Events
  | Listings
  | Dir of string
[@@deriving sexp_of, compare, equal]

let max_depth = 64

let is_ws = function
  | ' ' | '\t' | '\n' | '\r' -> true
  | _ -> false
;;

let rec skip_ws s len pos =
  if pos < len && is_ws s.[pos] then skip_ws s len (pos + 1) else pos
;;

let hex_val = function
  | '0' .. '9' as c -> Char.to_int c - Char.to_int '0'
  | 'a' .. 'f' as c -> 10 + Char.to_int c - Char.to_int 'a'
  | 'A' .. 'F' as c -> 10 + Char.to_int c - Char.to_int 'A'
  | _ -> -1
;;

let scan_hex4 s len pos =
  if pos + 4 > len
  then -1
  else (
    let a = hex_val s.[pos] in
    let b = hex_val s.[pos + 1] in
    let c = hex_val s.[pos + 2] in
    let d = hex_val s.[pos + 3] in
    if a < 0 || b < 0 || c < 0 || d < 0
    then -1
    else (a lsl 12) lor (b lsl 8) lor (c lsl 4) lor d)
;;

(* Scans a JSON string starting right after the opening '"'. Returns the index right after the closing '"',
   or -1 on any syntax error (unclosed string, unescaped control char, invalid escape, lone surrogate). *)
let rec scan_string s len i =
  if i >= len
  then -1
  else (
    match s.[i] with
    | '"' -> i + 1
    | '\\' ->
      if i + 1 >= len
      then -1
      else (
        match s.[i + 1] with
        | '"' | '\\' | '/' | 'b' | 'f' | 'n' | 'r' | 't' -> scan_string s len (i + 2)
        | 'u' ->
          let cp = scan_hex4 s len (i + 2) in
          if cp < 0
          then -1
          else if cp >= 0xDC00 && cp <= 0xDFFF
          then -1
          else if cp >= 0xD800 && cp <= 0xDBFF
          then
            if i + 12 <= len && Char.equal s.[i + 6] '\\' && Char.equal s.[i + 7] 'u'
            then (
              let lo = scan_hex4 s len (i + 8) in
              if lo >= 0xDC00 && lo <= 0xDFFF then scan_string s len (i + 12) else -1)
            else -1
          else scan_string s len (i + 6)
        | _ -> -1)
    | c when Char.to_int c < 0x20 -> -1
    | _ -> scan_string s len (i + 1))
;;

let rec has_backslash s pos stop =
  if pos >= stop
  then false
  else if Char.equal s.[pos] '\\'
  then true
  else has_backslash s (pos + 1) stop
;;

(* Decodes a validated JSON string slice [start, stop) that contains at least one escape. *)
let unescape_slice s ~start ~stop =
  let buf = Buffer.create (stop - start) in
  let rec go i =
    if i >= stop
    then Buffer.contents buf
    else if not (Char.equal s.[i] '\\')
    then (
      Buffer.add_char buf s.[i];
      go (i + 1))
    else (
      match s.[i + 1] with
      | '"' ->
        Buffer.add_char buf '"';
        go (i + 2)
      | '\\' ->
        Buffer.add_char buf '\\';
        go (i + 2)
      | '/' ->
        Buffer.add_char buf '/';
        go (i + 2)
      | 'b' ->
        Buffer.add_char buf '\b';
        go (i + 2)
      | 'f' ->
        Buffer.add_char buf '\x0c';
        go (i + 2)
      | 'n' ->
        Buffer.add_char buf '\n';
        go (i + 2)
      | 'r' ->
        Buffer.add_char buf '\r';
        go (i + 2)
      | 't' ->
        Buffer.add_char buf '\t';
        go (i + 2)
      | 'u' ->
        let cp = scan_hex4 s stop (i + 2) in
        if cp >= 0xD800 && cp <= 0xDBFF
        then (
          let lo = scan_hex4 s stop (i + 8) in
          let full = 0x10000 + ((cp - 0xD800) lsl 10) + (lo - 0xDC00) in
          Stdlib.Buffer.add_utf_8_uchar buf (Stdlib.Uchar.of_int full);
          go (i + 12))
        else (
          Stdlib.Buffer.add_utf_8_uchar buf (Stdlib.Uchar.of_int cp);
          go (i + 6))
      | _ -> Buffer.contents buf)
  in
  go start
;;

let rec skip_digits s len pos =
  if pos < len && Char.is_digit s.[pos] then skip_digits s len (pos + 1) else pos
;;

let scan_number s len pos =
  let pos = if pos < len && Char.equal s.[pos] '-' then pos + 1 else pos in
  if pos >= len
  then -1
  else (
    let pos =
      if Char.equal s.[pos] '0'
      then pos + 1
      else if Char.is_digit s.[pos]
      then skip_digits s len (pos + 1)
      else -1
    in
    if pos < 0
    then -1
    else (
      let pos =
        if pos < len && Char.equal s.[pos] '.'
        then (
          let stop = skip_digits s len (pos + 1) in
          if stop = pos + 1 then -1 else stop)
        else pos
      in
      if pos < 0
      then -1
      else if pos < len && (Char.equal s.[pos] 'e' || Char.equal s.[pos] 'E')
      then (
        let pos = pos + 1 in
        let pos =
          if pos < len && (Char.equal s.[pos] '+' || Char.equal s.[pos] '-')
          then pos + 1
          else pos
        in
        let stop = skip_digits s len pos in
        if stop = pos then -1 else stop)
      else pos))
;;

let scan_literal s len pos word =
  if pos + String.length word <= len && String.is_substring_at s ~pos ~substring:word
  then pos + String.length word
  else -1
;;

let rec scan_value s len pos ~depth =
  if depth > max_depth
  then -1
  else (
    let pos = skip_ws s len pos in
    if pos >= len
    then -1
    else (
      match s.[pos] with
      | '"' -> scan_string s len (pos + 1)
      | 't' -> scan_literal s len pos "true"
      | 'f' -> scan_literal s len pos "false"
      | 'n' -> scan_literal s len pos "null"
      | '-' | '0' .. '9' -> scan_number s len pos
      | '[' -> scan_array s len (pos + 1) ~depth:(depth + 1)
      | '{' -> scan_object s len (pos + 1) ~depth:(depth + 1)
      | _ -> -1))

and scan_array_items s len pos ~depth =
  let pos = scan_value s len pos ~depth in
  if pos < 0
  then -1
  else (
    let pos = skip_ws s len pos in
    if pos >= len
    then -1
    else if Char.equal s.[pos] ']'
    then pos + 1
    else if Char.equal s.[pos] ','
    then scan_array_items s len (pos + 1) ~depth
    else -1)

and scan_array s len pos ~depth =
  if depth > max_depth
  then -1
  else (
    let pos = skip_ws s len pos in
    if pos >= len
    then -1
    else if Char.equal s.[pos] ']'
    then pos + 1
    else scan_array_items s len pos ~depth)

and scan_object_members s len pos ~depth =
  let pos = skip_ws s len pos in
  if pos >= len || not (Char.equal s.[pos] '"')
  then -1
  else (
    let pos = scan_string s len (pos + 1) in
    if pos < 0
    then -1
    else (
      let pos = skip_ws s len pos in
      if pos >= len || not (Char.equal s.[pos] ':')
      then -1
      else (
        let pos = scan_value s len (pos + 1) ~depth in
        if pos < 0
        then -1
        else (
          let pos = skip_ws s len pos in
          if pos >= len
          then -1
          else if Char.equal s.[pos] '}'
          then pos + 1
          else if Char.equal s.[pos] ','
          then scan_object_members s len (pos + 1) ~depth
          else -1))))

and scan_object s len pos ~depth =
  if depth > max_depth
  then -1
  else (
    let pos = skip_ws s len pos in
    if pos >= len
    then -1
    else if Char.equal s.[pos] '}'
    then pos + 1
    else scan_object_members s len pos ~depth)
;;

let is_channel_key s ~start ~stop =
  let len = stop - start in
  if not (has_backslash s start stop)
  then len = 7 && String.is_substring_at s ~pos:start ~substring:"channel"
  else if len > 42
  then false
  else String.equal (unescape_slice s ~start ~stop) "channel"
;;

let route_of_channel_name ~fast s ~start ~stop =
  let len = stop - start in
  if not (has_backslash s start stop)
  then
    if len = 6 && String.is_substring_at s ~pos:start ~substring:"trades"
    then Trades
    else if len = 6 && String.is_substring_at s ~pos:start ~substring:"l2Book"
    then if fast then L2_book_fast else L2_book
    else if len = 16 && String.is_substring_at s ~pos:start ~substring:"allDexsAssetCtxs"
    then All_dexs_asset_ctxs
    else Events
  else if len > 96
  then Events
  else (
    match unescape_slice s ~start ~stop with
    | "trades" -> Trades
    | "l2Book" -> if fast then L2_book_fast else L2_book
    | "allDexsAssetCtxs" -> All_dexs_asset_ctxs
    | _ -> Events)
;;

let rec scan_top_members ~fast frame len pos found_set found =
  let pos = skip_ws frame len pos in
  if pos >= len || not (Char.equal frame.[pos] '"')
  then Events
  else (
    let key_start = pos + 1 in
    let after_key = scan_string frame len key_start in
    if after_key < 0
    then Events
    else (
      let key_stop = after_key - 1 in
      let pos = skip_ws frame len after_key in
      if pos >= len || not (Char.equal frame.[pos] ':')
      then Events
      else (
        let vpos = skip_ws frame len (pos + 1) in
        let is_chan =
          (not found_set) && is_channel_key frame ~start:key_start ~stop:key_stop
        in
        let after_val =
          if is_chan && vpos < len && Char.equal frame.[vpos] '"'
          then scan_string frame len (vpos + 1)
          else scan_value frame len vpos ~depth:1
        in
        if after_val < 0
        then Events
        else (
          let next_found_set = found_set || is_chan in
          let next_found =
            if is_chan
            then
              if vpos < len && Char.equal frame.[vpos] '"'
              then
                route_of_channel_name ~fast frame ~start:(vpos + 1) ~stop:(after_val - 1)
              else Events
            else found
          in
          let pos = skip_ws frame len after_val in
          if pos >= len
          then Events
          else if Char.equal frame.[pos] ','
          then scan_top_members ~fast frame len (pos + 1) next_found_set next_found
          else if Char.equal frame.[pos] '}'
          then
            if skip_ws frame len (pos + 1) = len
            then if next_found_set then next_found else Events
            else Events
          else Events))))
;;

let of_frame ~fast frame =
  let len = String.length frame in
  if len = 0 || not (Stdlib.String.is_valid_utf_8 frame)
  then Events
  else (
    let pos = skip_ws frame len 0 in
    if pos >= len || not (Char.equal frame.[pos] '{')
    then Events
    else (
      let pos = skip_ws frame len (pos + 1) in
      if pos >= len
      then Events
      else if Char.equal frame.[pos] '}'
      then Events
      else scan_top_members ~fast frame len pos false Events))
;;

let dir = function
  | Trades -> "trades"
  | L2_book -> "l2Book"
  | L2_book_fast -> "l2Book-fast"
  | All_dexs_asset_ctxs -> "allDexsAssetCtxs"
  | Events -> "events"
  | Listings -> "listings"
  | Dir dir -> dir
;;
