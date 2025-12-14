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

<!--- Add once a module:
### On the Sanger HPC

To run the pipeline on the Sanger HPC as a module replace `nextflow run main.nf` with the name of the tool. For instance, to see a help message:

```
module load qc_mags
qc_mags --help
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

### Input manifest

This pipeline requires a manifest of reads i.e. a CSV file with the header line 'ID,R1,R2' (mandatory) and rows containing the read ID, path to read 1 and path to read 2. Only paired-end reads are supported and the files should be gzipped fastqs (file extension '.fastq.gz').

### Inputs

- Paired-end reads per (mixed) sample

### Outputs

TBC

### Parameters

<!--- WIP:
    // themisto options
    temp_storage = "/tmp"
    themisto_index = null
    kmer_size = 31

    // msweep options
    ref_groups = null

    // mgems options
    get_assignments = false

    // skip options
    skip_clustering = false
--->

TBC

### Dependencies

All dependencies are containerised in publicly available docker images.

<!--- Mention Nextflow version dependency --->
<!--- Add note here if/when database dependencies become necessary. --->

## Software versions

The current version of the pipeline uses the following software dependencies:

| Software | Version | Image URL                                      |
| -------- | ------- | ---------------------------------------------- |
| themisto | 3.2.2   | quay.io/sangerpathogens/themisto:3.2.2         |
| mSWEEP   | 2.2.1   | quay.io/biocontainers/msweep:2.2.1--h503566f_1 |
| mGEMS    | 1.3.3   | quay.io/biocontainers/mgems:1.3.3--h13024bc_2  |

<!---
| XXX       | X.X.X   | quay.io/...                                           |
| XXX       | X.X.X   | quay.io/...                                           |
--->

<!--- Uncomment in next version:
To see the dependencies for a previous version go to the tag corresponding to that version and navigate to this section of the README.
--->

## Temporary Storage Usage

TBC

## GPU Acceleration

TBC
