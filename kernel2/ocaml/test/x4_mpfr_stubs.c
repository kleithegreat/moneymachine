/* Step 5 tests ONLY. No engine object links MPFR. The same mm2_test_mpfr
 * function is linked into the frozen reference's test executable (test 13).
 * MPFR/GMP headers and libraries come from the existing pinned nixpkgs;
 * the advisor must expose them to this test derivation without moving the lock.
 * All rounding paths set 53 bits, emin=-1073, emax=1024 and subnormalize
 * with the operation's ternary result, then restore the caller's MPFR range.
 */
#ifndef MM2_TEST_REFERENCE
#include <caml/alloc.h>
#include <caml/fail.h>
#include <caml/memory.h>
#include <caml/mlvalues.h>
#include <fenv.h>
#include <gnu/libc-version.h>
#endif
#include <gmp.h>
#include <mpfr.h>
#include <stdint.h>
#include <string.h>

#ifndef MM2_TEST_REFERENCE
static void mpz_set_u64(mpz_t z, uint64_t v)
{
  mpz_import(z, 1, 1, sizeof v, 0, 0, &v);
}

static void mpz_set_i64(mpz_t z, int64_t v)
{
  uint64_t mag = v < 0 ? (uint64_t)(-(v + 1)) + UINT64_C(1) : (uint64_t)v;
  mpz_set_u64(z, mag);
  if (v < 0) mpz_neg(z, z);
}

static uint64_t mpz_get_u64(const mpz_t z)
{
  uint64_t v = 0;
  size_t count = 0;
  if (mpz_sizeinbase(z, 2) > 64)
    caml_failwith("MPFR stub u64 overflow");
  mpz_export(&v, &count, 1, sizeof v, 0, 0, z);
  return count == 0 ? 0 : v;
}

static uint64_t splitmix64(uint64_t *state)
{
  uint64_t z = (*state += UINT64_C(0x9e3779b97f4a7c15));
  z = (z ^ (z >> 30)) * UINT64_C(0xbf58476d1ce4e5b9);
  z = (z ^ (z >> 27)) * UINT64_C(0x94d049bb133111eb);
  return z ^ (z >> 31);
}

static void mpz_random_bits(mpz_t z, int bits, uint64_t *state)
{
  mpz_set_ui(z, 0);
  int remaining = bits;
  int shift = 0;
  while (remaining > 0) {
    uint64_t w = splitmix64(state);
    if (remaining < 64)
      w &= (UINT64_C(1) << remaining) - UINT64_C(1);
    mpz_t chunk;
    mpz_init(chunk);
    mpz_set_u64(chunk, w);
    mpz_mul_2exp(chunk, chunk, (mp_bitcnt_t)shift);
    mpz_add(z, z, chunk);
    mpz_clear(chunk);
    shift += 64;
    remaining -= 64;
  }
  mpz_setbit(z, (mp_bitcnt_t)(bits - 1));
}

static value return_mpq(mpq_t q)
{
  CAMLparam0();
  CAMLlocal3(pair, numerator, denominator);
  mpq_canonicalize(q);
  char *n = mpz_get_str(NULL, 10, mpq_numref(q));
  char *d = mpz_get_str(NULL, 10, mpq_denref(q));
  numerator = caml_copy_string(n);
  denominator = caml_copy_string(d);
  void (*release)(void *, size_t);
  mp_get_memory_functions(NULL, NULL, &release);
  release(n, strlen(n) + 1);
  release(d, strlen(d) + 1);
  pair = caml_alloc_tuple(2);
  Store_field(pair, 0, numerator);
  Store_field(pair, 1, denominator);
  CAMLreturn(pair);
}

static uint64_t bits_of(double x)
{
  uint64_t bits;
  memcpy(&bits, &x, sizeof bits);
  return bits;
}

static double double_of(uint64_t bits)
{
  double x;
  memcpy(&x, &bits, sizeof x);
  return x;
}

static double rounded_q(const mpq_t q)
{
  mpfr_exp_t emin = mpfr_get_emin(), emax = mpfr_get_emax();
  mpfr_t result;
  mpfr_set_emin(-1073);
  mpfr_set_emax(1024);
  mpfr_init2(result, 53);
  int ternary = mpfr_set_q(result, q, MPFR_RNDN);
  ternary = mpfr_subnormalize(result, ternary, MPFR_RNDN);
  (void)ternary;
  double out = mpfr_get_d(result, MPFR_RNDN);
  mpfr_clear(result);
  mpfr_set_emin(emin);
  mpfr_set_emax(emax);
  return out;
}
#endif

