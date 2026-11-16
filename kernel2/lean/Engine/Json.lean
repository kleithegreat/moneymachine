

namespace Engine.Json

/-- A JSON value, as strict as KERNEL.md's header and program: integers only, no repeated key. -/
inductive J where
  | null
  | bool (value : Bool)
  | int (value : Int)
  | str (value : String)
  | arr (items : List J)
  | obj (members : List (String × J))
  deriving Repr

abbrev Chars := List Char

/-- A string's characters, read from its bytes so that the kernel meets a list and not an indexed array. -/
def chars (text : String) : List Char := text.toByteArray.data.toList.map fun b => Char.ofNat b.toNat

def isSpace (c : Char) : Bool := c == ' ' || c == '\n' || c == '\r' || c == '\t'

def skipSpace : Chars → Chars
  | c :: rest => if isSpace c then skipSpace rest else c :: rest
  | [] => []

def isDigit (c : Char) : Bool := '0' ≤ c && c ≤ '9'

def hexValue (c : Char) : Option Nat :=
  if '0' ≤ c && c ≤ '9' then some (c.toNat - '0'.toNat)
  else if 'a' ≤ c && c ≤ 'f' then some (c.toNat - 'a'.toNat + 10)
  else if 'A' ≤ c && c ≤ 'F' then some (c.toNat - 'A'.toNat + 10)
  else none

inductive Tok where
  | open_obj | close_obj | open_arr | close_arr | comma | colon
  | str (value : String) | int (value : Int) | lit (value : J)

/-- The lexer's position inside a token. -/
inductive Lex where
  | between
  | text (acc : List Char)
  | escape (acc : List Char)
  | unicode (acc : List Char) (digits : List Nat)
  | number (negative : Bool) (value : Nat) (count : Nat)
  | word (rest : List Char) (value : J)

structure LexState where
  tokens : List Tok
  mode : Lex

def numberToken (negative : Bool) (value : Nat) : Tok :=
  Tok.int (if negative then -(value : Int) else (value : Int))

/-- A character met between tokens. -/
def between (st : List Tok) (c : Char) : Except String LexState :=
  if isSpace c then .ok ⟨st, .between⟩
  else if c == '{' then .ok ⟨Tok.open_obj :: st, .between⟩
  else if c == '}' then .ok ⟨Tok.close_obj :: st, .between⟩
  else if c == '[' then .ok ⟨Tok.open_arr :: st, .between⟩
  else if c == ']' then .ok ⟨Tok.close_arr :: st, .between⟩
  else if c == ',' then .ok ⟨Tok.comma :: st, .between⟩
  else if c == ':' then .ok ⟨Tok.colon :: st, .between⟩
  else if c == '"' then .ok ⟨st, .text []⟩
  else if c == '-' then .ok ⟨st, .number true 0 0⟩
  else if isDigit c then .ok ⟨st, .number false (c.toNat - '0'.toNat) 1⟩
  else if c == 't' then .ok ⟨st, .word (chars "rue") (J.bool true)⟩
  else if c == 'f' then .ok ⟨st, .word (chars "alse") (J.bool false)⟩
  else if c == 'n' then .ok ⟨st, .word (chars "ull") J.null⟩
  else .error "unexpected character"

def lexStep (st : LexState) (c : Char) : Except String LexState :=
  match st.mode with
  | .between => between st.tokens c
  | .text acc =>
    if c == '"' then .ok ⟨Tok.str (String.ofList acc.reverse) :: st.tokens, .between⟩
    else if c == '\\' then .ok ⟨st.tokens, .escape acc⟩
    else if c.toNat < 32 then .error "control character in string"
    else .ok ⟨st.tokens, .text (c :: acc)⟩
  | .escape acc =>
    if c == 'u' then .ok ⟨st.tokens, .unicode acc []⟩
    else if c == '"' then .ok ⟨st.tokens, .text ('"' :: acc)⟩
    else if c == '\\' then .ok ⟨st.tokens, .text ('\\' :: acc)⟩
    else if c == '/' then .ok ⟨st.tokens, .text ('/' :: acc)⟩
    else if c == 'b' then .ok ⟨st.tokens, .text ('\x08' :: acc)⟩
    else if c == 'f' then .ok ⟨st.tokens, .text ('\x0c' :: acc)⟩
    else if c == 'n' then .ok ⟨st.tokens, .text ('\n' :: acc)⟩
    else if c == 'r' then .ok ⟨st.tokens, .text ('\r' :: acc)⟩
    else if c == 't' then .ok ⟨st.tokens, .text ('\t' :: acc)⟩
    else .error "bad escape"
  | .unicode acc digits =>
    match hexValue c with
    | none => .error "bad unicode escape"
    | some d =>
      let digits' := d :: digits
      if digits'.length < 4 then .ok ⟨st.tokens, .unicode acc digits'⟩
      else
        let code := digits'.reverse.foldl (fun n x => n * 16 + x) 0
        if h : code.isValidChar then .ok ⟨st.tokens, .text (Char.ofNatAux code h :: acc)⟩
        else .error "bad unicode escape"
  | .number negative value count =>
    if isDigit c then
      if count == 1 && value == 0 then .error "leading zero"
      else .ok ⟨st.tokens, .number negative (value * 10 + (c.toNat - '0'.toNat)) (count + 1)⟩
    else if count == 0 then .error "bad number"
    else if c == '.' || c == 'e' || c == 'E' then .error "not an integer"
    else between (numberToken negative value :: st.tokens) c
  | .word rest value =>
    match rest with
    | [] => .error "bad literal"
    | w :: more =>
      if w == c then
        if more.isEmpty then .ok ⟨Tok.lit value :: st.tokens, .between⟩ else .ok ⟨st.tokens, .word more value⟩
      else .error "bad literal"

