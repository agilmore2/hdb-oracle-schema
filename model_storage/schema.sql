-- HDB model storage schema (SQLite)
--
-- Extracted from the Oracle HDB schema (flyway_migration/sql/base V1_0_2,
-- V1_0_3). Covers model timeseries (M_*), model / model run metadata,
-- ensembles, and the minimum site / datatype / site_datatype tables they
-- reference.
--
-- Differences from Oracle:
--   * No _ARCHIVE tables, triggers, packages, sequences or synonyms.
--   * All tables are STRICT (requires SQLite 3.37+).
--   * Single-column surrogate keys are INTEGER PRIMARY KEY (rowid alias), so
--     SQLite assigns ids on insert in place of the populate_pk triggers.
--   * DATE columns are TEXT in the form 'YYYY-MM-DD HH:MM:SS', enforced by
--     CHECK (col IS strftime('%Y-%m-%d %H:%M:%S', col)), which also rejects
--     impossible dates such as '2026-02-30 00:00:00'.
--   * m_hour/m_day/m_month/m_year/m_wy have no end_date_time; it is implied
--     by start_date_time plus the table's interval.
--   * Required columns that have a sensible value get a DEFAULT. Foreign keys
--     to hdb_objecttype and hdb_unit default to the 'unknown' row (id 0)
--     seeded at the end of this file. Names and values stay required.
--   * hdb_unit.base_unit_id is nullable; NULL means the unit is a base unit.
--   * Foreign keys to tables outside this subset (hdb_state, hdb_river_reach,
--     hdb_dimension, hdb_physical_quantity, hdb_agen, ref_db_list) are
--     dropped; the columns are kept.
--   * Foreign keys are only enforced with PRAGMA foreign_keys = ON, which
--     must be set per connection.

PRAGMA foreign_keys = ON;

------------------------------------------------------------------------
-- Lookup tables
------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS hdb_objecttype (
    objecttype_id            INTEGER PRIMARY KEY,
    objecttype_name          TEXT    NOT NULL,
    objecttype_tag           TEXT    NOT NULL,
    objecttype_parent_order  INTEGER NOT NULL DEFAULT 0
) STRICT;

CREATE TABLE IF NOT EXISTS hdb_unit (
    unit_id                 INTEGER PRIMARY KEY,
    unit_name               TEXT    NOT NULL,
    unit_common_name        TEXT    NOT NULL,
    dimension_id            INTEGER NOT NULL DEFAULT 0,
    base_unit_id            INTEGER REFERENCES hdb_unit (unit_id),
    month_year              TEXT,
    over_month_year         TEXT,
    is_factor               INTEGER NOT NULL DEFAULT 1 CHECK (is_factor IN (0, 1)),
    mult_factor             REAL,
    from_stored_expression  TEXT,
    to_stored_expression    TEXT,
    family                  TEXT
) STRICT;

------------------------------------------------------------------------
-- Site / datatype
------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS hdb_site (
    site_id               INTEGER PRIMARY KEY,
    site_name             TEXT    NOT NULL,
    site_common_name      TEXT    NOT NULL,
    objecttype_id         INTEGER NOT NULL DEFAULT 0
        REFERENCES hdb_objecttype (objecttype_id),
    parent_site_id        INTEGER REFERENCES hdb_site (site_id),
    parent_objecttype_id  INTEGER REFERENCES hdb_objecttype (objecttype_id),
    state_id              INTEGER,
    basin_id              INTEGER REFERENCES hdb_site (site_id),
    lat                   TEXT,
    longi                 TEXT,
    hydrologic_unit       TEXT,
    segment_no            INTEGER,
    river_mile            REAL,
    elevation             REAL,
    description           TEXT,
    nws_code              TEXT,
    scs_id                TEXT,
    shef_code             TEXT,
    usgs_id               TEXT,
    db_site_code          TEXT    NOT NULL DEFAULT 'UNK'
) STRICT;

