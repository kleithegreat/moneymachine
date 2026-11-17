type rat = Exact.rat

type role =
  | Maker
  | Taker

type tier =
  { from_ms : int64
  ; name : string
  ; maker : rat
  ; taker : rat
  }

type event =
  | Fill of
      { time : int64
      ; coin : int
      ; units : rat
      ; price : rat
      ; role : role
      }
  | Funding of
      { time : int64
      ; hour : int64
      ; coin : int
      ; oracle : rat
      ; rate : rat
      }
  | Absorb

type t = string

type position =
  { units : rat
  ; cost : rat
  ; entry : rat option
  }

type snapshot =
  { cash : rat
  ; positions : position list
  ; realized : rat
  ; fees : rat
  ; funding : rat
  ; absorbed : rat
  ; bankrupt : bool
  }

type receipt =
  { state : t
  ; fee : rat
  ; closed_pnl : rat
  ; tier : string option
  ; rate : rat option
  }

let text (numerator, denominator) = numerator ^ "/" ^ denominator
let tokens text = String.split_on_char ' ' text

let rat_of_token token =
  match String.split_on_char '/' token with
  | [ numerator; denominator ] -> numerator, denominator
  | _ -> failwith ("Ledger: not a rational: " ^ token)
;;

let tier_tokens tier =
  [ Int64.to_string tier.from_ms; tier.name; text tier.maker; text tier.taker ]
;;

let schedule_tokens schedule =
  string_of_int (List.length schedule) :: List.concat_map tier_tokens schedule
;;

let event_tokens = function
  | Fill { time; coin; units; price; role } ->
    [ "F"
    ; Int64.to_string time
    ; string_of_int coin
    ; text units
    ; text price
    ; (match role with
       | Maker -> "M"
       | Taker -> "T")
    ]
  | Funding { time; hour; coin; oracle; rate } ->
    [ "U"
    ; Int64.to_string time
    ; Int64.to_string hour
    ; string_of_int coin
    ; text oracle
    ; text rate
    ]
  | Absorb -> [ "A" ]
;;

let call operation arguments =
  match String.split_on_char ' ' (Exact.call operation arguments) with
  | "malformed" :: _ -> failwith ("Ledger." ^ operation ^ ": malformed arguments")
  | reply -> reply
;;

let words = String.concat " "
let pair_text (n, d) = n ^ " " ^ d

let take count items =
  let rec go count acc rest =
    if count = 0
    then List.rev acc, rest
    else (
      match rest with
      | [] -> failwith "Ledger: reply too short"
      | x :: tail -> go (count - 1) (x :: acc) tail)
  in
  go count [] items
;;

let state_length coins = 7 + (2 * coins)

let read_state coins reply =
  let state, rest = take (state_length coins) reply in
  words state, rest
;;

let read_option reply =
  match reply with
  | "none" :: rest -> None, rest
  | "some" :: value :: rest -> Some value, rest
  | _ -> failwith "Ledger: bad option"
;;

let read_receipt coins reply =
  match reply with
  | fee :: pnl :: rest ->
    let tier, rest = read_option rest in
    let rate, rest = read_option rest in
    let state, rest = read_state coins rest in
    ( { state
      ; fee = rat_of_token fee
      ; closed_pnl = rat_of_token pnl
      ; tier
      ; rate = Option.map rat_of_token rate
      }
    , rest )
  | _ -> failwith "Ledger: reply too short"
;;

let coin_count state = int_of_string (List.hd (tokens state))

let initial cash coins =
  match call "ledger_initial" (text cash ^ " " ^ string_of_int coins) with
  | "ok" :: state -> words state
  | _ -> failwith "Ledger.initial"
;;

let view state =
  match call "ledger_view" state with
  | count :: cash :: rest ->
    let coins = int_of_string count in
    let rec positions n rest =
      if n = 0
      then [], rest
      else (
        match rest with
        | units :: cost :: entry :: rest ->
          let tail, rest = positions (n - 1) rest in
          let entry = if entry = "none" then None else Some (rat_of_token entry) in
          { units = rat_of_token units; cost = rat_of_token cost; entry } :: tail, rest
        | _ -> failwith "Ledger.view: reply too short")
    in
    let positions, rest = positions coins rest in
    (match rest with
     | [ realized; fees; funding; absorbed; bankrupt ] ->
       { cash = rat_of_token cash
       ; positions
       ; realized = rat_of_token realized
       ; fees = rat_of_token fees
       ; funding = rat_of_token funding
       ; absorbed = rat_of_token absorbed
       ; bankrupt = bankrupt = "true"
       }
     | _ -> failwith "Ledger.view: bad tail")
  | _ -> failwith "Ledger.view: reply too short"
;;

let marked operation state marks =
  let arguments =
    words ((string_of_int (List.length marks) :: List.map text marks) @ [ state ])
  in
  match call operation arguments with
  | [ value ] -> rat_of_token value
  | _ -> failwith ("Ledger." ^ operation)
;;

let equity = marked "ledger_equity"
let unrealized = marked "ledger_unrealized"

let step schedule state event =
  let arguments = words (schedule_tokens schedule @ [ state ] @ event_tokens event) in
  match call "ledger_step" arguments with
  | "error" :: code :: _ -> Error code
  | "ok" :: rest ->
    let receipt, _ = read_receipt (coin_count state) rest in
    Ok receipt
  | _ -> failwith "Ledger.step: bad reply"
;;

let replay ~cash ~coins schedule events =
  let arguments =
    words
      ([ text cash; string_of_int coins ]
       @ schedule_tokens schedule
       @ (string_of_int (List.length events) :: List.concat_map event_tokens events))
  in
  match call "ledger_replay" arguments with
  | "error" :: code :: _ -> Error code
  | "ok" :: count :: rest ->
    let rec receipts n rest =
      if n = 0
      then []
      else (
        let receipt, rest = read_receipt coins rest in
        receipt :: receipts (n - 1) rest)
    in
    Ok (receipts (int_of_string count) rest)
  | _ -> failwith "Ledger.replay: bad reply"
;;
