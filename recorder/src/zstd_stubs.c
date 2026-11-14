#include <stdlib.h>
#include <zstd.h>
#include <caml/mlvalues.h>
#include <caml/alloc.h>
#include <caml/memory.h>
#include <caml/fail.h>

CAMLprim value mmrec_zstd_compress(value src)
{
  CAMLparam1(src);
  CAMLlocal1(out);
  size_t n = caml_string_length(src);
  size_t bound = ZSTD_compressBound(n);
  char *buf = malloc(bound);
  if (buf == NULL) caml_failwith("zstd: out of memory");
  size_t written = ZSTD_compress(buf, bound, String_val(src), n, 3);
  if (ZSTD_isError(written)) {
    free(buf);
    caml_failwith(ZSTD_getErrorName(written));
  }
  out = caml_alloc_initialized_string(written, buf);
  free(buf);
  CAMLreturn(out);
}

CAMLprim value mmrec_zstd_frame_size(value src, value pos)
{
  CAMLparam2(src, pos);
  size_t len = caml_string_length(src);
  size_t at = Long_val(pos);
  if (at >= len) CAMLreturn(Val_long(-1));
  size_t size = ZSTD_findFrameCompressedSize(String_val(src) + at, len - at);
  if (ZSTD_isError(size)) CAMLreturn(Val_long(-1));
  CAMLreturn(Val_long(size));
}

CAMLprim value mmrec_zstd_decompress(value src)
{
  CAMLparam1(src);
  CAMLlocal1(out);
  size_t len = caml_string_length(src);
  unsigned long long content = ZSTD_getFrameContentSize(String_val(src), len);
  if (content == ZSTD_CONTENTSIZE_ERROR || content == ZSTD_CONTENTSIZE_UNKNOWN)
    caml_failwith("zstd: frame content size unavailable");
  char *buf = malloc(content > 0 ? content : 1);
  if (buf == NULL) caml_failwith("zstd: out of memory");
  size_t got = ZSTD_decompress(buf, content, String_val(src), len);
  if (ZSTD_isError(got)) {
    free(buf);
    caml_failwith(ZSTD_getErrorName(got));
  }
  out = caml_alloc_initialized_string(got, buf);
  free(buf);
  CAMLreturn(out);
}
