//! The committed registry's DSL inputs, which every test program is checked against.

use mm::dsl::Input;
use std::path::Path;

pub fn inputs() -> Vec<Input> {
    let reg = mm::source::registry(Path::new(concat!(env!("CARGO_MANIFEST_DIR"), "/../../sources"))).unwrap();
    mm::source::inputs(&reg)
}

pub mod store;
