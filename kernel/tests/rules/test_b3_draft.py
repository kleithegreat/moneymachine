"""B3's unfrozen Parquet image must preserve the case's meaning (c76-revision.md)."""

from importlib import import_module

import pytest

draft = import_module("audit.stage7.b3-draft.resolver_suite")


@pytest.mark.parametrize("text", [
    '{"extra": "\\ud800"}', '{"extra": "\\udc00"}', '{"extra": NaN}',
    '{"extra": 1, "\\u0065xtra": 2}', '{"extra": ' + '[' * 64 + '0' + ']' * 64 + '}',
])
def test_malformed_json_has_no_image_even_in_an_undeclared_member(text):
    c = draft.case([draft.BARS], [draft.rev("bars", 200, text)], 100, [], "INVALID")
    assert not draft.image(c)


def test_metadata_collisions_have_no_image_before_or_after_rule_checking():
    for c in draft.HAND:
        if c["expect"] == "E_DECL":
            assert not draft.image(c)


def test_well_formed_non_cells_and_absent_members_still_have_images():
    for text in ('{}', '{"close": [1]}', '{"close": 1e999}', '{"extra": ' + '[' * 63 + '0' + ']' * 63 + '}'):
        c = draft.case([draft.BARS], [draft.rev("bars", 200, text)], 100, [], "INVALID")
        assert draft.image(c)
