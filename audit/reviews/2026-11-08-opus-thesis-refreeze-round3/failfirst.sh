#!/usr/bin/env bash
# For each fix commit: tree at the commit with its non-test files reverted to the parent; run the commit's new tests.
set -u
REPO=/home/kevin/repos/mm-rv-rf
run() { c=$1; shift; d=/tmp/rf3/ff-$c; rm -rf $d; mkdir -p $d
  git -C $REPO archive $c | tar -x -C $d
  for f in $(git -C $REPO show --format= --name-only $c | grep -v '/tests/\|test_\|\.md$\|\.pdf$\|\.tex$'); do
    git -C $REPO show $c^:$f > $d/$f 2>/dev/null || rm -f $d/$f; done
  echo "=== $c (source reverted to parent): $*"
  (cd $d && TMPDIR=/tmp/rf3/tmp timeout 900 pytest -q -p no:cacheprovider "$@" 2>&1 | tail -6)
  echo "=== $c (as committed): $*"
  d2=/tmp/rf3/ok-$c; rm -rf $d2; mkdir -p $d2; git -C $REPO archive $c | tar -x -C $d2
  (cd $d2 && TMPDIR=/tmp/rf3/tmp timeout 900 pytest -q -p no:cacheprovider "$@" 2>&1 | tail -3)
}
mkdir -p /tmp/rf3/tmp
run ac31ca2 thesis/tests/test_registry.py -k "hot_journal or literal_filename"
run 8b2007f ingest/tests/test_hl.py -k "recorder_requests_keep or only_returned_items"
run b09073d ingest/tests/test_hl.py -k "malformed_successful"
run 9b6871b thesis/tests/test_market.py -k "parse_each_archive_record_once or incomplete_appends"
run 576383b sandbox/tests/test_canary.py -k "killed_session_without or never_hides or tilde"
run 3a0d398 sandbox/tests/test_canary.py -k "after_daemon_receipt"
run a364804 thesis/tests/test_market.py -k "oversized_inventory or failed_discovery or largest_admissible"
run e6bc37b thesis/tests/test_market.py thesis/tests/test_runner.py -k "early_scheduler or early_wakeup"
run d4c6d6b thesis/tests/test_market.py -k "retry_admission_includes"
run 5a9b6f3 thesis/tests/test_market.py ops/test_live.py -k "certified_ip_remainder or shared_ip_allocation or cold_registration_funding"
