namespace Engine

/-- The verdict on a program's text: `ok`, or one line starting `rejected:`. Step 0 admits the header alone. -/
@[export mm2_check]
def check (program : String) : String :=
  if (program.splitOn "\n").head? = some "mm2-program 0" then
    "ok"
  else
    "rejected: the first line is not `mm2-program 0`"

end Engine
