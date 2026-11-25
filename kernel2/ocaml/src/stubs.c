#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <caml/alloc.h>
#include <caml/custom.h>
#include <caml/fail.h>
#include <caml/memory.h>
#include <caml/mlvalues.h>

#include <lean/lean.h>

lean_object *initialize_engine_Engine(uint8_t builtin);
lean_object *mm2_check(lean_object *program);
lean_object *mm2_exact_call(lean_object *op, lean_object *args);
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

CAMLprim value mm2_stub_exact(value op, value args) {
  CAMLparam2(op, args);
  CAMLlocal1(reply);
  ensure_lean();
  lean_object *lean_op = lean_mk_string_from_bytes(String_val(op), caml_string_length(op));
  lean_object *lean_args = lean_mk_string_from_bytes(String_val(args), caml_string_length(args));
  lean_object *res = mm2_exact_call(lean_op, lean_args);
  reply = caml_alloc_initialized_string(lean_string_size(res) - 1, lean_string_cstr(res));
  lean_dec(res);
  CAMLreturn(reply);
}

lean_object *mm2_machine_start(lean_object *program, lean_object *header);
lean_object *mm2_machine_feed(lean_object *state, lean_object *records, lean_object *integers, lean_object *doubles);
lean_object *mm2_machine_finish(lean_object *state);
lean_object *mm2_machine_snapshot(lean_object *state);
uint64_t mm2_machine_count(lean_object *state);
lean_object *mm2_windows_json(lean_object *unit);
lean_object *mm2_compile_windows(lean_object *text);
lean_object *mm2_machine_inspect(lean_object *header, lean_object *records, lean_object *integers, lean_object *doubles);

static void machine_finalize(value v) { lean_dec(State_val(v)); }

static struct custom_operations machine_ops = {
  "mm2.machine_state", machine_finalize, custom_compare_default, custom_hash_default,
  custom_serialize_default, custom_deserialize_default,
  custom_compare_ext_default, custom_fixed_length_default};

static value ml_string_of_lean(lean_object *s) {
  return caml_alloc_initialized_string(lean_string_size(s) - 1, lean_string_cstr(s));
}

static lean_object *lean_string_of_ml(value s) {
  return lean_mk_string_from_bytes(String_val(s), caml_string_length(s));
}

static lean_object *lean_bytes(const void *data, size_t size) {
  lean_object *a = lean_alloc_sarray(1, size, size);
  if (size > 0) memcpy(lean_sarray_cptr(a), data, size);
  return a;
}

static value wrap_state(lean_object *state) {
  CAMLparam0();
  CAMLlocal1(block);
  block = caml_alloc_custom(&machine_ops, sizeof(lean_object *), 0, 1);
  State_val(block) = state;
  CAMLreturn(block);
}

static value result_of_except(lean_object *r, int wrap) {
  CAMLparam0();
  CAMLlocal2(payload, out);
  lean_object *field = lean_ctor_get(r, 0);
  lean_inc(field);
  if (lean_ptr_tag(r) == 1) {
    payload = wrap ? wrap_state(field) : ml_string_of_lean(field);
    if (!wrap) lean_dec(field);
    out = caml_alloc(1, 0);
  } else {
    payload = ml_string_of_lean(field);
    lean_dec(field);
    out = caml_alloc(1, 1);
  }
  Store_field(out, 0, payload);
  lean_dec(r);
  CAMLreturn(out);
}

CAMLprim value mm2_stub_machine_start(value program, value header) {
  CAMLparam2(program, header);
  ensure_lean();
  lean_object *r = mm2_machine_start(lean_string_of_ml(program), lean_string_of_ml(header));
  CAMLreturn(result_of_except(r, 1));
}

CAMLprim value mm2_stub_machine_feed(value state, value records, value integers, value doubles) {
  CAMLparam4(state, records, integers, doubles);
  CAMLlocal4(block, report, trace, out);
  size_t n = Wosize_val(integers);
  int64_t *ints = malloc(n * 8 + 1);
  for (size_t i = 0; i < n; i++) ints[i] = Int64_val(Field(integers, i));
  size_t m = Wosize_val(doubles) / (Double_wosize);
  lean_object *ri = lean_bytes(Bytes_val(records), caml_string_length(records));
  lean_object *ii = lean_bytes(ints, n * 8);
  lean_object *di = lean_bytes((const double *)doubles, m * 8);
  free(ints);
  lean_inc(State_val(state));
  lean_object *r = mm2_machine_feed(State_val(state), ri, ii, di);
  lean_object *s = lean_ctor_get(r, 0);
  lean_inc(s);
  block = wrap_state(s);
  report = ml_string_of_lean(lean_ctor_get(r, 1));
  trace = ml_string_of_lean(lean_ctor_get(r, 2));
  lean_dec(r);
  out = caml_alloc_tuple(3);
  Store_field(out, 0, block);
  Store_field(out, 1, report);
  Store_field(out, 2, trace);
  CAMLreturn(out);
}