/* op=0: exp, op=1: log. Also the test-13 link boundary. */
double mm2_test_mpfr(int op, double x)
{
  mpfr_exp_t emin = mpfr_get_emin(), emax = mpfr_get_emax();
  mpfr_t argument, result;
  mpfr_set_emin(-1073);
  mpfr_set_emax(1024);
  mpfr_init2(argument, 53);
  mpfr_init2(result, 53);
  mpfr_set_d(argument, x, MPFR_RNDN);
  int ternary = op == 0 ? mpfr_exp(result, argument, MPFR_RNDN)
                        : mpfr_log(result, argument, MPFR_RNDN);
  ternary = mpfr_subnormalize(result, ternary, MPFR_RNDN);
  (void)ternary;
  double out = mpfr_get_d(result, MPFR_RNDN);
  mpfr_clears(argument, result, (mpfr_ptr)0);
  mpfr_set_emin(emin);
  mpfr_set_emax(emax);
  return out;
}

#ifndef MM2_TEST_REFERENCE
CAMLprim value mm2_test_mpfr_eval(value op, value bits)
{
  CAMLparam2(op, bits);
  CAMLreturn(caml_copy_int64((int64_t)bits_of(
    mm2_test_mpfr(Int_val(op), double_of((uint64_t)Int64_val(bits))))));
}

CAMLprim value mm2_test_mpfr_round(value pair)
{
  CAMLparam1(pair);
  mpq_t q;
  mpq_init(q);
  if (mpz_set_str(mpq_numref(q), String_val(Field(pair, 0)), 10) != 0 ||
      mpz_set_str(mpq_denref(q), String_val(Field(pair, 1)), 10) != 0 ||
      mpz_sgn(mpq_denref(q)) <= 0) {
    mpq_clear(q);
    caml_invalid_argument("test MPFR rational");
  }
  mpq_canonicalize(q);
  uint64_t bits = bits_of(rounded_q(q));
  mpq_clear(q);
  CAMLreturn(caml_copy_int64((int64_t)bits));
}

/* An independent exact-rational enclosure of exp(x), x < 0. Its ends must
 * round alike. This checks the 53-bit MPFR stub, not just mpfr_get_d twice. */
static uint64_t subnormal_bits(const mpq_t q)
{
  mpz_t numerator, whole, remainder;
  mpz_inits(numerator, whole, remainder, (mpz_ptr)0);
  mpz_mul_2exp(numerator, mpq_numref(q), 1074);
  mpz_fdiv_qr(whole, remainder, numerator, mpq_denref(q));
  mpz_mul_2exp(remainder, remainder, 1);
  int comparison = mpz_cmp(remainder, mpq_denref(q));
  if (comparison > 0 || (comparison == 0 && mpz_odd_p(whole)))
    mpz_add_ui(whole, whole, 1);
  uint64_t bits = mpz_get_u64(whole);
  mpz_clears(numerator, whole, remainder, (mpz_ptr)0);
  return bits;
}

static int check_subnormal(double x)
{
  mpq_t a, term, sum, tail, lo, hi, divisor;
  mpq_inits(a, term, sum, tail, lo, hi, divisor, (mpq_ptr)0);
  mpq_set_d(a, -x);
  mpq_set_ui(term, 1, 1);
  mpq_set_ui(sum, 1, 1);
  uint64_t n = (uint64_t)(-2 * x) + UINT64_C(300);
  for (uint64_t k = 1; k <= n; ++k) {
    mpq_mul(term, term, a);
    mpz_set_u64(mpq_numref(divisor), k);
    mpz_set_ui(mpq_denref(divisor), 1);
    mpq_div(term, term, divisor);
    mpq_add(sum, sum, term);
  }
  mpq_mul(tail, term, a);
  mpz_set_u64(mpq_numref(divisor), n + 1);
  mpz_set_ui(mpq_denref(divisor), 1);
  mpq_div(tail, tail, divisor);
  mpq_mul_2exp(tail, tail, 1);
  mpq_add(lo, sum, tail);
  mpq_inv(lo, lo);
  mpq_sub(hi, sum, tail);
  mpq_inv(hi, hi);
  uint64_t lower = subnormal_bits(lo), upper = subnormal_bits(hi);
  int conversion_ok = bits_of(rounded_q(lo)) == lower && bits_of(rounded_q(hi)) == upper;
  uint64_t got = bits_of(mm2_test_mpfr(0, x));
  mpq_clears(a, term, sum, tail, lo, hi, divisor, (mpq_ptr)0);
  return conversion_ok && lower == upper && got == lower;
}

