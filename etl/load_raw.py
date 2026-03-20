import os
import re
from datetime import datetime
from pathlib import Path

import pandas as pd
import psycopg2
from psycopg2 import sql

# --- Config ---
DB_CONFIG = {
    "host": "localhost",
    "port": 5432,
    "dbname": "nexusflow",
    "user": "postgres",
    "password": os.environ["PG_PASSWORD"],
}

DATA_ROOT = Path(__file__).parent.parent / "data"
BATCHES = ["batch_1", "batch_2", "batch_3"]
SENTINEL_VALUES = ["-", "N/A", "n/a", ""]


def to_table_name(batch: str, filename: str) -> str:
    stem = Path(filename).stem
    safe = re.sub(r"[^a-z0-9_]", "_", stem.lower())
    return f"{batch}_{safe}"


def load_csv(path: Path, batch_id: int) -> pd.DataFrame:
    df = pd.read_csv(path, dtype=str, keep_default_na=False)
    df.replace(SENTINEL_VALUES, None, inplace=True)
    df["_batch_id"] = batch_id
    df["_loaded_at"] = datetime.utcnow()
    df["_filename"] = path.name
    return df


def create_table_and_load(conn, schema: str, table: str, df: pd.DataFrame) -> int:
    qualified = sql.Identifier(schema, table)

    # Build column definitions — metadata cols are typed, rest are TEXT
    col_defs = []
    for col in df.columns:
        if col == "_batch_id":
            col_defs.append(sql.SQL("{} INTEGER").format(sql.Identifier(col)))
        elif col == "_loaded_at":
            col_defs.append(sql.SQL("{} TIMESTAMP").format(sql.Identifier(col)))
        else:
            col_defs.append(sql.SQL("{} TEXT").format(sql.Identifier(col)))

    with conn.cursor() as cur:
        cur.execute(
            sql.SQL("DROP TABLE IF EXISTS {}").format(qualified)
        )
        cur.execute(
            sql.SQL("CREATE TABLE {} ({})").format(
                qualified, sql.SQL(", ").join(col_defs)
            )
        )

        if df.empty:
            conn.commit()
            return 0

        cols = sql.SQL(", ").join(sql.Identifier(c) for c in df.columns)
        placeholders = sql.SQL(", ").join(sql.Placeholder() * len(df.columns))
        insert_stmt = sql.SQL("INSERT INTO {} ({}) VALUES ({})").format(
            qualified, cols, placeholders
        )

        rows = [tuple(None if pd.isna(v) else v for v in row) for row in df.itertuples(index=False)]
        cur.executemany(insert_stmt, rows)

    conn.commit()
    return len(rows)


def main():
    conn = psycopg2.connect(**DB_CONFIG)

    with conn.cursor() as cur:
        cur.execute("CREATE SCHEMA IF NOT EXISTS raw")
    conn.commit()

    summary = []

    for batch in BATCHES:
        batch_num = int(batch.split("_")[1])
        batch_dir = DATA_ROOT / batch

        if not batch_dir.exists():
            print(f"[skip] {batch_dir} does not exist")
            continue

        csv_files = sorted(batch_dir.glob("*.csv"))
        if not csv_files:
            print(f"[skip] no CSV files in {batch_dir}")
            continue

        for csv_path in csv_files:
            table = to_table_name(batch, csv_path.name)
            df = load_csv(csv_path, batch_num)
            rows = create_table_and_load(conn, "raw", table, df)
            summary.append((f"raw.{table}", rows))

    conn.close()

    print("\n--- Load Summary ---")
    for table, rows in summary:
        print(f"  {table}: {rows} rows")
    print(f"\n{len(summary)} table(s) loaded.")


if __name__ == "__main__":
    main()