CAMLprim value mm2_stub_machine_finish(value state) {
  CAMLparam1(state);
  CAMLlocal4(report, trace, summary, out);
  lean_inc(State_val(state));
  lean_object *r = mm2_machine_finish(State_val(state));
  report = ml_string_of_lean(lean_ctor_get(r, 0));
  trace = ml_string_of_lean(lean_ctor_get(r, 1));
  summary = ml_string_of_lean(lean_ctor_get(r, 2));
  lean_dec(r);
  out = caml_alloc_tuple(3);
  Store_field(out, 0, report);
  Store_field(out, 1, trace);
  Store_field(out, 2, summary);
  CAMLreturn(out);
}

CAMLprim value mm2_stub_machine_snapshot(value state) {
  CAMLparam1(state);
  CAMLlocal1(text);
  lean_inc(State_val(state));
  lean_object *r = mm2_machine_snapshot(State_val(state));
  text = ml_string_of_lean(r);
  lean_dec(r);
  CAMLreturn(text);
}

CAMLprim value mm2_stub_machine_count(value state) {
  CAMLparam1(state);
  lean_inc(State_val(state));
  CAMLreturn(caml_copy_int64((int64_t)mm2_machine_count(State_val(state))));
}

typedef struct { lean_object **items; size_t size, cap; } stack_t;
typedef struct { lean_object **slots; size_t cap, used; } seen_t;

static int seen_add(seen_t *t, lean_object *o) {
  if ((t->used + 1) * 2 > t->cap) {
    size_t cap = t->cap ? t->cap * 2 : 1024;
    lean_object **slots = calloc(cap, sizeof(lean_object *));
    for (size_t i = 0; i < t->cap; i++) {
      lean_object *p = t->slots[i];
      if (!p) continue;
      size_t h = ((uintptr_t)p >> 4) * 11400714819323198485ull % cap;
      while (slots[h]) h = (h + 1) % cap;
      slots[h] = p;
    }
    free(t->slots);
    t->slots = slots;
    t->cap = cap;
  }
  size_t h = ((uintptr_t)o >> 4) * 11400714819323198485ull % t->cap;
  while (t->slots[h]) {
    if (t->slots[h] == o) return 0;
    h = (h + 1) % t->cap;
  }
  t->slots[h] = o;
  t->used++;
  return 1;
}

static void push(stack_t *s, lean_object *o) {
  if (s->size == s->cap) {
    s->cap = s->cap ? s->cap * 2 : 256;
    s->items = realloc(s->items, s->cap * sizeof(lean_object *));
  }
  s->items[s->size++] = o;
}

CAMLprim value mm2_stub_machine_retained(value state) {
  CAMLparam1(state);
  stack_t stack = {0, 0, 0};
  seen_t seen = {0, 0, 0};
  uint64_t total = 0;
  push(&stack, State_val(state));
  while (stack.size > 0) {
    lean_object *o = stack.items[--stack.size];
    if (lean_is_scalar(o) || o->m_rc == 0) continue;
    if (!seen_add(&seen, o)) continue;
    total += lean_object_byte_size(o);
    unsigned tag = lean_ptr_tag(o);
    if (tag <= LeanMaxCtorTag) {
      unsigned n = lean_ctor_num_objs(o);
      for (unsigned i = 0; i < n; i++) push(&stack, lean_ctor_get(o, i));
    } else if (tag == LeanArray) {
      size_t n = lean_array_size(o);
      for (size_t i = 0; i < n; i++) push(&stack, lean_array_get_core(o, i));
    }
  }
  free(stack.items);
  free(seen.slots);
  CAMLreturn(caml_copy_int64((int64_t)total));
}

CAMLprim value mm2_stub_windows_json(value unit) {
  CAMLparam1(unit);
  CAMLlocal1(text);
  ensure_lean();
  lean_object *r = mm2_windows_json(lean_box(0));
  text = ml_string_of_lean(r);
  lean_dec(r);
  CAMLreturn(text);
}

CAMLprim value mm2_stub_compile_windows(value text) {
  CAMLparam1(text);
  ensure_lean();
  CAMLreturn(result_of_except(mm2_compile_windows(lean_string_of_ml(text)), 0));
}

CAMLprim value mm2_stub_machine_inspect(value header, value records, value integers, value doubles) {
  CAMLparam4(header, records, integers, doubles);
  ensure_lean();
  size_t n = Wosize_val(integers);
  int64_t *ints = malloc(n * 8 + 1);
  for (size_t i = 0; i < n; i++) ints[i] = Int64_val(Field(integers, i));
  size_t m = Wosize_val(doubles) / (Double_wosize);
  lean_object *ri = lean_bytes(Bytes_val(records), caml_string_length(records));
  lean_object *ii = lean_bytes(ints, n * 8);
  lean_object *di = lean_bytes((const double *)doubles, m * 8);
  free(ints);
  lean_object *r = mm2_machine_inspect(lean_string_of_ml(header), ri, ii, di);
  CAMLreturn(result_of_except(r, 0));
}