def lex (text : String) : Except String (List Tok) := do
  if (chars text).any (fun c => 127 < c.toNat) then .error "non-ASCII text"
  let st ← (chars text).foldlM lexStep ⟨[], .between⟩
  match st.mode with
  | .between => .ok st.tokens.reverse
  | .number negative value count =>
    if count == 0 then .error "bad number" else .ok (numberToken negative value :: st.tokens).reverse
  | _ => .error "unterminated token"

/-- Where the reader is: before a value, before a key, after a key, or after a value. -/
inductive Mode where
  | value | valueOrClose | key | keyOrClose | colon | after

inductive Frame where
  | arr (items : List J)
  | obj (members : List (String × J)) (pending : Option String)

structure Reader where
  stack : List Frame
  mode : Mode
  result : Option J

/-- A finished value goes to its container, or is the result. -/
def complete (r : Reader) (v : J) : Except String Reader :=
  match r.stack with
  | [] => if r.result.isSome then .error "trailing value" else .ok ⟨[], .after, some v⟩
  | .arr items :: up => .ok ⟨.arr (v :: items) :: up, .after, r.result⟩
  | .obj ms (some k) :: up => .ok ⟨.obj ((k, v) :: ms) none :: up, .after, r.result⟩
  | .obj _ none :: _ => .error "a value without a key"

def readTok (r : Reader) (t : Tok) : Except String Reader :=
  match r.mode, t with
  | .value, .str s | .valueOrClose, .str s => complete r (J.str s)
  | .value, .int n | .valueOrClose, .int n => complete r (J.int n)
  | .value, .lit v | .valueOrClose, .lit v => complete r v
  | .value, .open_arr | .valueOrClose, .open_arr => .ok ⟨.arr [] :: r.stack, .valueOrClose, r.result⟩
  | .value, .open_obj | .valueOrClose, .open_obj => .ok ⟨.obj [] none :: r.stack, .keyOrClose, r.result⟩
  | .valueOrClose, .close_arr =>
    match r.stack with
    | .arr [] :: up => complete ⟨up, r.mode, r.result⟩ (J.arr [])
    | _ => .error "unexpected ]"
  | .key, .str k | .keyOrClose, .str k =>
    match r.stack with
    | .obj ms none :: up =>
      if ms.any (fun p => p.1 == k) then .error "repeated key"
      else .ok ⟨.obj ms (some k) :: up, .colon, r.result⟩
    | _ => .error "unexpected key"
  | .keyOrClose, .close_obj =>
    match r.stack with
    | .obj [] none :: up => complete ⟨up, r.mode, r.result⟩ (J.obj [])
    | _ => .error "unexpected }"
  | .colon, .colon => .ok ⟨r.stack, .value, r.result⟩
  | .after, .comma =>
    match r.stack with
    | .arr _ :: _ => .ok ⟨r.stack, .value, r.result⟩
    | .obj _ _ :: _ => .ok ⟨r.stack, .key, r.result⟩
    | [] => .error "unexpected ,"
  | .after, .close_arr =>
    match r.stack with
    | .arr items :: up => complete ⟨up, r.mode, r.result⟩ (J.arr items.reverse)
    | _ => .error "unexpected ]"
  | .after, .close_obj =>
    match r.stack with
    | .obj ms _ :: up => complete ⟨up, r.mode, r.result⟩ (J.obj ms.reverse)
    | _ => .error "unexpected }"
  | _, _ => .error "unexpected token"

/-- The whole text as one value, strictly: integers only, no repeated key, nothing after it. -/
def parse (text : String) : Except String J := do
  let tokens ← lex text
  let r ← tokens.foldlM readTok ⟨[], .value, none⟩
  match r.stack, r.result with
  | [], some v => .ok v
  | _, _ => .error "incomplete document"

def J.field? : J → String → Option J
  | .obj ms, key => (ms.find? (fun p => p.1 == key)).map (·.2)
  | _, _ => none

/-- The object's keys are exactly `required` and, besides them, any of `optional`. -/
def J.keysAre (j : J) (required optional : List String) : Bool :=
  match j with
  | .obj ms =>
    required.all (fun k => ms.any (fun p => p.1 == k)) &&
      ms.all (fun p => required.contains p.1 || optional.contains p.1)
  | _ => false

def escape (s : String) : String :=
  String.ofList (s.toList.flatMap fun c =>
    if c == '"' then ['\\', '"']
    else if c == '\\' then ['\\', '\\']
    else if c.toNat < 32 then ['?']
    else [c])

end Engine.Json
