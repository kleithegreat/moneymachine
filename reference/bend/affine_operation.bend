import Base

# An abstract operation used twice: the shape every model function would need.
def twice(-N: Data, f: N -> N -> N, +x: N) -> N:
  f(x, f(x, x))

def main() -> U32:
  0
