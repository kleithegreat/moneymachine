from hypothesis import given, settings, strategies as st

from ingest.witness import Book


@settings(max_examples=300, deadline=None)
@given(st.lists(st.tuples(st.sampled_from("AB"), st.floats(-5, 5).filter(lambda q: abs(q) > 1e-6),
                          st.floats(50, 150), st.floats(-0.01, 0.01)), min_size=1, max_size=30))
def test_cash_equity_reconciles_with_entry_accounting(events):
    book, marks = Book(), {}
    for coin, qty, price, rate in events:
        book.fill(coin, qty, price, fee=abs(qty) * price * 0.00045)
        marks[coin] = price
        book.settle(coin, price, rate)
        e1, e2 = book.equity(marks), book.reconciled(marks)
        assert abs(e1 - e2) <= 1e-9 * max(1.0, abs(e1))
