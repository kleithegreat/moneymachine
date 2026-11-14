#include <stdlib.h>
#include <zstd.h>
#include <caml/mlvalues.h>
#include <caml/alloc.h>
#include <caml/custom.h>
#include <caml/memory.h>
#include <caml/fail.h>

#define Cctx_val(v) (*(ZSTD_CCtx **)Data_custom_val(v))
#define Dctx_val(v) (*(ZSTD_DCtx **)Data_custom_val(v))

static void cctx_finalize(value v) { ZSTD_freeCCtx(Cctx_val(v)); }
static void dctx_finalize(value v) { ZSTD_freeDCtx(Dctx_val(v)); }

static struct custom_operations cctx_ops = {
  "mmrec.zstd.cctx", cctx_finalize, custom_compare_default, custom_hash_default,
  custom_serialize_default, custom_deserialize_default, custom_compare_ext_default,
  custom_fixed_length_default
};

static struct custom_operations dctx_ops = {
  "mmrec.zstd.dctx", dctx_finalize, custom_compare_default, custom_hash_default,
  custom_serialize_default, custom_deserialize_default, custom_compare_ext_default,
  custom_fixed_length_default
};

CAMLprim value mmrec_zstd_cctx_create(value unit)
{
  CAMLparam1(unit);
  CAMLlocal1(v);
  ZSTD_CCtx *ctx = ZSTD_createCCtx();
  if (ctx == NULL) caml_failwith("zstd: out of memory");
  ZSTD_CCtx_setParameter(ctx, ZSTD_c_compressionLevel, 9);
  ZSTD_CCtx_setParameter(ctx, ZSTD_c_checksumFlag, 1);
  v = caml_alloc_custom(&cctx_ops, sizeof(ZSTD_CCtx *), 0, 1);
  Cctx_val(v) = ctx;
  CAMLreturn(v);
}

/* One step of ZSTD_compressStream2: returns (new input position, output, bytes still to flush). */
CAMLprim value mmrec_zstd_compress_step(value cctx, value src, value pos, value ending)
{
  CAMLparam4(cctx, src, pos, ending);
  CAMLlocal3(out, result, unused);
  size_t cap = ZSTD_CStreamOutSize();
  char *buf = malloc(cap);
  if (buf == NULL) caml_failwith("zstd: out of memory");
  ZSTD_inBuffer in = { String_val(src), caml_string_length(src), Long_val(pos) };
  ZSTD_outBuffer o = { buf, cap, 0 };
  ZSTD_EndDirective mode = Bool_val(ending) ? ZSTD_e_end : ZSTD_e_flush;
  size_t remaining = ZSTD_compressStream2(Cctx_val(cctx), &o, &in, mode);
  if (ZSTD_isError(remaining)) {
    free(buf);
    caml_failwith(ZSTD_getErrorName(remaining));
  }
  out = caml_alloc_initialized_string(o.pos, buf);
  free(buf);
  result = caml_alloc_tuple(3);
  Store_field(result, 0, Val_long(in.pos));
  Store_field(result, 1, out);
  Store_field(result, 2, Val_long(remaining));
  CAMLreturn(result);
}

CAMLprim value mmrec_zstd_dctx_create(value unit)
{
  CAMLparam1(unit);
  CAMLlocal1(v);
  ZSTD_DCtx *ctx = ZSTD_createDCtx();
  if (ctx == NULL) caml_failwith("zstd: out of memory");
  v = caml_alloc_custom(&dctx_ops, sizeof(ZSTD_DCtx *), 0, 1);
  Dctx_val(v) = ctx;
  CAMLreturn(v);
}

/* One step of ZSTD_decompressStream: returns (new input position, output, its hint; 0 at the end of a frame). */
CAMLprim value mmrec_zstd_decompress_step(value dctx, value src, value pos)
{
  CAMLparam3(dctx, src, pos);
  CAMLlocal2(out, result);
  size_t cap = ZSTD_DStreamOutSize();
  char *buf = malloc(cap);
  if (buf == NULL) caml_failwith("zstd: out of memory");
  ZSTD_inBuffer in = { String_val(src), caml_string_length(src), Long_val(pos) };
  ZSTD_outBuffer o = { buf, cap, 0 };
  size_t hint = ZSTD_decompressStream(Dctx_val(dctx), &o, &in);
  if (ZSTD_isError(hint)) {
    free(buf);
    caml_failwith(ZSTD_getErrorName(hint));
  }
  out = caml_alloc_initialized_string(o.pos, buf);
  free(buf);
  result = caml_alloc_tuple(3);
  Store_field(result, 0, Val_long(in.pos));
  Store_field(result, 1, out);
  Store_field(result, 2, Val_long(hint));
  CAMLreturn(result);
}
