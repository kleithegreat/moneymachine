#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include <caml/alloc.h>
#include <caml/custom.h>
#include <caml/fail.h>
#include <caml/memory.h>
#include <caml/mlvalues.h>

#include <lean/lean.h>

lean_object *initialize_engine_Engine(uint8_t builtin);
lean_object *mm2_check(lean_object *program);
lean_object *mm2_state_new(lean_object *unit);
lean_object *mm2_state_bump(lean_object *state);
uint64_t mm2_state_counter(lean_object *state);

static int lean_ready = 0;
static intnat created = 0;
static intnat released = 0;

static void ensure_lean(void) {
  if (lean_ready) return;
  lean_object *res = initialize_engine_Engine(1);
  if (lean_io_result_is_error(res)) caml_failwith("Lean initialization failed");
  lean_dec_ref(res);
  lean_io_mark_end_initialization();
  lean_ready = 1;
}

#define State_val(v) (*((lean_object **)Data_custom_val(v)))

static void state_finalize(value v) {
  lean_dec(State_val(v));
  released += 1;
}

static struct custom_operations state_ops = {
  "mm2.lean_state", state_finalize, custom_compare_default, custom_hash_default,
  custom_serialize_default, custom_deserialize_default,
  custom_compare_ext_default, custom_fixed_length_default};

CAMLprim value mm2_stub_state_create(value unit) {
  CAMLparam1(unit);
  CAMLlocal1(block);
  ensure_lean();
  block = caml_alloc_custom(&state_ops, sizeof(lean_object *), 0, 1);
  State_val(block) = mm2_state_new(lean_box(0));
  created += 1;
  CAMLreturn(block);
}

CAMLprim value mm2_stub_state_bump(value state) {
  CAMLparam1(state);
  State_val(state) = mm2_state_bump(State_val(state));
  CAMLreturn(Val_unit);
}

CAMLprim value mm2_stub_state_counter(value state) {
  CAMLparam1(state);
  lean_inc(State_val(state));
  CAMLreturn(Val_long((intnat)mm2_state_counter(State_val(state))));
}

CAMLprim value mm2_stub_created_total(value unit) { return Val_long(created); }

CAMLprim value mm2_stub_released_total(value unit) { return Val_long(released); }

CAMLprim value mm2_stub_check(value program) {
  CAMLparam1(program);
  CAMLlocal1(verdict);
  ensure_lean();
  lean_object *arg = lean_mk_string_from_bytes(String_val(program), caml_string_length(program));
  lean_object *res = mm2_check(arg);
  verdict = caml_alloc_initialized_string(lean_string_size(res) - 1, lean_string_cstr(res));
  lean_dec(res);
  CAMLreturn(verdict);
}
