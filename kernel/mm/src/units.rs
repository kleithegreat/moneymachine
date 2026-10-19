//! Units as integer exponent vectors over base units. Time units are distinct bases,
//! so a per-hour and a per-year rate differ until explicitly converted.

use std::fmt;

pub const BASES: [&str; 5] = ["usd", "coin", "h", "d", "y"];
const TIME: [usize; 3] = [2, 3, 4];
const HOURS_PER: [f64; 3] = [1.0, 24.0, 8760.0];

#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug, Default)]
pub struct Unit(pub [i8; 5]);

impl Unit {
    pub const ONE: Unit = Unit([0; 5]);

    pub fn base(name: &str) -> Option<Unit> {
        let i = BASES.iter().position(|b| *b == name)?;
        let mut e = [0; 5];
        e[i] = 1;
        Some(Unit(e))
    }

    pub fn mul(self, o: Unit) -> Option<Unit> {
        self.zip(o, |a, b| a.checked_add(b))
    }

    pub fn div(self, o: Unit) -> Option<Unit> {
        self.zip(o, |a, b| a.checked_sub(b))
    }

    pub fn sqrt(self) -> Option<Unit> {
        let mut e = self.0;
        for x in e.iter_mut() {
            if *x % 2 != 0 {
                return None;
            }
            *x /= 2;
        }
        Some(Unit(e))
    }

    fn zip(self, o: Unit, f: impl Fn(i8, i8) -> Option<i8>) -> Option<Unit> {
        let mut e = [0; 5];
        for i in 0..5 {
            e[i] = f(self.0[i], o.0[i])?;
        }
        Some(Unit(e))
    }

    /// Factor that converts a value in `self` to `to`, if they differ only in time units
    /// and have the same total time exponent.
    pub fn conversion(self, to: Unit) -> Option<f64> {
        let non_time_equal = (0..5).filter(|i| !TIME.contains(i)).all(|i| self.0[i] == to.0[i]);
        let total = |u: Unit| TIME.iter().map(|&i| u.0[i] as i32).sum::<i32>();
        if !non_time_equal || total(self) != total(to) {
            return None;
        }
        let hours = |u: Unit| TIME.iter().zip(HOURS_PER).map(|(&i, h)| h.powi(u.0[i] as i32)).product::<f64>();
        Some(hours(self) / hours(to))
    }

    pub fn parse(s: &str) -> Option<Unit> {
        let s: String = s.chars().filter(|c| !c.is_whitespace()).collect();
        let mut parts = s.splitn(2, '/');
        let num = Self::product(parts.next()?)?;
        match parts.next() {
            None => Some(num),
            Some(den) => num.div(Self::product(den)?),
        }
    }

    fn product(s: &str) -> Option<Unit> {
        if s == "1" {
            return Some(Unit::ONE);
        }
        let mut u = Unit::ONE;
        for factor in s.split('*') {
            let (name, exp) = match factor.split_once('^') {
                Some((n, e)) => (n, e.parse::<i8>().ok()?),
                None => (factor, 1),
            };
            let b = Unit::base(name)?;
            for _ in 0..exp.unsigned_abs() {
                u = if exp > 0 { u.mul(b)? } else { u.div(b)? };
            }
        }
        Some(u)
    }
}

impl fmt::Display for Unit {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        let side = |pos: bool| {
            let v: Vec<String> = BASES
                .iter()
                .zip(self.0)
                .filter(|(_, e)| if pos { *e > 0 } else { *e < 0 })
                .map(|(b, e)| if e.abs() == 1 { b.to_string() } else { format!("{b}^{}", e.abs()) })
                .collect();
            if v.is_empty() { "1".to_string() } else { v.join("*") }
        };
        let (n, d) = (side(true), side(false));
        if d == "1" { write!(f, "{n}") } else { write!(f, "{n}/{d}") }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_and_display() {
        for s in ["1", "usd", "usd/coin", "1/h", "usd*coin/h^2", "1/y"] {
            assert_eq!(Unit::parse(s).unwrap().to_string(), s);
        }
        assert!(Unit::parse("eur").is_none());
        assert!(Unit::parse("usd/").is_none());
        assert_eq!(Unit::parse("usd/coin/h"), None);
    }

    #[test]
    fn conversions() {
        let ph = Unit::parse("1/h").unwrap();
        let py = Unit::parse("1/y").unwrap();
        assert_eq!(ph.conversion(py), Some(8760.0));
        assert_eq!(py.conversion(ph), Some(1.0 / 8760.0));
        assert_eq!(Unit::parse("usd").unwrap().conversion(Unit::parse("coin").unwrap()), None);
        assert_eq!(ph.conversion(Unit::ONE), None);
    }
}
