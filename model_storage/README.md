# HDB model storage (SQLite)

A standalone SQLite version of the model-storage part of the HDB Oracle schema. It needs SQLite 3.37 or later, because every table is `STRICT`.

```sh
sqlite3 model.db < schema.sql
```

Turn on foreign key enforcement for every connection, because SQLite leaves it off by default:

```sql
PRAGMA foreign_keys = ON;
```

## Tables

| Group | Tables |
|---|---|
| Lookups | `hdb_objecttype`, `hdb_unit` |
| Site / datatype | `hdb_site`, `hdb_datatype`, `hdb_site_datatype` |
| Models | `hdb_model`, `hdb_modeltype`, `ref_model_run`, `ref_model_run_keyval` |
| Ensembles | `ref_ensemble`, `ref_ensemble_keyval`, `ref_ensemble_trace` |
| Timeseries | `m_hour`, `m_day`, `m_month`, `m_year`, `m_wy` |

## Differences from HDB schema

- The schema has no `_archive` tables, triggers, packages, sequences or synonyms.
- Columns that were `number(11)` surrogate keys are `INTEGER PRIMARY KEY`. SQLite assigns the id when a row is inserted without one.
- Every table is `STRICT`, so a value of the wrong type is rejected rather than stored as-is.
- Dates are stored as text in exactly the form `YYYY-MM-DD HH:MM:SS`, so they sort and compare correctly as strings. A `CHECK` on each date column rejects any other format (for example `2026-10-01` or `2026-10-01T00:00:00`) and impossible dates such as `2026-02-30 00:00:00`.
- `CURRENT_TIMESTAMP` defaults (`date_time_loaded`, `run_date`) are in UTC.
- Required columns that have a sensible value get a default:

  | Column | Default |
  |---|---|
  | `hdb_site.objecttype_id` | `0`, the seeded `unknown` objecttype |
  | `hdb_site.db_site_code` | `'UNK'` |
  | `hdb_datatype.unit_id` | `0`, the seeded `unknown` unit |
  | `hdb_datatype.physical_quantity_name` | `'unknown'` |
  | `hdb_datatype.allowable_intervals` | `'either'` |
  | `hdb_objecttype.objecttype_parent_order` | `0` |
  | `hdb_unit.dimension_id` | `0` |
  | `hdb_unit.is_factor` | `1` |
  | `ref_model_run.user_name` | `'unknown'` |
  | `ref_model_run.extra_keys_y_n` | `'N'` |
  | `ref_model_run.run_date`, `date_time_loaded` | `CURRENT_TIMESTAMP` |
  | `ref_model_run_keyval.date_time_loaded`, `ref_ensemble_keyval.date_time_loaded` | `CURRENT_TIMESTAMP` |

  Names, tags and timeseries values have no default and must be supplied.
- `hdb_unit.base_unit_id` can be null, which means the unit is its own base unit. In Oracle it was required.
- `m_hour`, `m_day`, `m_month`, `m_year` and `m_wy` have no `end_date_time` column. The end of each value's period is its start plus the table's interval.
- The `m_*` tables are `WITHOUT ROWID` and clustered on their composite primary key. They have no separate date indexes.
- Foreign keys to tables that aren't included here have been dropped, but their columns are kept. Those tables are `hdb_state`, `31b_river_reach`, `hdb_dimension`, `hdb_physical_quantity`, `hdb_agen` and `ref_db_list`.
- Month range and statistic tables also not included.
- These tables are not included: `ref_site_coef*`, `hdb_datatype_feature`, and the rest of the metadata and computation schema.
