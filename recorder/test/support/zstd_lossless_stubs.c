#include <stdlib.h>
#include <string.h>
#include <zstd.h>
#include <caml/alloc.h>
#include <caml/memory.h>
#include <caml/mlvalues.h>

/* Decodes every byte of a possibly unended zstd stream: unlike the zstd CLI, keeps draining the decoder after the
   input is exhausted, so a full output buffer on the last input call loses nothing. Stops at an error or when a
   call ends with the input consumed and its output buffer not full. */
CAMLprim value mm_test_zstd_decode_lossless(value input)
{
  CAMLparam1(input);
  CAMLlocal1(result);
  size_t in_size = caml_string_length(input);
  char *in_copy = malloc(in_size ? in_size : 1);
  memcpy(in_copy, String_val(input), in_size);
  size_t capacity = 1 << 20, length = 0;
  char *out = malloc(capacity);
  ZSTD_DCtx *ctx = ZSTD_createDCtx();
  ZSTD_inBuffer in = { in_copy, in_size, 0 };
  for (;;) {
    if (capacity - length < ZSTD_DStreamOutSize()) {
      capacity *= 2;
      out = realloc(out, capacity);
    }
    ZSTD_outBuffer o = { out + length, ZSTD_DStreamOutSize(), 0 };
    size_t ret = ZSTD_decompressStream(ctx, &o, &in);
    length += o.pos;
    if (ZSTD_isError(ret)) break;
    if (in.pos == in.size && o.pos < o.size) break;
  }
  result = caml_alloc_string(length);
  memcpy(Bytes_val(result), out, length);
  ZSTD_freeDCtx(ctx);
  free(out);
  free(in_copy);
  CAMLreturn(result);
}
