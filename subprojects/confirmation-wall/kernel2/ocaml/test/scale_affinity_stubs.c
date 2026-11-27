/* Test harness only: pin before exec, so every worker thread inherits one
   core without requiring taskset (not among the flake's build inputs). */
#define _GNU_SOURCE
#include <sched.h>
#include <unistd.h>
#include <caml/mlvalues.h>
#include <caml/fail.h>

CAMLprim value mm2_test_pin_one_core(value unit)
{
    (void)unit;
    cpu_set_t allowed;
    if (sched_getaffinity(0, sizeof(allowed), &allowed) != 0)
        caml_failwith("test sched_getaffinity failed");
    int chosen = -1;
    for (int cpu = 0; cpu < CPU_SETSIZE; ++cpu) {
        if (CPU_ISSET(cpu, &allowed)) {
            chosen = cpu;
            break;
        }
    }
    if (chosen < 0)
        caml_failwith("test worker has no allowed CPU");
    cpu_set_t single;
    CPU_ZERO(&single);
    CPU_SET(chosen, &single);
    if (sched_setaffinity(0, sizeof(single), &single) != 0)
        caml_failwith("test sched_setaffinity failed");
    return Val_unit;
}
