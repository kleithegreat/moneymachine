/* Test 13: replace only libm exp/log at link time in the frozen reference.
 * Source evaluation, windows, constants and operation order are untouched. */
double mm2_test_mpfr(int op, double x);
double __wrap_exp(double x) { return mm2_test_mpfr(0, x); }
double __wrap_log(double x) { return mm2_test_mpfr(1, x); }
