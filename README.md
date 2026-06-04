# gemsweep

[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A521.04.0-23aa62.svg?labelColor=000000)](https://www.nextflow.io/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)

[[_TOC_]]

## Pipeline overview

**gemsweep** is a Nextflow DSL2 pipeline for deconvoluting mixed read sets (e.g. plate sweep sequencing data) and resolving them into strain-level bins. It implements [Themisto](https://github.com/algbio/themisto) pseudoalignment against a curated set of reference genomes, [mSWEEP](https://github.com/PROBIC/mSWEEP) for relative abundance estimation, and [mGEMS](https://github.com/PROBIC/mGEMS) for read binning.

The reference preparation and indexing steps are controlled by `--ref_mode`:

| `--ref_mode` | Description                                                                                                                               |
| ------------ | ----------------------------------------------------------------------------------------------------------------------------------------- |
| `index`      | Use a pre-built Themisto index and group assignments file directly.                                                                       |
| `full`       | Cluster all references with PopPUNK or Sketchlib and build the index (no de-replication).                                                 |
| `refine`     | Cluster references and de-replicate each cluster to a configurable number of maximally-distant representatives before building the index. |
| `autoselect` | Automatically select candidate references from reads using Sylph, then cluster and refine.                                                |

The core read processing steps (shared across all modes) are:

1. **Input** — reads are loaded from a local manifest CSV or other sources via the `mixed_input` sub-workflow.
2. **Pseudoalignment** — reads are pseudoaligned to the Themisto index.
3. **Abundance estimation** — mSWEEP estimates the relative abundance of each reference group per sample.
4. **Read binning** — mGEMS bins reads into per-group FASTQ files. Only groups with abundance above `--min_abundance` are binned.

## Usage

### Quickstart

#### From source code

1. Clone this repository (including submodules):

   ```bash
   git clone --recurse-submodules <repo-url>
   cd gemsweep
   ```

2. To run with `docker`, use the `-profile docker` option:

   ```bash
   nextflow run main.nf \
       -profile docker \
       --manifest manifest.csv \
       --ref_mode refine \
       --references references.txt \
       --outdir my_output
   ```

   Other profiles are also supported (`singularity`).  
   :warning: If no profile is specified the pipeline will run with the Sanger HPC-specific configuration.

3. Once the run has finished successfully and you have inspected the output, clean up intermediate files. The `work/` directory and `.nextflow.log` are useful for troubleshooting — do not delete them until you are satisfied the outputs are correct:

   ```bash
   rm -rf work .nextflow*
   ```

   Alternatively, use `nextflow clean` for more fine-grained control over which runs and intermediate files are removed.

#### Using on the Sanger farm

Load Nextflow and Singularity:

```bash
module load nextflow ISG/singularity
```

Submit to LSF:

```bash
bsub -o output.o -e error.e -q oversubscribed -R "select[mem>4000] rusage[mem=4000]" -M4000 \
    nextflow run main.nf \
        --manifest manifest.csv \
        --ref_mode refine \
        --references references.txt \
        --outdir my_output
```

### Input

#### Manifest (`--manifest`)

A CSV file with the required header `ID,R1,R2`, containing per-sample paths to paired `.fastq.gz` files:

```
ID,R1,R2
sampleA,/path/to/sampleA_1.fastq.gz,/path/to/sampleA_2.fastq.gz
```

#### Generating a manifest

**Sanger users:** the [manifest_generator](https://gitlab.internal.sanger.ac.uk/sanger-pathogens/pipelines/manifest_generator/) tool can generate a compatible `ID,R1,R2` manifest from a directory of FASTQ files or from iRODS.

#### Other input modes

This pipeline supports additional input modes via the `mixed_input` sub-workflow — these can be combined in a single run:

- **iRODS** (Sanger internal) — specify `--studyid`, `--runid`, `--laneid`, and/or `--plexid` on the command line; at least `--studyid` or `--runid` is required. A batch CSV of multiple iRODS searches can be supplied via `--manifest_of_lanes`. Requires an active iRODS session (`iinit`).
- **ENA download** — supply a file of ENA accession IDs via `--manifest_ena`. Set `--accession_type` to `run` (default), `sample`, or `study`.
- **Directory scan** — provide a path to a directory of FASTQ files via `--manifest_from_dir`. Use `--fastq_validation` (`strict`/`relaxed`, default: `strict`) and `--max_depth` (default: `0`) to control discovery.

Run `--help` for the full parameter list.

#### References (`--references`)

A text file listing paths to reference FASTA files (one per line). Required when `--ref_mode` is `full` or `refine`.

```
/path/to/reference1.fasta
/path/to/reference2.fasta
```

#### Pre-built index (`--ref_mode index`)

If you already have a Themisto index and group assignments, skip clustering and index building:

- `--themisto_index` — path to the pre-built Themisto index prefix (without file extensions).
- `--ref_groups` — grouped references text file, one line per reference (mandatory when `--themisto_index` is supplied).

#### Autoselect mode (`--ref_mode autoselect`)

When using `autoselect`, no `--references` input is required. Sylph sketches the reads and queries a pre-built Sylph database (default: GTDB r226) to identify candidate reference species. These candidates are then clustered and refined automatically. A caching mechanism (`--cache_dir`) avoids recomputing per-species reference sets across runs.

### Output

Results are written to `--outdir` (default: `./results`):

```
results/
  <sample_ID>/
    <sample_ID>_mSWEEP_abundances.txt   # mSWEEP relative abundance estimates
    <sample_ID>_mSWEEP_probs.tsv        # mSWEEP assignment probabilities
    mGEMS/
      <sample_ID>_<group>.R1.fastq.gz   # Binned reads per reference group
      <sample_ID>_<group>.R2.fastq.gz
  ref_groups/
    references.txt                      # Reference sequences used for index building
    groups.txt                          # Reference-to-group assignments
  themisto/
    <index_prefix>.*                    # Themisto index files
    index_report.txt                    # Themisto index statistics
  <cluster_tool>/                       # e.g. poppunk/ or sketchlib/
    <reference_ID>/
      groups.txt                        # Per-reference group assignments
  poppunk/
    <reference_ID>/
      pp_database/                      # PopPUNK database (if --publish_poppunk true)
  sylph/
    <sample_ID>_sylph_filtered_report.tsv    # Sylph filtered profile (autoselect mode)
    taxon_refs/                              # Reference lists per taxon (autoselect mode)
    taxon_group_ref_reports/                 # Combined reference reports (autoselect mode)
    taxon_refs/*                             # Expanded reference FASTAs (autoselect mode)
```

### Parameters

**General options**

| Option            | Type      | Default     | Description                                                                        |
| ----------------- | --------- | ----------- | ---------------------------------------------------------------------------------- |
| `--manifest`      | `path`    | `null`      | Input manifest CSV with header `ID,R1,R2` (mandatory).                             |
| `--outdir`        | `path`    | `./results` | Directory where results are written.                                               |
| `--ref_mode`      | `string`  | `null`      | Reference processing mode: `index`, `full`, `refine`, or `autoselect` (mandatory). |
| `--ref_prep_only` | `boolean` | `false`     | Run only the reference preparation steps, skipping pseudoalignment and binning.    |

---

**Reference options**

| Option              | Type      | Default   | Description                                                                                      |
| ------------------- | --------- | --------- | ------------------------------------------------------------------------------------------------ |
| `--references`      | `path`    | `null`    | Text file with paths to reference FASTAs (one per line). Required for `full` and `refine` modes. |
| `--representatives` | `integer` | `20`      | Maximum representatives per cluster when `--ref_mode` is `refine` or `autoselect`.               |
| `--cluster_tool`    | `string`  | `poppunk` | Clustering tool for `full` and `refine` modes. Options: `poppunk`, `sketchlib`.                  |

---

**Cache (autoselect mode)**

| Option        | Type   | Default | Description                                                                                                                         |
| ------------- | ------ | ------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| `--cache_dir` | `path` | `null`  | Path to a cache directory for autoselect mode. Reuses previously computed per-species reference sets to avoid redundant clustering. |

---

**PopPUNK options**

| Option              | Type      | Default  | Description                                                          |
| ------------------- | --------- | -------- | -------------------------------------------------------------------- |
| `--poppunk_model`   | `string`  | `dbscan` | Clustering model. Options: `dbscan`, `bgmm`.                         |
| `--publish_poppunk` | `boolean` | `false`  | Publish full PopPUNK output. Group assignments are always published. |

---

**Sketchlib options**

| Option                | Type      | Default                | Description                                                                                                                       |
| --------------------- | --------- | ---------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| `--sketchlib_kstep`   | `string`  | `13,29,4`              | K-mer sizes for sketching in the format `start,stop,step`.                                                                        |
| `--cluster_algorithm` | `string`  | `connected_components` | Community-finding algorithm for distance-based clustering. Options: `connected_components`, `leiden`, `louvain`, `walktrap`, etc. |
| `--ani_threshold`     | `float`   | `0.02`                 | Maximum ANI distance for clustering (0.02 clusters genomes sharing >98% ANI similarity).                                          |
| `--cluster_strict`    | `boolean` | `false`                | Fail early if all genomes form a single cluster or are all singletons.                                                            |

---

**Themisto options**

| Option             | Type      | Default | Description                                                                                                                                   |
| ------------------ | --------- | ------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| `--themisto_index` | `path`    | `null`  | Pre-built Themisto index prefix (without extensions). Used with `--ref_mode index`. Requires `--ref_groups`.                                  |
| `--themisto_k`     | `integer` | `31`    | K-mer size for index building and pseudoalignment. Options: `21`, `31`, `51`. Must match a pre-built index if `--themisto_index` is provided. |
| `--temp_dir`       | `path`    | `null`  | Custom temporary storage directory for index creation. Defaults to `/tmp`.                                                                    |
| `--temp_space`     | `integer` | `10000` | Temporary storage (MB) to reserve during index creation and pseudoalignment.                                                                  |

---

**mSWEEP options**

| Option         | Type   | Default | Description                                                                              |
| -------------- | ------ | ------- | ---------------------------------------------------------------------------------------- |
| `--ref_groups` | `path` | `null`  | Grouped references text file (one line per reference). Required with `--ref_mode index`. |

---

**mGEMS options**

| Option              | Type      | Default  | Description                                                                    |
| ------------------- | --------- | -------- | ------------------------------------------------------------------------------ |
| `--get_assignments` | `boolean` | `false`  | Output the read assignment table used by mGEMS for binning.                    |
| `--min_abundance`   | `float`   | `0.0001` | Minimum relative abundance. Only groups exceeding this will have reads binned. |

---

**Sylph reference selection options (autoselect mode)**

| Option                | Type      | Default                                                                  | Description                                                                                                               |
| --------------------- | --------- | ------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------- |
| `--sylph_db`          | `path`    | `/data/pam/software/sylph/gtdb-r226-c200-dbv1/gtdb-r226-c200-dbv1.syldb` | Pre-built Sylph database.                                                                                                 |
| `--sylph_k`           | `integer` | `31`                                                                     | Sketch k-mer size for Sylph. Options: `21`, `31`.                                                                         |
| `--sylph_min_ani`     | `float`   | `95`                                                                     | Minimum ANI threshold for Sylph candidate selection.                                                                      |
| `--sylph_min_cov`     | `float`   | `0.01`                                                                   | Minimum coverage threshold for Sylph candidate selection.                                                                 |
| `--taxonomic_rank`    | `string`  | `species`                                                                | Taxonomic rank by which to group references. Options: `domain`, `phylum`, `class`, `order`, `family`, `genus`, `species`. |
| `--genome_id_to_file` | `path`    | See schema                                                               | TSV file mapping GTDB genome IDs to local FASTA paths.                                                                    |

---

**General**

| Option              | Type      | Default | Description                 |
| ------------------- | --------- | ------- | --------------------------- |
| `--monochrome_logs` | `boolean` | `false` | Output logs in plain ASCII. |

### Advanced usage

#### Using a pre-built index (`ref_mode index`)

Skip clustering and index building entirely by supplying a pre-built Themisto index and group assignments:

```bash
nextflow run main.nf \
    --manifest manifest.csv \
    --ref_mode index \
    --themisto_index /path/to/index_prefix \
    --ref_groups /path/to/groups.txt \
    --outdir my_output
```

#### Autoselect with caching

In `autoselect` mode, Sylph queries the GTDB database to identify species present in each sample, then automatically selects and clusters reference genomes. Supply `--cache_dir` to reuse previously computed per-species reference sets across runs:

```bash
nextflow run main.nf \
    --manifest manifest.csv \
    --ref_mode autoselect \
    --cache_dir /path/to/cache \
    --outdir my_output
```

#### Reference preparation only

Use `--ref_prep_only true` to build a Themisto index without running pseudoalignment or binning. The resulting index can then be reused across multiple runs with `--ref_mode index`.

#### Temporary storage for large datasets

Themisto index creation can require substantial temporary disk space. On the Sanger HPC, LSF scratch space is allocated automatically. Locally, set `--temp_dir` to a path with sufficient capacity and adjust `--temp_space` accordingly.

### Dependencies

All dependencies are containerised in publicly available Docker/Singularity images.

For `autoselect` mode, the following databases must be available (Sanger HPC defaults are pre-configured):

- **Sylph database** (`--sylph_db`): a pre-built Sylph `.syldb` file (default: GTDB r226).
- **Genome ID-to-file map** (`--genome_id_to_file`): TSV mapping GTDB genome identifiers to local FASTA paths.

## Software versions

| Software  | Version | Image                                                  |
| --------- | ------- | ------------------------------------------------------ |
| Themisto  | 3.2.2   | `quay.io/sangerpathogens/themisto:3.2.2`               |
| mSWEEP    | 2.2.1   | `quay.io/biocontainers/msweep:2.2.1--h503566f_1`       |
| mGEMS     | 1.3.3   | `quay.io/biocontainers/mgems:1.3.3--h13024bc_2`        |
| PopPUNK   | 2.7.8   | `quay.io/biocontainers/poppunk:2.7.8--py310h4d0eb5b_0` |
| Sylph     | 0.8.1   | `quay.io/biocontainers/sylph:0.8.1--ha6fb395_0`        |
| Sketchlib | 2.1.5   | `quay.io/sangerpathogens/pp-sketchlib-python:2.1.5-c1` |

See `modules/` for pinned container versions.

## Troubleshooting

- **`--ref_mode` not set**: `--ref_mode` is required and must be one of `index`, `full`, `refine`, or `autoselect`. Run `--help` for details.
- **Insufficient temporary disk space**: Themisto index creation requires substantial `/tmp` space. Set `--temp_dir` to a path with more capacity, or increase `--temp_space`.
- **mSWEEP finds no groups**: when using `--ref_mode index`, ensure `--ref_groups` matches the reference set used to build `--themisto_index`. Group labels must correspond one-to-one with references in the index.
- **Autoselect finds no candidates**: check that `--sylph_db` points to the correct Sylph database and that `--sylph_min_ani` / `--sylph_min_cov` thresholds are not too stringent.
- **Resuming a failed run**: add `-resume` to your command to restart from cached intermediate results.
- For further help, check `.nextflow.log` and the per-process `.command.log` logs in the `work/` directory.

Sanger users may find [this page](https://ssg-confluence.internal.sanger.ac.uk/spaces/PaMI/pages/181078206/General+pipeline+info#Generalpipelineinfo-Troubleshootingafailedpipelinerunandsendingabugreport) useful for troubleshooting Nextflow pipeline runs.

## Issues and Contributions

**GitHub users:** if you find an issue with this pipeline, or would like to suggest an improvement, please log an issue or open a pull request on this repository.

**Sanger users:** if you need internal support, you can raise an issue on the PAM Freshservice portal: https://sanger.freshservice.com/support/catalog/items/426
