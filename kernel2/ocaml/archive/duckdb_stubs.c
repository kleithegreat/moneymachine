#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

#include <caml/alloc.h>
#include <caml/custom.h>
#include <caml/fail.h>
#include <caml/memory.h>
#include <caml/mlvalues.h>

#include <duckdb.h>

static duckdb_database database = NULL;
static duckdb_connection shared = NULL;

static void ensure_database(void) {
  if (database) return;
  if (duckdb_open(NULL, &database) != DuckDBSuccess) caml_failwith("duckdb_open failed");
  if (duckdb_connect(database, &shared) != DuckDBSuccess) caml_failwith("duckdb_connect failed");
}

static void run(const char *sql, duckdb_result *result) {
  ensure_database();
  if (duckdb_query(shared, sql, result) != DuckDBSuccess) {
    char message[2048];
    snprintf(message, sizeof message, "duckdb: %s", duckdb_result_error(result));
    duckdb_destroy_result(result);
    caml_failwith(message);
  }
}

CAMLprim value mm2_duckdb_exec(value sql) {
  CAMLparam1(sql);
  duckdb_result result;
  run(String_val(sql), &result);
  duckdb_destroy_result(&result);
  CAMLreturn(Val_unit);
}

CAMLprim value mm2_duckdb_scalar_int64(value sql) {
  CAMLparam1(sql);
  duckdb_result result;
  run(String_val(sql), &result);
  int64_t v = duckdb_value_int64(&result, 0, 0);
  duckdb_destroy_result(&result);
  CAMLreturn(caml_copy_int64(v));
}

CAMLprim value mm2_duckdb_scalar_string(value sql) {
  CAMLparam1(sql);
  CAMLlocal1(out);
  duckdb_result result;
  run(String_val(sql), &result);
  char *text = duckdb_value_varchar(&result, 0, 0);
  if (text) {
    out = caml_copy_string(text);
    duckdb_free(text);
  } else {
    out = caml_copy_string("");
  }
  duckdb_destroy_result(&result);
  CAMLreturn(out);
}

typedef struct {
  duckdb_connection connection;
  duckdb_prepared_statement statement;
  duckdb_result result;
  int open;
} cursor_t;

#define Cursor_val(v) (*((cursor_t **)Data_custom_val(v)))

static void cursor_close(cursor_t *c) {
  if (!c || !c->open) return;
  duckdb_destroy_result(&c->result);
  duckdb_destroy_prepare(&c->statement);
  duckdb_disconnect(&c->connection);
  c->open = 0;
}

static void cursor_finalize(value v) {
  cursor_t *c = Cursor_val(v);
  cursor_close(c);
  free(c);
}

static struct custom_operations cursor_ops = {
  "mm2.duckdb_cursor", cursor_finalize, custom_compare_default, custom_hash_default,
  custom_serialize_default, custom_deserialize_default,
  custom_compare_ext_default, custom_fixed_length_default};

CAMLprim value mm2_duckdb_open_cursor(value sql) {
  CAMLparam1(sql);
  CAMLlocal1(block);
  ensure_database();
  cursor_t *c = calloc(1, sizeof(cursor_t));
  if (duckdb_connect(database, &c->connection) != DuckDBSuccess) {
    free(c);
    caml_failwith("duckdb_connect failed");
  }
  if (duckdb_prepare(c->connection, String_val(sql), &c->statement) != DuckDBSuccess) {
    char message[2048];
    snprintf(message, sizeof message, "duckdb: %s", duckdb_prepare_error(c->statement));
    duckdb_destroy_prepare(&c->statement);
    duckdb_disconnect(&c->connection);
    free(c);
    caml_failwith(message);
  }
  if (duckdb_execute_prepared_streaming(c->statement, &c->result) != DuckDBSuccess) {
    char message[2048];
    snprintf(message, sizeof message, "duckdb: %s", duckdb_result_error(&c->result));
    duckdb_destroy_result(&c->result);
    duckdb_destroy_prepare(&c->statement);
    duckdb_disconnect(&c->connection);
    free(c);
    caml_failwith(message);
  }
  c->open = 1;
  block = caml_alloc_custom(&cursor_ops, sizeof(cursor_t *), 0, 1);
  Cursor_val(block) = c;
  CAMLreturn(block);
}

CAMLprim value mm2_duckdb_close_cursor(value cursor) {
  CAMLparam1(cursor);
  cursor_close(Cursor_val(cursor));
  CAMLreturn(Val_unit);
}

/* A batch of a quote query: columns time BIGINT and four DOUBLE[] lists. Returns None at the end, else
   Some (n, times, lens, values): times is n little-endian int64s as bytes, lens is 4n ints (bid_px, bid_sz,
   ask_px, ask_sz of each row in turn), values the four columns' doubles concatenated row after row. */
CAMLprim value mm2_duckdb_next_quotes(value cursor) {
  CAMLparam1(cursor);
  CAMLlocal5(times, lens, values, column, out);
  CAMLlocal1(some);
  cursor_t *c = Cursor_val(cursor);
  if (!c->open) CAMLreturn(Val_int(0));
  duckdb_data_chunk chunk = duckdb_fetch_chunk(c->result);
  if (!chunk) CAMLreturn(Val_int(0));
  idx_t n = duckdb_data_chunk_get_size(chunk);
  times = caml_alloc_string(n * 8);
  memcpy(Bytes_val(times), duckdb_vector_get_data(duckdb_data_chunk_get_vector(chunk, 0)), n * 8);
  lens = caml_alloc(4 * n + 1, 0);
  for (idx_t i = 0; i < 4 * n + 1; i++) Field(lens, i) = Val_long(0);
  values = caml_alloc_tuple(4);
  for (int col = 0; col < 4; col++) {
    duckdb_vector vec = duckdb_data_chunk_get_vector(chunk, col + 1);
    duckdb_list_entry *entries = (duckdb_list_entry *)duckdb_vector_get_data(vec);
    uint64_t *validity = duckdb_vector_get_validity(vec);
    duckdb_vector child = duckdb_list_vector_get_child(vec);
    double *data = (double *)duckdb_vector_get_data(child);
    size_t total = 0;
    for (idx_t i = 0; i < n; i++) {
      size_t len = (validity && !duckdb_validity_row_is_valid(validity, i)) ? 0 : entries[i].length;
      Field(lens, col * n + i) = Val_long(len);
      total += len;
    }
    column = caml_alloc(total * Double_wosize, Double_array_tag);
    size_t at = 0;
    for (idx_t i = 0; i < n; i++) {
      size_t len = Long_val(Field(lens, col * n + i));
      if (len) memcpy((double *)column + at, data + entries[i].offset, len * 8);
      at += len;
    }
    Store_field(values, col, column);
  }
  duckdb_destroy_data_chunk(&chunk);
  out = caml_alloc_tuple(4);
  Store_field(out, 0, Val_long(n));
  Store_field(out, 1, times);
  Store_field(out, 2, lens);
  Store_field(out, 3, values);
  some = caml_alloc(1, 0);
  Store_field(some, 0, out);
  CAMLreturn(some);
}
