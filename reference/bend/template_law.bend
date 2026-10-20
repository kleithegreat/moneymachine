import Base

def twice(~f: U32 -> U32 -> U32, +x: U32) -> U32:
  f(x, f(x, x))

law twice_same:
  for g: U32 -> U32 -> U32
  for +x: U32
  {twice(~g, x) == g(x, g(x, x)) : U32}

def twice_same(g, x):
  {==}

def main() -> U32:
  0
