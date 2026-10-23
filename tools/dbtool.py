"""Small helper to talk to the UniHub Supabase database.

Reads SUPABASE_DB_URL from the git-ignored file .env.local (or the environment).
The connection string is never printed.

Usage:
  python tools/dbtool.py ping                 check the connection
  python tools/dbtool.py apply FILE.sql       run a SQL file in ONE transaction
  python tools/dbtool.py query "select 1"     run a read-only query
  python tools/dbtool.py status               show which migrations are applied
  python tools/dbtool.py baseline V1 V2 ...   mark migrations as applied WITHOUT running them
  python tools/dbtool.py migrate              apply all pending files in supabase/migrations
"""
import os
import sys
from pathlib import Path

import psycopg

ROOT = Path(__file__).resolve().parent.parent


def load_url() -> str:
    url = os.environ.get("SUPABASE_DB_URL")
    env_file = ROOT / ".env.local"
    if not url and env_file.exists():
        for line in env_file.read_text(encoding="utf-8-sig").splitlines():
            line = line.strip()
            if line.startswith("SUPABASE_DB_URL="):
                url = line.split("=", 1)[1].strip().strip('"').strip("'")
            elif line.startswith(("postgresql://", "postgres://")):
                url = line  # a bare connection string is fine too
    if not url:
        sys.exit("No SUPABASE_DB_URL found. Create .env.local (see the setup instructions).")
    if "[YOUR-PASSWORD]" in url or "YOUR-PASSWORD" in url:
        sys.exit("The placeholder [YOUR-PASSWORD] is still in .env.local - replace it with the real password.")
    return url


def connect(**kwargs) -> psycopg.Connection:
    try:
        return psycopg.connect(load_url(), connect_timeout=15, **kwargs)
    except psycopg.OperationalError as e:
        msg = str(e).replace(load_url(), "<url>")
        # Never echo credentials; show only the server's reason.
        first = msg.strip().splitlines()[0] if msg.strip() else "connection failed"
        sys.exit(f"Could not connect: {first}")


def ensure_tracking(conn: psycopg.Connection) -> None:
    # Same table the official Supabase CLI uses, so both tools agree.
    conn.execute("create schema if not exists supabase_migrations")
    conn.execute(
        "create table if not exists supabase_migrations.schema_migrations "
        "(version text primary key, statements text[], name text)"
    )


def migration_files() -> list[Path]:
    return sorted((ROOT / "supabase" / "migrations").glob("*.sql"))


def split_name(path: Path) -> tuple[str, str]:
    version, _, name = path.stem.partition("_")
    return version, name


def main() -> None:
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    cmd = sys.argv[1]
    with connect() as conn:
        if cmd == "ping":
            row = conn.execute("select current_user, version()").fetchone()
            tables = conn.execute(
                "select count(*) from information_schema.tables where table_schema = 'public'"
            ).fetchone()[0]
            print(f"connected as {row[0]}")
            print(row[1].split(",")[0])
            print(f"public tables: {tables}")
        elif cmd == "apply" and len(sys.argv) == 3:
            sql = Path(sys.argv[2]).read_text(encoding="utf-8")
            with conn.transaction():
                conn.execute(sql)
            print("applied OK (committed)")
        elif cmd == "query" and len(sys.argv) == 3:
            with conn.transaction():
                conn.execute("set transaction read only")
                cur = conn.execute(sys.argv[2])
                if cur.description:
                    print([d.name for d in cur.description])
                    for r in cur.fetchall():
                        print(r)
        elif cmd in ("status", "baseline", "migrate"):
            with conn.transaction():
                ensure_tracking(conn)
            done = {r[0] for r in conn.execute("select version from supabase_migrations.schema_migrations")}
            files = migration_files()
            if cmd == "status":
                for f in files:
                    v, n = split_name(f)
                    print(("applied  " if v in done else "PENDING  ") + f.name)
            elif cmd == "baseline":
                for v in sys.argv[2:]:
                    match = [f for f in files if split_name(f)[0] == v]
                    if not match:
                        sys.exit(f"no migration file with version {v}")
                    with conn.transaction():
                        conn.execute(
                            "insert into supabase_migrations.schema_migrations (version, name) values (%s, %s) "
                            "on conflict do nothing", (v, split_name(match[0])[1]))
                    print("marked applied:", match[0].name)
            else:
                pending = [f for f in files if split_name(f)[0] not in done]
                if not pending:
                    print("nothing to apply")
                for f in pending:
                    v, n = split_name(f)
                    sql = f.read_text(encoding="utf-8")
                    with conn.transaction():  # all-or-nothing per file
                        conn.execute(sql)
                        conn.execute(
                            "insert into supabase_migrations.schema_migrations (version, statements, name) "
                            "values (%s, %s, %s)", (v, [sql], n))
                    print("applied:", f.name)
        else:
            sys.exit(__doc__)


if __name__ == "__main__":
    main()