/* Bracket each exact real boundary by adjacent binary64 arguments. */
CAMLprim value mm2_test_mpfr_boundaries(value unit)
{
  CAMLparam1(unit);
  CAMLlocal2(out, item);
  mpfr_t x, a;
  mpfr_inits2(4096, x, a, (mpfr_ptr)0);
  out = caml_alloc(6, 0);
  for (int i = 0; i < 6; ++i) Store_field(out, i, Val_unit);
  for (int i = 0; i < 3; ++i) {
    if (i == 0) {
      mpfr_set_ui(x, 2, MPFR_RNDN);
      mpfr_set_ui_2exp(a, 1, -53, MPFR_RNDN);
      mpfr_sub(x, x, a, MPFR_RNDN);
      mpfr_mul_2si(x, x, 1023, MPFR_RNDN);
      mpfr_log(x, x, MPFR_RNDN);
    } else if (i == 1) {
      mpfr_set_ui(x, 1, MPFR_RNDN);
      mpfr_set_ui_2exp(a, 1, -53, MPFR_RNDN);
      mpfr_sub(x, x, a, MPFR_RNDN);
      mpfr_mul_2si(x, x, -1022, MPFR_RNDN);
      mpfr_log(x, x, MPFR_RNDN);
    } else {
      mpfr_const_log2(x, MPFR_RNDN);
      mpfr_mul_si(x, x, -1075, MPFR_RNDN);
    }
    for (int j = 0; j < 2; ++j) {
      item = caml_copy_int64((int64_t)bits_of(mpfr_get_d(x, j == 0 ? MPFR_RNDD : MPFR_RNDU)));
      Store_field(out, 2 * i + j, item);
    }
  }
  mpfr_clears(x, a, (mpfr_ptr)0);
  CAMLreturn(out);
}

CAMLprim value mm2_test_mpfr_selfcheck(value unit)
{
  CAMLparam1(unit);
  for (int i = 0; i < 12; ++i) {
    double x = -743.0 - (double)i / 8;
    uint64_t got = bits_of(mm2_test_mpfr(0, x));
    if (got == 0 || got >= UINT64_C(0x0010000000000000) || !check_subnormal(x))
      caml_failwith("MPFR subnormal exp disagrees with exact rational enclosure");
  }
  mpfr_t x, a;
  mpfr_inits2(4096, x, a, (mpfr_ptr)0);
  mpfr_const_log2(x, MPFR_RNDN);
  mpfr_mul_si(x, x, -1075, MPFR_RNDN);
  double lower = mpfr_get_d(x, MPFR_RNDD), upper = mpfr_get_d(x, MPFR_RNDU);
  if (!check_subnormal(lower) || !check_subnormal(upper) ||
      bits_of(mm2_test_mpfr(0, lower)) != 0 ||
      bits_of(mm2_test_mpfr(0, upper)) != 1)
    caml_failwith("MPFR exp at the zero/min-subnormal boundary");
  mpfr_set_ui(x, 1, MPFR_RNDN);
  mpfr_set_ui_2exp(a, 1, -53, MPFR_RNDN);
  mpfr_sub(x, x, a, MPFR_RNDN);
  mpfr_mul_2si(x, x, -1022, MPFR_RNDN);
  mpfr_log(x, x, MPFR_RNDN);
  double sub_top = mpfr_get_d(x, MPFR_RNDD), norm_bot = mpfr_get_d(x, MPFR_RNDU);
  mpfr_clears(x, a, (mpfr_ptr)0);
  uint64_t sub_exp = bits_of(mm2_test_mpfr(0, sub_top));
  uint64_t norm_exp = bits_of(mm2_test_mpfr(0, norm_bot));
  if (sub_exp == 0 || sub_exp >= UINT64_C(0x0010000000000000) ||
      norm_exp < UINT64_C(0x0010000000000000) ||
      norm_exp >= UINT64_C(0x7FF0000000000000))
    caml_failwith("MPFR exp at the subnormal/normal boundary");
  CAMLreturn(Val_unit);
}

/* Test rationals use GMP, never the converter under test. kind 0 samples a
 * binade; kind 1 is a normal midpoint; kind 2 a subnormal midpoint (random is
 * the lower significand); kind 3 the subnormal/normal boundary; kind 4 is
 * the overflow midpoint plus index * 2^960, where index=-1,0,1; kind 5
 * samples a binade with a 100-300 bit odd denominator. */
