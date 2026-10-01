# Script index and implementation notes

The UKHLS and related analysis scripts are in `ukhls/`; the separate IAPT preparation and analysis scripts are in `iapt/`. Names and dependencies come from the scripts; outputs and required packages should be checked again when each script is run. Original filenames are preserved.

| Stage | Script | Main input or role |
| --- | --- | --- |
| UKHLS preparation | `ukhls/U1.1_indresp_ghq_lfs.do` | Original waves 1–14 preparation; produces `ind_ghq_lfs.dta` and event-related files. |
| UKHLS preparation with household ID | `ukhls/U1.1_indresp_ghq_lfs_keep_hidp.do` | Alternative differing only by keeping `hidp` in `ind_event.dta`; `ind_ghq_lfs.dta` construction is the same in both versions. |
| Descriptions | `ukhls/U1.2_ghq_descriptive.do` | Reads `ind_ghq_lfs`; GHQ distributions and descriptive figures. |
| Event descriptions | `ukhls/U1.3_lifeevent_descriptive.do` | Reads `ghqevent_nodrop`; event coding and descriptions. |
| Initial IV exploration | `ukhls/U1.4_lifeevent_IV.do`, `ukhls/U1.5_lifeevent_IV_test.do` | Read `ghqevent`; preliminary specifications and tests. |
| Life-event selection | `ukhls/U1.6_lifeevent_IVchoice_deathascore.do`, `ukhls/U1.7_master_IV_selection_tests.do` | Read `ghqevent`; first stages, candidate instruments, weak-IV diagnostics and related analyses. |
| Missing GHQ | `ukhls/U1.7_dealingwith_missingGHQ.do` | Reads `ind_ghq_lfs`; missingness investigation. |
| Heterogeneity | `ukhls/U1.8_supervisor_heterogeneity_transitions.do` | Reads `ghqevent`; initial GHQ, employment transition and submarket analyses. Its header requires five variable-name macros to be set before running. |
| Wage changes | `ukhls/wage_change_iv_general_fixed.do`, `ukhls/wage_change_iv_general_fixed_with_OLS.do` | Alternative wage-change analyses using `ghqevent`; the second includes an OLS comparison. |
| Therapy exploration | `ukhls/therapy_waitingtime_IV.do` | Reads `ind_ghq_lfs.dta`, `hidp_geo.dta` and `IAPT_LSOA_month_exposure_clean.dta`; constructs LAD-month exposure and an IV analysis. |
| Claimant-count check | `ukhls/IAPT_claimant_count_preliminary(1).do` | Reads a Nomis claimant-count CSV, geography lookup and IAPT exposure data; preliminary LAD-month association and residualisation. Claimant count is not a claimant rate. |
| Stress movement | `ukhls/U1.9_stress_transition_equalweights.do` | Reads `ghqevent.dta`, O*NET stress scores and a crosswalk; the SOC2000 bridge is an empirical proxy. |
| Stress, wages and outflows | `ukhls/U1_10_stress_complete.do` | Reads `ind_ghq_lfs.dta`, O*NET scores and crosswalk; describes transitions and wages. |

## Practical run sequence

1. Configure the source and output paths in **one** U1.1 preparation file. Its source folder must contain the wave-specific UKHLS individual response files. Check its additional local inputs such as `cpi` and `hh_pidp` before execution.
2. Inspect the resulting `ind_ghq_lfs.dta` and event files, including whether `ghqevent.dta` has been produced by your existing workflow. A fresh checkout does not include any of these datasets.
3. Run the descriptive or life-event analyses you need. For the master IV script, check the availability of `ivreg2`, `ranktest`, `weakiv` and `weakivtest` in Stata. Some exploratory scripts also use `outreg2` or `esttab`.
4. For therapy or stress analyses, supply the separate geography, IAPT or O*NET sources identified in the chosen script. Check linkage coverage, time alignment and the meaning of the occupation crosswalk before interpreting coefficients.

## Review priorities

- The preparation file contains `merge n:n year using cpi` in two places. Review the intended year-level CPI merge and key uniqueness before relying on derived files; no change has yet been made to this code.
- Paths are fixed to a particular Windows installation in several files. A shared configuration and separate raw/derived/output folders would make runs more reliable.
- Similar scripts represent alternatives or successive revisions. Decide which specification is authoritative before consolidating them; preserve old results and filenames until the comparison is complete.
- The therapy waiting-time script aggregates equally over LSOAs within LAD-month. Examine the geography and timing assumptions, and assess possible direct effects of access and local labour-market conditions before treating waiting time as a valid instrument.
- No end-to-end reproduction has yet been performed. Record Stata version, package versions, source-data release, row counts and saved output names as each stage is verified.
