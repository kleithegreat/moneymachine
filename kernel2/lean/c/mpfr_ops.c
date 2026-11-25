#include <lean/lean.h>
#include <mpfr.h>
#include <stdint.h>
#include <string.h>

#define MM2_POS_INF UINT64_C(0x7FF0000000000000)
#define MM2_NEG_INF UINT64_C(0xFFF0000000000000)
#define MM2_QNAN UINT64_C(0x7FF8000000000000)
#define MM2_ONE UINT64_C(0x3FF0000000000000)
#define MM2_MAG_MASK UINT64_C(0x7FFFFFFFFFFFFFFF)
#define MM2_FRAC_MASK UINT64_C(0x000FFFFFFFFFFFFF)

static int is_nan_bits(uint64_t bits)
{
  return (bits & MM2_POS_INF) == MM2_POS_INF && (bits & MM2_FRAC_MASK) != 0;
}

static double double_of_bits(uint64_t bits)
{
  double x;
  memcpy(&x, &bits, sizeof x);
  return x;
}

static uint64_t bits_of_double(double x)
{
  uint64_t bits;
  memcpy(&bits, &x, sizeof bits);
  return bits;
}

static uint64_t eval_mpfr_finite(int is_log, double x)
{
  mpfr_exp_t emin = mpfr_get_emin(), emax = mpfr_get_emax();
  mpfr_t argument, result;
  mpfr_set_emin(-1073);
  mpfr_set_emax(1024);
  mpfr_init2(argument, 53);
  mpfr_init2(result, 53);
  mpfr_set_d(argument, x, MPFR_RNDN);
  int ternary = is_log ? mpfr_log(result, argument, MPFR_RNDN)
                       : mpfr_exp(result, argument, MPFR_RNDN);
  ternary = mpfr_subnormalize(result, ternary, MPFR_RNDN);
  (void)ternary;
  uint64_t out_bits;
  if (mpfr_nan_p(result)) {
    out_bits = MM2_QNAN;
  } else if (mpfr_inf_p(result)) {
    out_bits = mpfr_sgn(result) < 0 ? MM2_NEG_INF : MM2_POS_INF;
  } else if (mpfr_zero_p(result)) {
    out_bits = 0;
  } else {
    out_bits = bits_of_double(mpfr_get_d(result, MPFR_RNDN));
  }
  mpfr_clears(argument, result, (mpfr_ptr)0);
  mpfr_set_emin(emin);
  mpfr_set_emax(emax);
  return out_bits;
}

LEAN_EXPORT uint64_t mm2_mpfr_exp(uint64_t bits)
{
  if (is_nan_bits(bits)) return MM2_QNAN;
  if (bits == MM2_POS_INF) return MM2_POS_INF;
  if (bits == MM2_NEG_INF) return 0;
  if ((bits & MM2_MAG_MASK) == 0) return MM2_ONE;
  return eval_mpfr_finite(0, double_of_bits(bits));
}

LEAN_EXPORT uint64_t mm2_mpfr_log(uint64_t bits)
{
  if (is_nan_bits(bits)) return MM2_QNAN;
  if ((bits & MM2_MAG_MASK) == 0) return MM2_NEG_INF;
  if ((bits >> 63) != 0) return MM2_QNAN;
  if (bits == MM2_POS_INF) return MM2_POS_INF;
  if (bits == MM2_ONE) return 0;
  return eval_mpfr_finite(1, double_of_bits(bits));
}