CAMLprim value mm2_test_mpfr_rational(value kind, value index, value random)
{
  CAMLparam3(kind, index, random);
  CAMLlocal1(out);
  mpq_t q, a;
  mpq_inits(q, a, (mpq_ptr)0);
  uint64_t raw = (uint64_t)Int64_val(random);
  uint64_t r = raw & UINT64_C(0x000fffffffffffff);
  int e = Int_val(index), k = Int_val(kind);
  if (k == 0) {
    uint64_t d = UINT64_C(0x0010000000000000) | (r >> 20) | UINT64_C(1);
    mpz_set_u64(mpq_numref(q), d + r);
    mpz_set_u64(mpq_denref(q), d);
  } else if (k == 1) {
    uint64_t n = UINT64_C(0x0010000000000000) | r;
    mpz_set_u64(mpq_numref(q), UINT64_C(2) * n + UINT64_C(1));
    mpz_set_ui(mpq_denref(q), 1);
    e -= 53;
  } else if (k == 2) {
    mpz_set_u64(mpq_numref(q), UINT64_C(2) * r + UINT64_C(1));
    mpz_set_ui(mpq_denref(q), 1);
    e = -1075;
  } else if (k == 3) {
    mpz_set_u64(mpq_numref(q), UINT64_C(0x001fffffffffffff));
    mpz_set_ui(mpq_denref(q), 1);
    e = -1075;
  } else if (k == 4) {
    mpz_set_u64(mpq_numref(q), UINT64_C(0x003fffffffffffff));
    mpz_set_ui(mpq_denref(q), 1);
    mpq_mul_2exp(q, q, 970);
    mpq_set_si(a, e, 1);
    mpq_mul_2exp(a, a, 960);
    mpq_add(q, q, a);
    e = 0;
  } else if (k == 5) {
    uint64_t state = raw ^ (UINT64_C(0x9e3779b97f4a7c15) * (uint64_t)(uint32_t)e);
    int bits = 100 + (int)(splitmix64(&state) % UINT64_C(201));
    mpz_random_bits(mpq_numref(q), bits, &state);
    mpz_random_bits(mpq_denref(q), bits, &state);
    mpz_setbit(mpq_denref(q), 0);
    if (mpz_cmp(mpq_numref(q), mpq_denref(q)) < 0)
      mpz_add(mpq_numref(q), mpq_numref(q), mpq_denref(q));
  } else {
    mpq_clears(q, a, (mpq_ptr)0);
    caml_invalid_argument("unknown rational kind");
  }
  if (e < 0) mpq_div_2exp(q, q, (mp_bitcnt_t)(-e));
  else mpq_mul_2exp(q, q, (mp_bitcnt_t)e);
  out = return_mpq(q);
  mpq_clears(q, a, (mpq_ptr)0);
  CAMLreturn(out);
}

/* Compute q + (num / den) * 2^exp2 using GMP for exact midpoint +/- epsilon. */
CAMLprim value mm2_test_mpfr_offset(value pair, value num_v, value den_v, value exp2_v)
{
  CAMLparam4(pair, num_v, den_v, exp2_v);
  CAMLlocal1(out);
  mpq_t q, delta;
  mpq_inits(q, delta, (mpq_ptr)0);
  if (mpz_set_str(mpq_numref(q), String_val(Field(pair, 0)), 10) != 0 ||
      mpz_set_str(mpq_denref(q), String_val(Field(pair, 1)), 10) != 0 ||
      mpz_sgn(mpq_denref(q)) <= 0) {
    mpq_clears(q, delta, (mpq_ptr)0);
    caml_invalid_argument("test MPFR rational");
  }
  mpq_canonicalize(q);
  int64_t num = Long_val(num_v), den = Long_val(den_v);
  int exp2 = Int_val(exp2_v);
  if (den <= 0) {
    mpq_clears(q, delta, (mpq_ptr)0);
    caml_invalid_argument("test MPFR offset denominator");
  }
  mpz_set_i64(mpq_numref(delta), num);
  mpz_set_i64(mpq_denref(delta), den);
  mpq_canonicalize(delta);
  if (exp2 < 0) mpq_div_2exp(delta, delta, (mp_bitcnt_t)(-exp2));
  else mpq_mul_2exp(delta, delta, (mp_bitcnt_t)exp2);
  mpq_add(q, q, delta);
  out = return_mpq(q);
  mpq_clears(q, delta, (mpq_ptr)0);
  CAMLreturn(out);
}

CAMLprim value mm2_test_glibc_version(value unit)
{
  CAMLparam1(unit);
  CAMLreturn(caml_copy_string(gnu_get_libc_version()));
}

CAMLprim value mm2_test_round_mode(value mode_v)
{
  CAMLparam1(mode_v);
  int m = Int_val(mode_v);
  int target;
  if (m == 0) target = FE_TONEAREST;
  else if (m == 1) target = FE_UPWARD;
  else if (m == 2) target = FE_DOWNWARD;
  else if (m == 3) target = FE_TOWARDZERO;
  else caml_invalid_argument("unknown IEEE rounding mode");
  if (fesetround(target) != 0 || fegetround() != target)
    caml_failwith("fesetround failed");
  CAMLreturn(Val_unit);
}

CAMLprim value mm2_test_get_round(value unit)
{
  CAMLparam1(unit);
  int cur = fegetround();
  int code = -1;
  if (cur == FE_TONEAREST) code = 0;
  else if (cur == FE_UPWARD) code = 1;
  else if (cur == FE_DOWNWARD) code = 2;
  else if (cur == FE_TOWARDZERO) code = 3;
  CAMLreturn(Val_int(code));
}
#endif
