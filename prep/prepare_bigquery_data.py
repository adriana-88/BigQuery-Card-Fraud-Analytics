"""
Prepare the Kaggle 'Financial Transactions Dataset: Analytics' for BigQuery Sandbox.

What it does
------------
1. Parses train_fraud_labels.json  ->  fraud_labels.csv (transaction_id, is_fraud)
2. Samples transactions_data.csv (1.26 GB, ~13M rows) down to ~TARGET_ROWS rows:
     - keeps ALL fraud transactions
     - random-samples legitimate/unlabeled ones (uniform across time, seeded)
   ->  transactions_sample.csv  (should land well under BigQuery's 100 MB
       console-upload limit)
3. Converts mcc_codes.json -> mcc_codes.csv (mcc_code, description)
4. Writes fraud_labels_sample.csv containing labels ONLY for sampled transactions
   (keeps the labels file small and consistent with the sample)

NOTE: amounts are left as raw strings (e.g. "$-77.00") on purpose.
Cleaning happens in BigQuery SQL (staging -> clean layer) as part of the project.

Usage
-----
Put this script in the same folder as the downloaded files, adjust the
CONFIG paths if needed, then:  python prepare_bigquery_data.py
"""

import json
import csv
import os
import random

import pandas as pd

# ----------------------------- CONFIG ---------------------------------------
INPUT_DIR = "."                      # folder with the Kaggle files
OUTPUT_DIR = "./bigquery_upload"     # where prepared files go

TRANSACTIONS_CSV = os.path.join(INPUT_DIR, "transactions_data.csv")
LABELS_JSON      = os.path.join(INPUT_DIR, "train_fraud_labels.json")
MCC_JSON         = os.path.join(INPUT_DIR, "mcc_codes.json")

TARGET_ROWS = 300_000        # total sampled transactions (incl. all fraud)
CHUNK_SIZE  = 500_000        # rows per chunk when streaming the big CSV
SEED        = 42
# -----------------------------------------------------------------------------

os.makedirs(OUTPUT_DIR, exist_ok=True)
rng = random.Random(SEED)


def load_fraud_labels(path: str) -> dict:
    """Load {'target': {tx_id: 'Yes'/'No'}} into a plain dict[str, str]."""
    print(f"[1/4] Loading fraud labels from {path} ...")
    with open(path, "r") as f:
        data = json.load(f)
    labels = data["target"] if "target" in data else data
    n_fraud = sum(1 for v in labels.values() if v == "Yes")
    print(f"      {len(labels):,} labels loaded | fraud = {n_fraud:,} "
          f"({n_fraud / len(labels):.4%})")
    return labels


def estimate_sampling_fraction(labels: dict) -> float:
    """Fraction needed for non-fraud rows to hit TARGET_ROWS overall.

    We sample from the FULL transactions file (labeled legit + unlabeled),
    so estimate the pool as: total_file_rows - fraud_rows. We don't know
    total_file_rows without a pass, so we count quickly (cheap: one column).
    """
    print("[2/4] Counting rows in transactions file (quick pass) ...")
    total = 0
    for chunk in pd.read_csv(TRANSACTIONS_CSV, usecols=[0],
                             chunksize=CHUNK_SIZE):
        total += len(chunk)
    n_fraud = sum(1 for v in labels.values() if v == "Yes")
    pool = total - n_fraud
    frac = max(0.0, (TARGET_ROWS - n_fraud) / pool)
    print(f"      total rows = {total:,} | fraud = {n_fraud:,} "
          f"| sampling fraction for the rest = {frac:.5f}")
    return frac


def sample_transactions(labels: dict, frac: float) -> None:
    print("[3/4] Sampling transactions (keeping ALL fraud) ...")
    out_tx_path = os.path.join(OUTPUT_DIR, "transactions_sample.csv")
    out_lbl_path = os.path.join(OUTPUT_DIR, "fraud_labels_sample.csv")

    kept_fraud = kept_other = 0
    first_chunk = True

    with open(out_lbl_path, "w", newline="") as lbl_f:
        lbl_writer = csv.writer(lbl_f)
        lbl_writer.writerow(["transaction_id", "is_fraud"])

        reader = pd.read_csv(TRANSACTIONS_CSV, dtype=str,
                             chunksize=CHUNK_SIZE)
        for i, chunk in enumerate(reader, start=1):
            ids = chunk["id"].astype(str)
            lab = ids.map(labels)                     # 'Yes' / 'No' / NaN
            is_fraud_mask = lab.eq("Yes")

            keep_mask = is_fraud_mask.copy()
            # sample the non-fraud rows
            rand = pd.Series([rng.random() for _ in range(len(chunk))],
                             index=chunk.index)
            keep_mask |= (~is_fraud_mask) & (rand < frac)

            kept = chunk[keep_mask]
            kept_fraud += int(is_fraud_mask.sum())
            kept_other += int(keep_mask.sum()) - int(is_fraud_mask.sum())

            kept.to_csv(out_tx_path, mode="w" if first_chunk else "a",
                        header=first_chunk, index=False)

            # labels for the kept rows (only where a label exists)
            kept_lab = lab[keep_mask].dropna()
            for tx_id, val in zip(ids[keep_mask][kept_lab.index], kept_lab):
                lbl_writer.writerow([tx_id, val])

            first_chunk = False
            print(f"      chunk {i}: kept so far -> fraud {kept_fraud:,} "
                  f"| other {kept_other:,}", end="\r")

    size_mb = os.path.getsize(out_tx_path) / 1e6
    print(f"\n      DONE. transactions_sample.csv: "
          f"{kept_fraud + kept_other:,} rows, {size_mb:.1f} MB")
    if size_mb > 95:
        print("      WARNING: file near/over the 100 MB console upload "
              "limit — lower TARGET_ROWS and rerun.")


def convert_mcc(path: str) -> None:
    print("[4/4] Converting MCC codes to CSV ...")
    with open(path, "r") as f:
        mcc = json.load(f)
    out = os.path.join(OUTPUT_DIR, "mcc_codes.csv")
    with open(out, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["mcc_code", "description"])
        for code, desc in sorted(mcc.items()):
            w.writerow([code, desc])
    print(f"      {len(mcc)} MCC codes -> {out}")


if __name__ == "__main__":
    labels = load_fraud_labels(LABELS_JSON)
    frac = estimate_sampling_fraction(labels)
    sample_transactions(labels, frac)
    convert_mcc(MCC_JSON)
    print("\nAll set. Upload to BigQuery from:", os.path.abspath(OUTPUT_DIR))
    print("Also upload users_data.csv and cards_data.csv as-is (they're small).")
