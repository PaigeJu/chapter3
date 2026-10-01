clear all
set more off
set linesize 255

/*****************************************************************************
 PRELIMINARY TEST: IAPT WAITING TIME AND MONTHLY CLAIMANT COUNT

 Purpose
   1. Convert the Nomis April-2019-LAD claimant-count CSV from wide to long.
   2. Add LAD19 ONS codes using the 2019 LSOA-CCG-LAD lookup.
   3. Re-map every IAPT LSOA to a fixed April 2019 LAD geography.
   4. Create a LAD19-month IAPT panel.
   5. Test whether monthly claimant count predicts IAPT access/waiting measures.
   6. Save waiting-time residuals net of claimant count and two-way fixed effects.

 Important interpretation
   Claimant count is not a claimant/unemployment rate. LAD fixed effects absorb
   time-invariant differences in LAD population size, but they do not absorb
   changes in population over time. Treat these estimates as preliminary.
*****************************************************************************/


/*****************************************************************************
 1. PATHS
*****************************************************************************/

* Existing IAPT LSOA-month exposure file.
global iaptfile ///
 "C:/Users/hm21806/Desktop/chapter3/code_iapt/lsoa_output/IAPT_CCG_month_LSOA11_exposure_only.dta"

* April 2019 LSOA-CCG-LAD lookup already used in the earlier work.
global lookup19 ///
 "C:/Users/hm21806/Desktop/chapter3/code_iapt/LSOA11_CCG19_LAD19_EN_LU_b15d0240099643b6a303f24ccc04da06_6577294720128586166.csv"

* Newly downloaded Nomis claimant-count file.
global nomiscsv ///
 "C:/Users/hm21806/Desktop/chapter3/IAPT/labour_market/nomis_claimant_rate_lad19_2015m7_2022m6.csv"

* Existing output directory. Do not change the earlier project paths.
global outdir ///
 "C:/Users/hm21806/Desktop/chapter3/IAPT/lsoa_analysis_output"

capture mkdir "$outdir"

confirm file "$iaptfile"
confirm file "$lookup19"
confirm file "$nomiscsv"

capture log close
log using "$outdir/IAPT_claimant_count_preliminary.log", text replace


/*****************************************************************************
 2. PREPARE THE FIXED APRIL-2019 LSOA-to-LAD LOOKUP
*****************************************************************************/

import delimited using "$lookup19", clear ///
    varnames(1) case(lower) stringcols(_all) encoding("UTF-8")

confirm variable lsoa11cd
confirm variable lad19cd
confirm variable lad19nm

keep lsoa11cd lad19cd lad19nm

replace lsoa11cd = upper(trim(lsoa11cd))
replace lad19cd  = upper(trim(lad19cd))
replace lad19nm  = itrim(trim(lad19nm))

drop if missing(lsoa11cd) | missing(lad19cd)
duplicates drop lsoa11cd lad19cd lad19nm, force
isid lsoa11cd

save "$outdir/LSOA11_to_LAD19_lookup.dta", replace

* A second lookup containing one observation per LAD19.
preserve
keep lad19cd lad19nm
duplicates drop
isid lad19cd
assert _N == 317
save "$outdir/LAD19_code_name_lookup.dta", replace
restore


/*****************************************************************************
 3. IMPORT AND RESHAPE THE NOMIS CLAIMANT-COUNT FILE

 The actual header is on line 9. The source contains 317 LAD rows plus a
 Column Total row and explanatory notes. Rows without a LAD name are removed.
*****************************************************************************/

import delimited using "$nomiscsv", clear ///
    varnames(1) rowrange(9) case(lower) encoding("UTF-8")

* The first imported variable contains the LAD name. Its exact truncated name
* is controlled by Stata, so identify it by position rather than spelling.
unab imported_vars : _all
local ladnamevar : word 1 of `imported_vars'
rename `ladnamevar' lad19nm

replace lad19nm = itrim(trim(lad19nm))
drop if missing(lad19nm)
drop if lower(lad19nm) == "column total"

* Keep only the 317 legitimate LAD names; this also removes Nomis footnotes.
merge m:1 lad19nm using "$outdir/LAD19_code_name_lookup.dta", ///
    keepusing(lad19cd)

tabulate _merge
keep if _merge == 3
drop _merge

assert _N == 317
isid lad19cd

* Rename the 84 monthly columns to a common reshape stub.
ds lad19nm lad19cd, not
local monthvars `r(varlist)'
local nmonths : word count `monthvars'
assert `nmonths' == 84

local j = 0
foreach v of local monthvars {
    local ++j
    rename `v' claimant_count`j'
}

