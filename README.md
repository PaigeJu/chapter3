# Chapter 3: mental health and labour-market transitions

Stata scripts for UKHLS data preparation, GHQ-12 descriptions, life-event instrumental-variable analyses, therapy waiting-time exploration, and occupational stress-tolerance analyses. The repository currently contains code only. UKHLS microdata, geographical files, IAPT data, O*NET inputs and generated results must be obtained and stored separately.

## Start here

1. Read [the script index](docs/script-index.md) to choose an analysis and identify its inputs.
2. Obtain the relevant source data through the original providers and place them on your own computer. Do not commit restricted microdata or household geography to this public repository.
3. Open the chosen `.do` file in Stata and set its path globals or working directory to your local files. Several scripts still contain the author's Windows paths and are not yet portable.
4. Check that each required input and any user-written Stata commands are present. Run the whole file in the order described in the index, then inspect its log, sample counts and merge diagnostics.

The preparation scripts use UKHLS waves 1–14. The only code difference between the two `U1.1` files is that `U1.1_indresp_ghq_lfs_keep_hidp.do` also keeps `hidp` in `ind_event.dta`. The `ind_ghq_lfs.dta` preparation is identical in both versions. Do not run both into the same output directory without checking which derived files you want to retain.

**Status:** This is an inventory of existing code, not a claim that the analyses reproduce from a fresh checkout. No Stata executable or research datasets were available for an end-to-end run in the review environment. Interpretation of IV estimates requires separate assessment of instrument relevance and the exclusion restriction.

## Working convention

Keep source data and generated outputs outside Git. Commit focused revisions to scripts and documentation with a note on inputs, the change and how it was checked. The current filenames are preserved so existing local workflows continue to find them.
