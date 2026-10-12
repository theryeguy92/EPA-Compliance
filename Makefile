# Common tasks. Every target runs inside the uv-managed environment.
export DBT_PROFILES_DIR := profiles
UV := uv run

.PHONY: setup ingest ingest-sample build test docs lint fmt ci clean

setup:            ## install Python deps and dbt packages
	uv sync
	$(UV) dbt deps

ingest:           ## download the full EPA ICIS-Air export and load data/warehouse/epa.duckdb
	$(UV) python ingest/ingest.py

ingest-sample:    ## load the committed Tennessee sample (what CI runs on)
	DUCKDB_PATH=data/warehouse/ci.duckdb $(UV) python ingest/ingest.py --source sample

build:            ## run models, snapshots and tests against the full dataset
	$(UV) dbt source freshness
	$(UV) dbt build

test:             ## tests only
	$(UV) dbt test

docs:             ## build and serve the docs site locally
	$(UV) dbt docs generate
	$(UV) dbt docs serve

lint:             ## lint SQL (needs a loaded warehouse for the dbt templater)
	DUCKDB_PATH=data/warehouse/ci.duckdb $(UV) sqlfluff lint models tests

fmt:              ## auto-fix lint issues
	DUCKDB_PATH=data/warehouse/ci.duckdb $(UV) sqlfluff fix models tests

ci: ingest-sample ## reproduce the CI build locally
	DUCKDB_PATH=data/warehouse/ci.duckdb $(UV) dbt source freshness --target ci
	DUCKDB_PATH=data/warehouse/ci.duckdb $(UV) dbt build --target ci
	DUCKDB_PATH=data/warehouse/ci.duckdb $(UV) sqlfluff lint models tests

clean:
	$(UV) dbt clean
	rm -f data/warehouse/*.duckdb data/warehouse/*.wal
