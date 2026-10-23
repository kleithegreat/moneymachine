"""The cloud host's NTP clock log, one reading per run (mm-clock.timer, every 5 min), in the stage 5 recorder's
clock record shape so `ingest.availability.ntp_readings` reads it for the merged-window amendment of 2026-10-23."""

import sys

from ingest.live import append, now_ms
from ingest.sources_record import clock_offset_ms

sent = now_ms()
append(sys.argv[1], "sources", sent, {"source": "clock", "key": "timesyncd", "sent": sent, "recv": now_ms(),
                                      "data": {"offset_ms": clock_offset_ms()}})
