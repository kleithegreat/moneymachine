let is_digit character = character >= '0' && character <= '9'
let all_digits text = text <> "" && String.for_all is_digit text

let strip_leading_zeros digits =
  let length = String.length digits in
  let rec first index =
    if index < length - 1 && digits.[index] = '0' then first (index + 1) else index
  in
  let start = first 0 in
  String.sub digits start (length - start)
;;

let strip_trailing_zeros digits =
  let rec last length =
    if length > 0 && digits.[length - 1] = '0' then last (length - 1) else length
  in
  String.sub digits 0 (last (String.length digits))
;;

let place text =
  let negative = text <> "" && text.[0] = '-' in
  let body = if negative then String.sub text 1 (String.length text - 1) else text in
  let whole, fraction =
    match String.index_opt body '.' with
    | None -> body, ""
    | Some point ->
      String.sub body 0 point, String.sub body (point + 1) (String.length body - point - 1)
  in
  let well_formed =
    all_digits whole
    && ((fraction = "" && not (String.contains body '.')) || all_digits fraction)
  in
  if not well_formed
  then Error "E_DECIMAL"
  else (
    let fraction = strip_trailing_zeros fraction in
    let digits = strip_leading_zeros (whole ^ fraction) in
    let sign = if negative && digits <> "0" then "-" else "" in
    Ok (sign ^ digits, String.length fraction))
;;