CREATE TABLE IF NOT EXISTS hdb_datatype (
    datatype_id             INTEGER PRIMARY KEY,
    datatype_name           TEXT    NOT NULL UNIQUE,
    datatype_common_name    TEXT    NOT NULL,
    physical_quantity_name  TEXT    NOT NULL DEFAULT 'unknown',
    unit_id                 INTEGER NOT NULL DEFAULT 0
        REFERENCES hdb_unit (unit_id),
    allowable_intervals     TEXT    NOT NULL DEFAULT 'either'
        CHECK (allowable_intervals IN ('non-instant', 'instant', 'either')),
    agen_id                 INTEGER,
    cmmnt                   TEXT
) STRICT;

CREATE TABLE IF NOT EXISTS hdb_site_datatype (
    site_datatype_id  INTEGER PRIMARY KEY,
    site_id           INTEGER NOT NULL REFERENCES hdb_site (site_id),
    datatype_id       INTEGER NOT NULL REFERENCES hdb_datatype (datatype_id),
    UNIQUE (site_id, datatype_id)
) STRICT;

CREATE INDEX IF NOT EXISTS site_datatype_dt_idx
    ON hdb_site_datatype (datatype_id);

------------------------------------------------------------------------
-- Models and model runs
------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS hdb_model (
    model_id     INTEGER PRIMARY KEY,
    model_name   TEXT NOT NULL,
    cmmnt        TEXT
) STRICT;

CREATE TABLE IF NOT EXISTS hdb_modeltype (
    modeltype       TEXT NOT NULL PRIMARY KEY,
    modeltype_name  TEXT NOT NULL
) STRICT;

CREATE TABLE IF NOT EXISTS ref_model_run (
    model_run_id          INTEGER PRIMARY KEY,
    model_run_name        TEXT    NOT NULL,
    model_id              INTEGER NOT NULL REFERENCES hdb_model (model_id),
    date_time_loaded      TEXT    NOT NULL DEFAULT CURRENT_TIMESTAMP
        CHECK (date_time_loaded IS strftime('%Y-%m-%d %H:%M:%S', date_time_loaded)),
    user_name             TEXT    NOT NULL DEFAULT 'unknown',
    extra_keys_y_n        TEXT    NOT NULL DEFAULT 'N'
        CHECK (extra_keys_y_n IN ('Y', 'N')),
    run_date              TEXT    NOT NULL DEFAULT CURRENT_TIMESTAMP
        CHECK (run_date IS strftime('%Y-%m-%d %H:%M:%S', run_date)),
    start_date            TEXT
        CHECK (start_date IS strftime('%Y-%m-%d %H:%M:%S', start_date)),
    end_date              TEXT
        CHECK (end_date IS strftime('%Y-%m-%d %H:%M:%S', end_date)),
    hydrologic_indicator  TEXT,
    modeltype             TEXT REFERENCES hdb_modeltype (modeltype),
    time_step_descriptor  TEXT,
    cmmnt                 TEXT
) STRICT;

CREATE TABLE IF NOT EXISTS ref_model_run_keyval (
    model_run_id      INTEGER NOT NULL REFERENCES ref_model_run (model_run_id),
    key_name          TEXT    NOT NULL,
    key_value         TEXT    NOT NULL,
    date_time_loaded  TEXT    NOT NULL DEFAULT CURRENT_TIMESTAMP
        CHECK (date_time_loaded IS strftime('%Y-%m-%d %H:%M:%S', date_time_loaded)),
    PRIMARY KEY (model_run_id, key_name)
) STRICT;

------------------------------------------------------------------------
-- Ensembles
------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS ref_ensemble (
    ensemble_id    INTEGER PRIMARY KEY,
    ensemble_name  TEXT NOT NULL,
    agen_id        INTEGER,
    trace_domain   TEXT,
    cmmnt          TEXT
) STRICT;

CREATE UNIQUE INDEX IF NOT EXISTS ref_ensemble_name_uidx
    ON ref_ensemble (ensemble_name);

CREATE TABLE IF NOT EXISTS ref_ensemble_keyval (
    ensemble_id       INTEGER NOT NULL
        REFERENCES ref_ensemble (ensemble_id) ON DELETE CASCADE,
    key_name          TEXT    NOT NULL,
    key_value         TEXT    NOT NULL,
    date_time_loaded  TEXT    NOT NULL DEFAULT CURRENT_TIMESTAMP
        CHECK (date_time_loaded IS strftime('%Y-%m-%d %H:%M:%S', date_time_loaded)),
    PRIMARY KEY (ensemble_id, key_name)
) STRICT;

