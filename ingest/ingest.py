"""Extract and load EPA ICIS-Air (Clean Air Act) data into DuckDB.

The EL half of an ELT pipeline: dbt owns every transformation. This script

1. downloads the ICIS-Air bulk export from EPA ECHO (refreshed weekly),
2. checks each file's header against ``expected_schemas.json`` and stops,
   naming the added or removed columns, if EPA changed the layout,
3. loads each file into the ``raw`` schema as all-varchar tables with
   ``_loaded_at`` and ``_source_file`` audit columns, and
4. records the run in ``raw._ingest_log``.

Usage:
    python ingest/ingest.py                    # download (cached) and load
    python ingest/ingest.py --refresh          # force a fresh download
    python ingest/ingest.py --source sample    # load the committed CI sample
    python ingest/ingest.py --make-sample TN   # rebuild data/sample/ from raw
    python ingest/ingest.py --accept-schema-changes
"""

from __future__ import annotations

import argparse
import csv
import gzip
import json
import os
import sys
import urllib.request
import zipfile
from datetime import datetime, timezone
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parent.parent
RAW_DIR = ROOT / "data" / "raw" / "icis_air"
SAMPLE_DIR = ROOT / "data" / "sample"
SCHEMA_FILE = Path(__file__).resolve().parent / "expected_schemas.json"
DEFAULT_DB = os.environ.get("DUCKDB_PATH", str(ROOT / "data" / "warehouse" / "epa.duckdb"))

DOWNLOAD_URL = "https://echo.epa.gov/files/echodownloads/ICIS-AIR_downloads.zip"

# Source file -> raw table. Pollutants, stack tests and Title V certifications
# ship in the same archive but are not modelled yet.
FILES = {
    "ICIS-AIR_FACILITIES.csv": "icis_air_facilities",
    "ICIS-AIR_PROGRAMS.csv": "icis_air_programs",
    "ICIS-AIR_FCES_PCES.csv": "icis_air_evaluations",
    "ICIS-AIR_VIOLATION_HISTORY.csv": "icis_air_violations",
    "ICIS-AIR_FORMAL_ACTIONS.csv": "icis_air_formal_actions",
    "ICIS-AIR_INFORMAL_ACTIONS.csv": "icis_air_informal_actions",
}


class SchemaDriftError(RuntimeError):
    pass


def log(msg: str) -> None:
    print(f"[ingest] {msg}", flush=True)


def download(refresh: bool) -> str | None:
    """Download and extract the archive; return the server's Last-Modified."""
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    archive = RAW_DIR.parent / "icis_air.zip"
    last_modified = None
    if refresh or not archive.exists():
        log(f"downloading {DOWNLOAD_URL}")
        with urllib.request.urlopen(DOWNLOAD_URL, timeout=600) as resp, open(archive, "wb") as out:
            last_modified = resp.headers.get("Last-Modified")
            while chunk := resp.read(1 << 20):
                out.write(chunk)
    else:
        log(f"using cached {archive.relative_to(ROOT)} (pass --refresh to re-download)")
    with zipfile.ZipFile(archive) as zf:
        for name in FILES:
            zf.extract(name, RAW_DIR)
    return last_modified


def read_header(path: Path) -> list[str]:
    opener = gzip.open if path.suffix == ".gz" else open
    with opener(path, "rt", newline="", encoding="utf-8") as f:
        return next(csv.reader(f))


def check_schemas(paths: dict[str, Path], accept: bool) -> None:
    expected = json.loads(SCHEMA_FILE.read_text()) if SCHEMA_FILE.exists() else {}
    drift = []
    for name, path in paths.items():
        actual = read_header(path)
        if name not in expected:
            expected[name] = actual
            log(f"recorded schema for {name} ({len(actual)} columns)")
            continue
        want = expected[name]
        added = [c for c in actual if c not in want]
        removed = [c for c in want if c not in actual]
        if added or removed:
            drift.append((name, added, removed))
            if accept:
                expected[name] = actual
        elif actual != want:
            log(f"note: {name} columns reordered (loaded by name, no action needed)")
    for name, added, removed in drift:
        log(f"SCHEMA DRIFT in {name}: added={added or '-'} removed={removed or '-'}")
    if drift and not accept:
        raise SchemaDriftError(
            "source schema changed; review the columns above, update the staging models, "
            "then rerun with --accept-schema-changes"
        )
    SCHEMA_FILE.write_text(json.dumps(expected, indent=2) + "\n")