reshape long claimant_count, i(lad19cd lad19nm) j(month_index)

capture confirm numeric variable claimant_count
if _rc destring claimant_count, replace force

generate int mdate = tm(2015m7) + month_index - 1
format mdate %tm

rename lad19cd oslaua
drop month_index

assert inrange(mdate, tm(2015m7), tm(2022m6))
assert !missing(claimant_count)
assert claimant_count >= 0
isid oslaua mdate
assert _N == 317 * 84

generate double ln_claimant_count = ln(claimant_count + 1)

label variable claimant_count "Nomis claimant count, total age 16+"
label variable ln_claimant_count "Log claimant count plus one"
label variable mdate "Calendar month"
label variable oslaua "April 2019 local-authority code"

order oslaua lad19nm mdate claimant_count ln_claimant_count
sort oslaua mdate

save "$outdir/nomis_LAD19_month_claimant_count.dta", replace


/*****************************************************************************
 4. RE-MAP THE IAPT LSOA EXPOSURE TO A FIXED APRIL-2019 LAD GEOGRAPHY
*****************************************************************************/

use "$iaptfile", clear

confirm variable lsoa11cd
confirm variable mdate
confirm variable access_6w
confirm variable delay_6w
confirm variable access_18w
confirm variable delay_18w
confirm variable over18_rate

replace lsoa11cd = upper(trim(lsoa11cd))
format mdate %tm
keep if inrange(mdate, tm(2015m7), tm(2022m6))

* Do not use the pre-existing oslaua: impose the same LAD19 geography as Nomis.
capture drop oslaua
merge m:1 lsoa11cd using "$outdir/LSOA11_to_LAD19_lookup.dta", ///
    keepusing(lad19cd lad19nm)

tabulate _merge
count if _merge == 1
assert r(N) == 0
keep if _merge == 3
drop _merge

rename lad19cd oslaua

* Equal-LSOA-weighted LAD exposure, consistent with the earlier construction.
generate byte one_lsoa = 1

local exposure_vars
foreach v in access_2w access_4w access_6w delay_6w ///
                 access_12w access_18w delay_18w over18_rate {
    capture confirm variable `v'
    if !_rc local exposure_vars `exposure_vars' `v'
}

collapse (mean) `exposure_vars' ///
         (sum) n_lsoa=one_lsoa, by(oslaua lad19nm mdate)

isid oslaua mdate
sort oslaua mdate

label variable n_lsoa "Number of LSOAs contributing to LAD19-month mean"
label data "IAPT exposure by fixed April-2019 LAD and month"

save "$outdir/IAPT_LAD19_month_exposure_equal_LSOA.dta", replace


/*****************************************************************************
 5. MERGE IAPT EXPOSURE WITH CLAIMANT COUNT
*****************************************************************************/

use "$outdir/IAPT_LAD19_month_exposure_equal_LSOA.dta", clear

merge 1:1 oslaua mdate using ///
    "$outdir/nomis_LAD19_month_claimant_count.dta", ///
    keepusing(claimant_count ln_claimant_count)

tabulate _merge
generate byte matched_claimant = (_merge == 3)

preserve
collapse (count) n_lad_month=oslaua ///
         (sum) matched_lad_month=matched_claimant, by(mdate)
generate double match_rate = matched_lad_month / n_lad_month
list mdate n_lad_month matched_lad_month match_rate, noobs separator(0)
save "$outdir/claimant_merge_audit_by_month.dta", replace
restore

keep if _merge == 3
drop _merge matched_claimant

egen long lad_id = group(oslaua), label
xtset lad_id mdate

isid oslaua mdate
assert !missing(claimant_count, ln_claimant_count)

save "$outdir/IAPT_LAD19_claimant_count_panel.dta", replace


/*****************************************************************************
 6. DESCRIPTIVE CHECKS
*****************************************************************************/

summarize claimant_count ln_claimant_count ///
          access_6w delay_6w access_18w delay_18w over18_rate, detail

pwcorr claimant_count ln_claimant_count ///
       access_6w delay_6w access_18w delay_18w over18_rate, sig obs

preserve
collapse (mean) claimant_count access_6w delay_6w ///
                access_18w delay_18w over18_rate, by(mdate)

twoway line claimant_count mdate, ///
    title("Mean claimant count across LAD19 areas") ///
    xtitle("") ytitle("Claimant count") ///
    xline(`=tm(2020m3)', lpattern(dash) lcolor(gs8)) ///
    name(claimant_time, replace)

