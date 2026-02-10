# mSWEEP-mGEMS (WIP name)

[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A521.04.0-23aa62.svg?labelColor=000000)](https://www.nextflow.io/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)

[[_TOC_]]

## Pipeline summary

This workflow deconvolutes mixed read sets (e.g. plate sweep sequencing data) and resolves these into strain-level resolution bins. It implements Themisto pseudoalignment of reads to a curated set of references, mSWEEP to estimate relative abundances and mGEMS to bin reads.

<!--- Insert Workflow Diagram Here --->

## Usage

### Quickstart

<!--- Add once a module with known name:
### On the Sanger HPC

To run the pipeline on the Sanger HPC as a module replace `nextflow run main.nf` with the name of the tool. For instance, to see a help message:

```
module load gemsweep
gemsweep --help
```

### From source
--->

To run the pipeline from source (this repository):

1.  Clone the repository.
2.  To run with `docker`, use the path to the `-profile docker` option:

    ```
    nextflow run <path/to/main.nf> \
        -profile docker \
        --manifest <path/to/manifest.csv>
    ```

    Other profiles are also supported (`docker`, `singularity`).  
    :warning: If no profile is specified the pipeline will run with a Sanger HPC-specific configuration.

    This pipeline's default settings are optimised for running on the Sanger HPC, including making use of GPU and temp storage. To run on other systems please configure the parameters appropriately.

    See [Usage](#usage) for all available pipeline options.

### Inputs

- Either of the following options for supplying references:

  - a prebuilt themisto index of references AND a reference grouping text file\*
  - a references.txt (indexing and clustering will happen within the pipeline)

  If a references.txt is supplied, any files supplied to `--ref_groups` and/or `--themisto_index` are ignored.

  NOTE: If supplying a prebuilt index a\) the kmer size must be identical to the argument `kmer_size` (default: 31) and b\) the reference grouping file must be in identical positional order to the references when indexed.

- Paired-end reads per (mixed) sample
  To provide locally stored reads either use --manifest (or alias --manifest_of_reads) to supply a CSV file with the header line 'ID,R1,R2' (mandatory) and rows containing the read ID, path to read 1 and path to read 2, or use --manifest_from_dir to supply a directory containing the reads (can be used alongside --max_depth with an integer reflecting how many sub-directories deep to look for reads).

  Note: Only paired-end reads are supported and the files should be gzipped fastqs (file extension '.fastq.gz').

  Alternatively you can supply reads from ENA or, if you have access, Sanger's iRODS. See here for more detail: https://gitlab.internal.sanger.ac.uk/sanger-pathogens/pipelines/assorted-sub-workflows/-/blob/main/mixed_input/README.md?ref_type=heads

<!---
Example reference grouping file would be useful to add.
--->

### Outputs

- Binned reads per reference group (strain-level deconvolution)
- Read assignment table (optionally, with `--get_assignments`)

<!---
Add example tree of results output
--->

### Parameters

**Logging options**

| Flag              | Type      | Default | Description                                           |
| ----------------- | --------- | ------- | ----------------------------------------------------- |
| `monochrome_logs` | `boolean` | `false` | Output logs in plain ASCII (disable colored logging). |

---

**General options**

| Flag         | Type   | Default       | Description                                                                                                                 |
| ------------ | ------ | ------------- | --------------------------------------------------------------------------------------------------------------------------- |
| `manifest`   | `path` | `null`        | Input manifest CSV with required header `ID,R1,R2`, containing per-sample paths to `.fastq.gz` files.                       |
| `references` | `path` | `null`        | Path to text file containing paths to references, one per line. If provided, ref_groups and themisto_index will be ignored. |
| `outdir`     | `path` | `"./results"` | Path to top directory containing all results, by default `results` within the launch directory.                             |

---

**Clustering options**

| Flag              | Type     | Default  | Description                                                                     |
| ----------------- | -------- | -------- | ------------------------------------------------------------------------------- |
| `poppunk_model`   | `string` | `dbscan` | Clustering model for poppunk to use (either dbscan or bgmm)                     |
| `publish_poppunk` | `bool`   | `false`  | Optionally publish full poppunk output, group assignments are always published. |

---

**Themisto options**

| Flag             | Type      | Default | Description                                                                                                                    |
| ---------------- | --------- | ------- | ------------------------------------------------------------------------------------------------------------------------------ |
| `temp_dir`       | `path`    | `null`  | Custom temporary storage directory to be used during runtime. Otherwise local `/tmp` will be used..                            |
| `themisto_index` | `path`    | `null`  | Path to a pre-built Themisto index including the index prefix (without exts). Skips indexing if provided.                      |
| `kmer_size`      | `integer` | `31`    | K-mer size for indexing and pseudoalignment. Allowed values: `21`, `31`, `51`. K-mer sizes must match if an index is provided. |

---

**mSWEEP options**

| Flag         | Type   | Default | Description                                                                                                             |
| ------------ | ------ | ------- | ----------------------------------------------------------------------------------------------------------------------- |
| `ref_groups` | `path` | `null`  | Grouped references text file, one line per reference. Mandatory when pre-built index is supplied to `--themisto_index`. |

---

**mGEMS options**

| Flag              | Type      | Default  | Description                                                                      |
| ----------------- | --------- | -------- | -------------------------------------------------------------------------------- |
| `get_assignments` | `boolean` | `false`  | Output the read assignment table used by mGEMS for binning.                      |
| `min_abundance`   | `float`   | `0.0001` | Only bin reads for groups that have a relative abundance higher than this value. |

---

### Dependencies

All dependencies are containerised in publicly available docker images.

<!--- Mention Nextflow version dependency --->
<!--- Add note here if/when database dependencies become necessary. --->

## Software versions

The current version of the pipeline uses the following software dependencies:

| Software | Version | Image URL                                            |
| -------- | ------- | ---------------------------------------------------- |
| themisto | 3.2.2   | quay.io/sangerpathogens/themisto:3.2.2               |
| mSWEEP   | 2.2.1   | quay.io/biocontainers/msweep:2.2.1--h503566f_1       |
| mGEMS    | 1.3.3   | quay.io/biocontainers/mgems:1.3.3--h13024bc_2        |
| PopPUNK  | 2.7.8   | quay.io/biocontainers/poppunk:2.7.8--py310h4d0eb5b_0 |

<!---
| XXX       | X.X.X   | quay.io/...                                           |
| XXX       | X.X.X   | quay.io/...                                           |
--->

<!--- Uncomment in next version:
To see the dependencies for a previous version go to the tag corresponding to that version and navigate to this section of the README.
--->

## Customise Temporary Storage

The `--temp_dir` option is available to customise temporary storage location if necessary. Themisto pseudoalignment requires temporary storage and requires that it is on the same filesystem as the process is run. By default this pipeline uses node-local `/tmp` which is safe for both HPC and non-HPC as long as `/tmp` is available and writable (usually true).

## GPU Acceleration

TBC
