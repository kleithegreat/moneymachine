"""C7.6's frozen Parquet image preserves the case's meaning (audit/criteria.md, B3 revision)."""

import pytest

from kernel.tests.rules import resolver_suite as suite


@pytest.mark.parametrize("text", [
    '{"extra": "\\ud800"}', '{"extra": "\\udc00"}', '{"extra": NaN}',
    '{"extra": 1, "\\u0065xtra": 2}', '{"extra": ' + '[' * 64 + '0' + ']' * 64 + '}',
])
def test_malformed_json_has_no_image_even_in_an_undeclared_member(text):
    c = suite.case([suite.BARS], [suite.rev("bars", 200, text)], 100, [], "INVALID")
    assert not suite.image(c)


def test_metadata_collisions_have_no_image_before_or_after_rule_checking():
    for c in suite.HAND:
        if c["expect"] == "E_DECL":
            assert not suite.image(c)


def test_well_formed_non_cells_and_absent_members_still_have_images():
    for text in ('{}', '{"close": [1]}', '{"close": 1e999}', '{"extra": ' + '[' * 63 + '0' + ']' * 63 + '}'):
        c = suite.case([suite.BARS], [suite.rev("bars", 200, text)], 100, [], "INVALID")
        assert suite.image(c)
