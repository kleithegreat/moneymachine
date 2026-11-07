import os, signal, sqlite3, time
from thesis.registry import Ledger

def test_reader_after_writer_killed_mid_commit(tmp_path):
    p = tmp_path / "ledger.sqlite"
    db = sqlite3.connect(p)
    db.execute("CREATE TABLE disclosures(id INTEGER PRIMARY KEY, campaign, kind, agent, created, content)")
    db.execute("INSERT INTO disclosures VALUES (1,'t','thesis','main','c','{\"id\": 1}')"); db.commit(); db.close()
    pid = os.fork()
    if pid == 0:
        w = sqlite3.connect(p, isolation_level=None); w.execute("PRAGMA cache_size=1"); w.execute("BEGIN IMMEDIATE")
        for i in range(2, 3000):
            w.execute("INSERT INTO disclosures VALUES (?,?,?,?,?,?)", (i, 't', 'thesis', 'main', 'c', '"' + 'x' * 500 + '"'))
        (tmp_path / "ready").touch(); time.sleep(100)
    while not (tmp_path / "ready").exists(): time.sleep(0.05)
    os.kill(pid, signal.SIGKILL); os.waitpid(pid, 0)
    assert (tmp_path / "ledger.sqlite-journal").exists()
    assert Ledger(p, "t", "/nonexistent").records("thesis", "main") == [(1, "c", {"id": 1})]