def load(paths: dict[str, Path], db_path: str, source: str, last_modified: str | None) -> None:
    Path(db_path).parent.mkdir(parents=True, exist_ok=True)
    loaded_at = datetime.now(timezone.utc).replace(tzinfo=None)
    con = duckdb.connect(db_path)
    con.execute("create schema if not exists raw")
    con.execute(
        """create table if not exists raw._ingest_log (
            loaded_at timestamp, source varchar, file_name varchar,
            table_name varchar, row_count bigint, source_last_modified varchar)"""
    )
    for name, path in paths.items():
        table = FILES[name]
        con.execute(
            f"""create or replace table raw.{table} as
                select *, ?::timestamp as _loaded_at, ? as _source_file
                from read_csv(?, all_varchar = true, header = true)""",
            [loaded_at, name, str(path)],
        )
        rows = con.execute(f"select count(*) from raw.{table}").fetchone()[0]
        con.execute(
            "insert into raw._ingest_log values (?, ?, ?, ?, ?, ?)",
            [loaded_at, source, name, table, rows, last_modified],
        )
        log(f"loaded raw.{table}: {rows:,} rows")
    con.close()


def make_sample(state: str) -> None:
    """Write a single-state slice of every file to data/sample/ for CI."""
    SAMPLE_DIR.mkdir(parents=True, exist_ok=True)
    con = duckdb.connect()
    facilities = RAW_DIR / "ICIS-AIR_FACILITIES.csv"
    con.execute(
        "create table ids as select pgm_sys_id from read_csv(?, all_varchar = true, header = true) "
        "where state = ?",
        [str(facilities), state],
    )
    for name in FILES:
        out = SAMPLE_DIR / f"{name}.gz"
        con.execute(
            f"""copy (
                    select src.* from read_csv('{RAW_DIR / name}', all_varchar = true, header = true) as src
                    semi join ids using (pgm_sys_id)
                ) to '{out}' (format csv, header true, compression gzip, force_quote *)"""
        )
        rows = con.execute(f"select count(*) from read_csv('{out}', all_varchar = true)").fetchone()[0]
        log(f"sample {out.relative_to(ROOT)}: {rows:,} rows")
    con.close()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--source", choices=["remote", "sample"], default="remote")
    parser.add_argument("--db", default=DEFAULT_DB, help="DuckDB file (default: $DUCKDB_PATH or data/warehouse/epa.duckdb)")
    parser.add_argument("--refresh", action="store_true", help="re-download even if a cached archive exists")
    parser.add_argument("--accept-schema-changes", action="store_true")
    parser.add_argument("--make-sample", metavar="STATE", help="rebuild data/sample/ for one state, then exit")
    args = parser.parse_args()

    if args.make_sample:
        make_sample(args.make_sample.upper())
        return 0

    last_modified = None
    if args.source == "remote":
        last_modified = download(args.refresh)
        paths = {name: RAW_DIR / name for name in FILES}
    else:
        paths = {name: SAMPLE_DIR / f"{name}.gz" for name in FILES}
        missing = [str(p) for p in paths.values() if not p.exists()]
        if missing:
            log(f"sample files missing: {missing}")
            return 1

    try:
        check_schemas(paths, args.accept_schema_changes)
    except SchemaDriftError as exc:
        log(str(exc))
        return 2
    load(paths, args.db, args.source, last_modified)
    return 0


if __name__ == "__main__":
    sys.exit(main())
