#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <zstd.h>
#include <caml/alloc.h>
#include <caml/callback.h>
#include <caml/fail.h>
#include <caml/memory.h>
#include <caml/mlvalues.h>

static void raise_zstd(const char *msg)
{
  const value *exn = caml_named_value("mmfabric.zstd.error");
  if (exn != NULL) {
    caml_raise_with_string(*exn, msg);
  }
  caml_failwith(msg);
}

CAMLprim value mmfabric_zstd_compress(value v_src, value v_level)
{
  CAMLparam2(v_src, v_level);
  CAMLlocal1(out);

  size_t src_len = caml_string_length(v_src);
  size_t cap = ZSTD_compressBound(src_len);
  if (cap == 0) cap = 1;
  char *dst = malloc(cap);
  if (dst == NULL) {
    raise_zstd("zstd: out of memory");
  }

  size_t written = ZSTD_compress(dst, cap, String_val(v_src), src_len, Int_val(v_level));
  if (ZSTD_isError(written)) {
    const char *err = ZSTD_getErrorName(written);
    free(dst);
    raise_zstd(err);
  }

  out = caml_alloc_initialized_string(written, dst);
  free(dst);
  CAMLreturn(out);
}

CAMLprim value mmfabric_zstd_decompress(value v_src)
{
  CAMLparam1(v_src);
  CAMLlocal1(out);

  size_t src_len = caml_string_length(v_src);
  if (src_len == 0) {
    raise_zstd("zstd: empty input");
  }

  ZSTD_DCtx *dctx = ZSTD_createDCtx();
  if (dctx == NULL) {
    raise_zstd("zstd: out of memory");
  }

  size_t chunk_cap = ZSTD_DStreamOutSize();
  if (chunk_cap == 0) chunk_cap = 16384;
  char *chunk = malloc(chunk_cap);
  if (chunk == NULL) {
    ZSTD_freeDCtx(dctx);
    raise_zstd("zstd: out of memory");
  }

  size_t out_cap = chunk_cap;
  char *out_buf = malloc(out_cap);
  if (out_buf == NULL) {
    free(chunk);
    ZSTD_freeDCtx(dctx);
    raise_zstd("zstd: out of memory");
  }

  size_t total = 0;
  size_t last_hint = 1;
  ZSTD_inBuffer in = { String_val(v_src), src_len, 0 };

  while (in.pos < in.size) {
    ZSTD_outBuffer o = { chunk, chunk_cap, 0 };
    size_t hint = ZSTD_decompressStream(dctx, &o, &in);
    if (ZSTD_isError(hint)) {
      const char *err = ZSTD_getErrorName(hint);
      free(out_buf);
      free(chunk);
      ZSTD_freeDCtx(dctx);
      raise_zstd(err);
    }
    if (o.pos > 0) {
      if (total > SIZE_MAX - o.pos) {
        free(out_buf);
        free(chunk);
        ZSTD_freeDCtx(dctx);
        raise_zstd("zstd: output overflow");
      }
      size_t needed = total + o.pos;
      if (needed > out_cap) {
        size_t new_cap = out_cap;
        while (new_cap < needed) {
          if (new_cap > SIZE_MAX / 2) {
            new_cap = needed;
            break;
          }
          new_cap *= 2;
        }
        char *grown = realloc(out_buf, new_cap);
        if (grown == NULL) {
          free(out_buf);
          free(chunk);
          ZSTD_freeDCtx(dctx);
          raise_zstd("zstd: out of memory");
        }
        out_buf = grown;
        out_cap = new_cap;
      }
      memcpy(out_buf + total, chunk, o.pos);
      total += o.pos;
    }
    last_hint = hint;
    if (o.pos == 0 && hint == 0 && in.pos == in.size) {
      break;
    }
  }

  /* Drain any buffered output if Zstd requested another flush call. */
  while (last_hint > 0 && in.pos == in.size) {
    ZSTD_outBuffer o = { chunk, chunk_cap, 0 };
    size_t hint = ZSTD_decompressStream(dctx, &o, &in);
    if (ZSTD_isError(hint)) {
      const char *err = ZSTD_getErrorName(hint);
      free(out_buf);
      free(chunk);
      ZSTD_freeDCtx(dctx);
      raise_zstd(err);
    }
    if (o.pos > 0) {
      size_t needed = total + o.pos;
      if (needed > out_cap) {
        char *grown = realloc(out_buf, needed);
        if (grown == NULL) {
          free(out_buf);
          free(chunk);
          ZSTD_freeDCtx(dctx);
          raise_zstd("zstd: out of memory");
        }
        out_buf = grown;
        out_cap = needed;
      }
      memcpy(out_buf + total, chunk, o.pos);
      total += o.pos;
    }
    last_hint = hint;
    if (o.pos == 0 && hint > 0) {
      free(out_buf);
      free(chunk);
      ZSTD_freeDCtx(dctx);
      raise_zstd("zstd: truncated frame");
    }
  }

  if (last_hint != 0) {
    free(out_buf);
    free(chunk);
    ZSTD_freeDCtx(dctx);
    raise_zstd("zstd: truncated frame");
  }

  out = caml_alloc_initialized_string(total, total > 0 ? out_buf : "");
  free(out_buf);
  free(chunk);
  ZSTD_freeDCtx(dctx);
  CAMLreturn(out);
}
