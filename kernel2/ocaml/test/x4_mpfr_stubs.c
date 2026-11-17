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
#endif
#include <gmp.h>
#include <mpfr.h>
#include <stdint.h>
#include <string.h>

#ifndef MM2_TEST_REFERENCE
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
  uint64_t bits = (uint64_t)mpz_get_ui(whole);
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
  unsigned long n = (unsigned long)(-2 * x) + 300;
  for (unsigned long k = 1; k <= n; ++k) {
    mpq_mul(term, term, a);
    mpq_set_ui(divisor, k, 1);
    mpq_div(term, term, divisor);
    mpq_add(sum, sum, term);
  }
  mpq_mul(tail, term, a);
  mpq_set_ui(divisor, n + 1, 1);
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
    } else {
      mpfr_const_log2(x, MPFR_RNDN);
      mpfr_mul_si(x, x, i == 1 ? -1022 : -1075, MPFR_RNDN);
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
  mpfr_t x;
  mpfr_init2(x, 4096);
  mpfr_const_log2(x, MPFR_RNDN);
  mpfr_mul_si(x, x, -1075, MPFR_RNDN);
  double lower = mpfr_get_d(x, MPFR_RNDD), upper = mpfr_get_d(x, MPFR_RNDU);
  mpfr_clear(x);
  if (!check_subnormal(lower) || !check_subnormal(upper) ||
      bits_of(mm2_test_mpfr(0, lower)) != 0 ||
      bits_of(mm2_test_mpfr(0, upper)) != 1)
    caml_failwith("MPFR exp at the zero/min-subnormal boundary");
  CAMLreturn(Val_unit);
}

/* Test rationals use GMP, never the converter under test. kind 0 samples a
 * binade; kind 1 is a normal midpoint; kind 2 a subnormal midpoint (random is
 * the lower significand); kind 3 the subnormal/normal boundary; kind 4 is
 * the overflow midpoint plus index * 2^960, where index=-1,0,1. */
CAMLprim value mm2_test_mpfr_rational(value kind, value index, value random)
{
  CAMLparam3(kind, index, random);
  CAMLlocal3(pair, numerator, denominator);
  mpq_t q, a;
  mpq_inits(q, a, (mpq_ptr)0);
  uint64_t r = (uint64_t)Int64_val(random) & UINT64_C(0x000fffffffffffff);
  int e = Int_val(index), k = Int_val(kind);
  if (k == 0) {
    unsigned long d = (unsigned long)(UINT64_C(0x0010000000000000) | (r >> 20) | 1);
    mpq_set_ui(q, d + (unsigned long)r, d);
  } else if (k == 1) {
    unsigned long n = (unsigned long)(UINT64_C(0x0010000000000000) | r);
    mpq_set_ui(q, 2 * n + 1, 1);
    e -= 53;
  } else if (k == 2) {
    mpq_set_ui(q, (unsigned long)(2 * r + 1), 1);
    e = -1075;
  } else if (k == 3) {
    mpq_set_ui(q, (unsigned long)UINT64_C(0x001fffffffffffff), 1);
    e = -1075;
  } else {
    mpq_set_ui(q, (unsigned long)UINT64_C(0x003fffffffffffff), 1);
    mpq_mul_2exp(q, q, 970);
    mpq_set_si(a, e, 1);
    mpq_mul_2exp(a, a, 960);
    mpq_add(q, q, a);
    e = 0;
  }
  if (e < 0) mpq_div_2exp(q, q, (unsigned long)-e);
  else mpq_mul_2exp(q, q, (unsigned long)e);
  mpq_canonicalize(q);
  char *n = mpz_get_str(NULL, 10, mpq_numref(q));
  char *d = mpz_get_str(NULL, 10, mpq_denref(q));
  numerator = caml_copy_string(n);
  denominator = caml_copy_string(d);
  void (*release)(void *, size_t);
  mp_get_memory_functions(NULL, NULL, &release);
  release(n, strlen(n) + 1);
  release(d, strlen(d) + 1);
  mpq_clears(q, a, (mpq_ptr)0);
  pair = caml_alloc_tuple(2);
  Store_field(pair, 0, numerator);
  Store_field(pair, 1, denominator);
  CAMLreturn(pair);
}
#endif
