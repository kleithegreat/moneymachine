//! Reads Databento DBN files for `ingest/databento.py`; the records are kernel-only, so nothing here prints them.
//! `dbnconv outrights <out.jsonl> <file.dbn.zst>...` writes, per definition file, the raw symbols of its outright
//! futures, sorted: {"file", "outrights"}.

use dbn::decode::{DbnDecoder, DecodeRecord};
use dbn::enums::InstrumentClass;
use dbn::InstrumentDefMsg;
use std::collections::BTreeSet;
use std::io::Write;

fn outrights(path: &str) -> BTreeSet<String> {
    let mut decoder = DbnDecoder::from_zstd_file(path).expect(path);
    let mut symbols = BTreeSet::new();
    while let Some(def) = decoder.decode_record::<InstrumentDefMsg>().expect(path) {
        if matches!(def.instrument_class(), Ok(InstrumentClass::Future)) {
            symbols.insert(def.raw_symbol().expect(path).to_owned());
        }
    }
    symbols
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    assert!(args.len() >= 3 && args[1] == "outrights", "usage: dbnconv outrights <out.jsonl> <file.dbn.zst>...");
    let mut out = std::fs::File::create(&args[2]).expect(&args[2]);
    for path in &args[3..] {
        let line = serde_json::json!({"file": path, "outrights": outrights(path)});
        writeln!(out, "{line}").expect(&args[2]);
    }
}
