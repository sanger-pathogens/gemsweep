#!/usr/bin/env python3

import argparse
from pathlib import Path
import pandas as pd


def load_report(path):
    df = pd.read_csv(path, sep="\t")
    df["__report_path"] = str(path)
    df["__sample_id"] = Path(path).name.replace("_sylph_profile.tsv", "")
    return df


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--reports", nargs="+", required=True)
    p.add_argument("--primary-ani", type=float, required=True)
    p.add_argument("--primary-cov", type=float, required=True)
    p.add_argument("--secondary-ani", type=float, required=True)
    p.add_argument("--secondary-cov", type=float, required=True)
    p.add_argument("--ani-column", default="Adjusted_ANI")
    p.add_argument("--cov-column", default="Eff_cov")
    p.add_argument("--out-primary", default="primary_references.txt")
    p.add_argument("--out-secondary", default="secondary_references.txt")
    p.add_argument("--out-summary", default="sylph_summary.tsv")
    args = p.parse_args()

    frames = [load_report(p) for p in args.reports]
    if not frames:
        raise SystemExit("No Sylph reports provided.")

    df = pd.concat(frames, ignore_index=True)

    ani_col = args.ani_column
    cov_col = args.cov_column

    # TODO: consider abundance thresholds once defined (e.g. Taxonomic_abundance or Sequence_abundance)

    primary_mask = (df[ani_col] >= args.primary_ani) & (df[cov_col] >= args.primary_cov)
    secondary_mask = (df[ani_col] >= args.secondary_ani) & (df[cov_col] >= args.secondary_cov)

    primary_hits = df.loc[primary_mask].copy()
    secondary_hits = df.loc[secondary_mask].copy()

    primary_refs = sorted(primary_hits["Genome_file"].dropna().unique())
    secondary_refs = sorted(
        set(primary_hits["Genome_file"].dropna().unique())
        | set(secondary_hits["Genome_file"].dropna().unique())
    )

    Path(args.out_primary).write_text("\n".join(primary_refs) + ("\n" if primary_refs else ""))
    Path(args.out_secondary).write_text("\n".join(secondary_refs) + ("\n" if secondary_refs else ""))

    summaries = []
    for genome_file, gdf in df.groupby("Genome_file", sort=True):
        gdf_primary = gdf[(gdf[ani_col] >= args.primary_ani) & (gdf[cov_col] >= args.primary_cov)]
        gdf_secondary = gdf[(gdf[ani_col] >= args.secondary_ani) & (gdf[cov_col] >= args.secondary_cov)]

        primary_pass = int(not gdf_primary.empty)
        secondary_pass = int((primary_pass == 0) and (not gdf_secondary.empty))
        failed_thresholds = int(primary_pass == 0 and secondary_pass == 0)

        summaries.append(
            {
                "reference_genome": genome_file,
                "primary_pass": primary_pass,
                "secondary_pass": secondary_pass,
                "failed_thresholds": failed_thresholds,
            }
        )

    summary_df = pd.DataFrame(summaries)

    totals = {
        "reference_genome": "TOTAL",
        "primary_pass": int(summary_df["primary_pass"].sum()),
        "secondary_pass": int(summary_df["secondary_pass"].sum()),
        "failed_thresholds": int(summary_df["failed_thresholds"].sum()),
    }

    summary_df = pd.concat([summary_df, pd.DataFrame([totals])], ignore_index=True)
    summary_df.to_csv(args.out_summary, sep="\t", index=False)


if __name__ == "__main__":
    main()