graph export "$outdir/claimant_count_monthly_mean.png", ///
    width(2200) replace
restore


/*****************************************************************************
 7. TWO-WAY FIXED-EFFECT PRELIMINARY REGRESSIONS

 Coefficient interpretation:
   a one-unit increase in ln(claimant_count + 1), approximately a 100% change
   for large counts, is associated with beta units of the IAPT outcome within
   the same LAD, net of common month shocks.
*****************************************************************************/

capture which reghdfe
if _rc {
    ssc install ftools, replace
    ssc install reghdfe, replace
}

estimates clear

local outcomes access_6w delay_6w access_18w delay_18w over18_rate
local stored_models

foreach y of local outcomes {
    capture confirm variable `y'
    if !_rc {
        quietly count if !missing(`y', ln_claimant_count)
        if r(N) > 0 {
            reghdfe `y' ln_claimant_count, ///
                absorb(lad_id mdate) vce(cluster lad_id)

            estimates store cc_`y'
            local stored_models `stored_models' cc_`y'

            * Save a separate residual for every available IAPT measure.
            predict double `y'_resid_cc if e(sample), residuals

            test ln_claimant_count
            scalar p_`y' = r(p)
        }
    }
}

* One- and twelve-month lag sensitivity tests for the six-week measures.
generate double ln_claimant_lag1  = L1.ln_claimant_count
generate double ln_claimant_lag12 = L12.ln_claimant_count

reghdfe access_6w ln_claimant_lag1 ln_claimant_lag12, ///
    absorb(lad_id mdate) vce(cluster lad_id)
estimates store lag_access6
predict double access_6w_resid_cc_lag if e(sample), residuals

reghdfe delay_6w ln_claimant_lag1 ln_claimant_lag12, ///
    absorb(lad_id mdate) vce(cluster lad_id)
estimates store lag_delay6
predict double delay_6w_resid_cc_lag if e(sample), residuals

* By construction, the contemporaneous residual should be orthogonal to the
* included claimant-count regressor, apart from numerical rounding.
pwcorr access_6w_resid_cc delay_6w_resid_cc ///
       ln_claimant_count claimant_count, sig obs

save "$outdir/IAPT_LAD19_claimant_count_residuals.dta", replace


/*****************************************************************************
 8. EXPORT REGRESSION RESULTS
*****************************************************************************/

capture which esttab
if _rc capture ssc install estout, replace

capture which esttab
if !_rc {
    esttab `stored_models' using ///
        "$outdir/IAPT_claimant_count_contemporaneous_results.rtf", ///
        replace se star(* 0.10 ** 0.05 *** 0.01) ///
        keep(ln_claimant_count) ///
        stats(N r2, labels("Observations" "R-squared")) ///
        mtitles("Access 6w" "Delay 6w" "Access 18w" ///
                "Delay 18w" "Over 18w") ///
        title("IAPT outcomes and local claimant count: LAD and month fixed effects")

    esttab lag_access6 lag_delay6 using ///
        "$outdir/IAPT_claimant_count_lagged_results.rtf", ///
        replace se star(* 0.10 ** 0.05 *** 0.01) ///
        keep(ln_claimant_lag1 ln_claimant_lag12) ///
        stats(N r2, labels("Observations" "R-squared")) ///
        mtitles("Access 6w" "Delay 6w") ///
        title("Lagged claimant count and IAPT outcomes")
}


/*****************************************************************************
 9. FINAL VALIDATION AND OUTPUT LIST
*****************************************************************************/

use "$outdir/IAPT_LAD19_claimant_count_residuals.dta", clear

isid oslaua mdate
assert inrange(mdate, tm(2015m7), tm(2022m6))
assert !missing(claimant_count, ln_claimant_count)

describe oslaua lad19nm mdate claimant_count ln_claimant_count ///
         access_6w delay_6w access_6w_resid_cc delay_6w_resid_cc

display as result "============================================================"
display as result "PRELIMINARY CLAIMANT-COUNT ANALYSIS COMPLETED"
display as result "Main panel:"
display as result "$outdir/IAPT_LAD19_claimant_count_panel.dta"
display as result "Panel with waiting-time residuals:"
display as result "$outdir/IAPT_LAD19_claimant_count_residuals.dta"
display as result "Regression table:"
display as result "$outdir/IAPT_claimant_count_contemporaneous_results.rtf"
display as result "============================================================"

log close
clear