CREATE TABLE IF NOT EXISTS ref_ensemble_trace (
    ensemble_id    INTEGER NOT NULL
        REFERENCES ref_ensemble (ensemble_id) ON DELETE CASCADE,
    trace_id       INTEGER NOT NULL,
    trace_numeric  REAL,
    trace_name     TEXT,
    model_run_id   INTEGER NOT NULL
        REFERENCES ref_model_run (model_run_id) ON DELETE CASCADE,
    PRIMARY KEY (ensemble_id, trace_id, model_run_id)
) STRICT;

------------------------------------------------------------------------
-- Model timeseries
------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS m_hour (
    model_run_id      INTEGER NOT NULL REFERENCES ref_model_run (model_run_id),
    site_datatype_id  INTEGER NOT NULL REFERENCES hdb_site_datatype (site_datatype_id),
    start_date_time   TEXT    NOT NULL
        CHECK (start_date_time IS strftime('%Y-%m-%d %H:%M:%S', start_date_time)),
    value             REAL    NOT NULL,
    PRIMARY KEY (model_run_id, site_datatype_id, start_date_time)
) WITHOUT ROWID, STRICT;

CREATE TABLE IF NOT EXISTS m_day (
    model_run_id      INTEGER NOT NULL REFERENCES ref_model_run (model_run_id),
    site_datatype_id  INTEGER NOT NULL REFERENCES hdb_site_datatype (site_datatype_id),
    start_date_time   TEXT    NOT NULL
        CHECK (start_date_time IS strftime('%Y-%m-%d %H:%M:%S', start_date_time)),
    value             REAL    NOT NULL,
    PRIMARY KEY (model_run_id, site_datatype_id, start_date_time)
) WITHOUT ROWID, STRICT;

CREATE TABLE IF NOT EXISTS m_month (
    model_run_id      INTEGER NOT NULL REFERENCES ref_model_run (model_run_id),
    site_datatype_id  INTEGER NOT NULL REFERENCES hdb_site_datatype (site_datatype_id),
    start_date_time   TEXT    NOT NULL
        CHECK (start_date_time IS strftime('%Y-%m-%d %H:%M:%S', start_date_time)),
    value             REAL    NOT NULL,
    PRIMARY KEY (model_run_id, site_datatype_id, start_date_time)
) WITHOUT ROWID, STRICT;

CREATE TABLE IF NOT EXISTS m_year (
    model_run_id      INTEGER NOT NULL REFERENCES ref_model_run (model_run_id),
    site_datatype_id  INTEGER NOT NULL REFERENCES hdb_site_datatype (site_datatype_id),
    start_date_time   TEXT    NOT NULL
        CHECK (start_date_time IS strftime('%Y-%m-%d %H:%M:%S', start_date_time)),
    value             REAL    NOT NULL,
    PRIMARY KEY (model_run_id, site_datatype_id, start_date_time)
) WITHOUT ROWID, STRICT;

CREATE TABLE IF NOT EXISTS m_wy (
    model_run_id      INTEGER NOT NULL REFERENCES ref_model_run (model_run_id),
    site_datatype_id  INTEGER NOT NULL REFERENCES hdb_site_datatype (site_datatype_id),
    start_date_time   TEXT    NOT NULL
        CHECK (start_date_time IS strftime('%Y-%m-%d %H:%M:%S', start_date_time)),
    value             REAL    NOT NULL,
    PRIMARY KEY (model_run_id, site_datatype_id, start_date_time)
) WITHOUT ROWID, STRICT;

------------------------------------------------------------------------
-- Seed rows that the column defaults point at
------------------------------------------------------------------------

INSERT OR IGNORE INTO hdb_objecttype
    (objecttype_id, objecttype_name, objecttype_tag, objecttype_parent_order)
VALUES (0, 'unknown', 'unk', 0);

INSERT OR IGNORE INTO hdb_unit
    (unit_id, unit_name, unit_common_name, dimension_id, base_unit_id, is_factor)
VALUES (0, 'unknown', 'unknown', 0, NULL, 1);
