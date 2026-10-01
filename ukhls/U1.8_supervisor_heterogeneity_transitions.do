********************************************************************************
* U1.8_supervisor_heterogeneity_transitions.do
* Supervisor requests:
*   1. First and second stages by initial GHQ group
*   2. Employment at t+1, conditional on working/not working at t
*   3. Results by submarket mobility, matching efficiency, and stress
*
* Confirmed input from the existing project:
*   C:/Users/hm21806/Desktop/chapter3/code202602_newjobf/ghqevent.dta
*
* IMPORTANT:
* - Edit the five variable-name macros in Section 0 before running.
* - The code never silently guesses an unconfirmed variable.
* - Initial GHQ means lagged GHQ (L.ghq), not contemporaneous endogenous GHQ.
* - All competing IV sets within an analysis use a locked common sample.
********************************************************************************

version 18
clear all
set more off
set linesize 255
set maxvar 20000

*==============================================================================*
* 0. PATHS AND VARIABLE NAMES
*==============================================================================*

global project "C:/Users/hm21806/Desktop/chapter3/code202602_newjobf"
global datadir "$project"
global outdir  "$project/supervisor_heterogeneity_output"

capture mkdir "$outdir"
cd "$project"

capture log close _all
log using "$outdir/U1.8_supervisor_heterogeneity_transitions.log", ///
    text replace name(main)

*----------------------- USER CHECK REQUIRED -------------------------------*
* Put the exact variable names from ghqevent.dta inside the quotation marks.
*
* A binary indicator equal to 1 if working at t and 0 otherwise.
local working_t_var ""

* A binary indicator equal to 1 if working at t+1 and 0 otherwise.
local working_t1_var ""

* Continuous or ordered submarket-level measures attached to each person-wave.
local mobility_var ""
local matching_efficiency_var ""
local stress_var ""
*----------------------------------------------------------------------------*

* Set to 1 only after the variables above have been filled in and checked.
local run_employment_transition 0
local run_submarket_analysis    0

* Main variables already used in U1.6/U1.7.
local y_main   newjob
local d        ghq
local controls lnw dvage age2 male i.year

local z_core deathfam
local z_A    deathfam vacation familyprob
local z_B    deathfam vacation familyprob anniversary

use "$datadir/ghqevent.dta", clear
replace ghq = . if ghq < 0

* Confirm the variables that are already known from the existing analysis.
foreach v in pidp wave year newjob ghq lnw dvage age2 male ///
    deathfam vacation familyprob anniversary {
    capture confirm variable `v'
    if _rc {
        display as error "Required variable `v' is not in ghqevent.dta."
        exit 111
    }
}

capture isid pidp wave
if _rc {
    display as error "pidp-wave does not uniquely identify observations."
    display as error "Panel lags cannot be constructed safely."
    exit 459
}
xtset pidp wave

* Store all subgroup results in one dataset.
tempname results_mem
tempfile results_file
postfile `results_mem' ///
    str28 analysis str40 group_name str8 specification str20 outcome ///
    double fs_b fs_se fs_F fs_p iv_b iv_se iv_p ols_b ols_se N ///
    using `results_file', replace

*==============================================================================*
* 1. INITIAL GHQ GROUPS
*==============================================================================*

display as text _newline "===== 1. RESULTS BY INITIAL GHQ ====="

* Initial GHQ is measured in the preceding observed wave.
capture drop ghq_initial
gen double ghq_initial = L.ghq
label variable ghq_initial "GHQ measured in the previous wave"

* Lock a common sample for Baseline, Expanded A, and Expanded B.
capture drop sample_initial_ghq
gen byte sample_initial_ghq = 1
foreach v in `y_main' `d' ghq_initial lnw dvage age2 male year pidp ///
    deathfam vacation familyprob anniversary {
    replace sample_initial_ghq = 0 if missing(`v')
}

count if sample_initial_ghq
display as result "Initial-GHQ common sample N = " r(N)

* Use sample tertiles because no validated clinical cut-offs for the 0-36
* Likert total have been supplied. Report the cut-offs produced by Stata.
capture drop ghq_initial_group
xtile ghq_initial_group = ghq_initial if sample_initial_ghq, nq(3)
label define ghq_initial_lab 1 "Low initial GHQ" ///
    2 "Middle initial GHQ" 3 "High initial GHQ", replace
label values ghq_initial_group ghq_initial_lab

tab ghq_initial_group if sample_initial_ghq, missing
tabstat ghq_initial if sample_initial_ghq, ///
    by(ghq_initial_group) statistics(n min p50 max mean sd)

forvalues g = 1/3 {
    local glabel : label ghq_initial_lab `g'

    foreach spec in core A B {
        local z
        if "`spec'" == "core" local z "`z_core'"
        if "`spec'" == "A"    local z "`z_A'"
        if "`spec'" == "B"    local z "`z_B'"

        display as text _newline ///
            "Initial GHQ: `glabel' | IV set: `spec' | Instruments: `z'"

        * First stage within the initial-GHQ group.
        quietly regress `d' `z' `controls' ///
            if sample_initial_ghq & ghq_initial_group==`g', ///
            vce(cluster pidp)
        local fs_b  = _b[deathfam]
        local fs_se = _se[deathfam]
        quietly test `z'
        local fs_F = r(F)
        local fs_p = r(p)
        noisily regress `d' `z' `controls' ///
            if sample_initial_ghq & ghq_initial_group==`g', ///
            vce(cluster pidp)
        noisily test `z'

        * OLS association on the same subgroup sample.
        quietly regress `y_main' `d' `controls' ///
            if sample_initial_ghq & ghq_initial_group==`g', ///
            vce(cluster pidp)
        local ols_b  = _b[`d']
        local ols_se = _se[`d']

        * Second stage.
        quietly ivregress 2sls `y_main' `controls' (`d'=`z') ///
            if sample_initial_ghq & ghq_initial_group==`g', ///
            vce(cluster pidp)
        local iv_b  = _b[`d']
        local iv_se = _se[`d']
        local iv_p  = 2*normal(-abs(`iv_b'/`iv_se'))
        local N     = e(N)

        noisily ivregress 2sls `y_main' `controls' (`d'=`z') ///
            if sample_initial_ghq & ghq_initial_group==`g', ///
            vce(cluster pidp)
        noisily estat firststage
        capture noisily estat endogenous
        capture noisily weakiv
        capture noisily ivreg2 `y_main' `controls' (`d'=`z') ///
            if sample_initial_ghq & ghq_initial_group==`g', ///
            cluster(pidp) first

        post `results_mem' ("initial_GHQ") ("`glabel'") ///
            ("`spec'") ("newjob") ///
            (`fs_b') (`fs_se') (`fs_F') (`fs_p') ///
            (`iv_b') (`iv_se') (`iv_p') (`ols_b') (`ols_se') (`N')
    }
}

*==============================================================================*
* 2. EMPLOYMENT AT t+1 CONDITIONAL ON EMPLOYMENT AT t
*==============================================================================*

display as text _newline ///
    "===== 2. WORKING/NOT WORKING AT t TO WORKING/NOT WORKING AT t+1 ====="

if `run_employment_transition' == 1 {

    if "`working_t_var'" == "" | "`working_t1_var'" == "" {
        display as error ///
            "Set working_t_var and working_t1_var before running Section 2."
        exit 198
    }

    foreach v in `working_t_var' `working_t1_var' {
        capture confirm variable `v'
        if _rc {
            display as error "Employment variable `v' was not found."
            exit 111
        }
        assert inlist(`v',0,1) if !missing(`v')
    }

    capture drop sample_employment
    gen byte sample_employment = 1
    foreach v in `working_t_var' `working_t1_var' `d' lnw dvage age2 ///
        male year pidp deathfam vacation familyprob anniversary {
        replace sample_employment = 0 if missing(`v')
    }

    tab `working_t_var' `working_t1_var' if sample_employment, ///
        row column

    forvalues start_work = 0/1 {
        if `start_work' == 0 local glabel "Not working at t"
        if `start_work' == 1 local glabel "Working at t"

        foreach spec in core A B {
            local z
            if "`spec'" == "core" local z "`z_core'"
            if "`spec'" == "A"    local z "`z_A'"
            if "`spec'" == "B"    local z "`z_B'"

            display as text _newline ///
                "`glabel' | Outcome: working at t+1 | IV set: `spec'"

            * First stage conditional on employment at t.
            quietly regress `d' `z' `controls' ///
                if sample_employment & `working_t_var'==`start_work', ///
                vce(cluster pidp)
            local fs_b  = _b[deathfam]
            local fs_se = _se[deathfam]
            quietly test `z'
            local fs_F = r(F)
            local fs_p = r(p)
            noisily regress `d' `z' `controls' ///
                if sample_employment & `working_t_var'==`start_work', ///
                vce(cluster pidp)
            noisily test `z'

            * OLS transition equation.
            quietly regress `working_t1_var' `d' `controls' ///
                if sample_employment & `working_t_var'==`start_work', ///
                vce(cluster pidp)
            local ols_b  = _b[`d']
            local ols_se = _se[`d']

            * IV transition equation.
            quietly ivregress 2sls `working_t1_var' `controls' ///
                (`d'=`z') ///
                if sample_employment & `working_t_var'==`start_work', ///
                vce(cluster pidp)
            local iv_b  = _b[`d']
            local iv_se = _se[`d']
            local iv_p  = 2*normal(-abs(`iv_b'/`iv_se'))
            local N     = e(N)

            noisily ivregress 2sls `working_t1_var' `controls' ///
                (`d'=`z') ///
                if sample_employment & `working_t_var'==`start_work', ///
                vce(cluster pidp)
            noisily estat firststage
            capture noisily weakiv
            capture noisily ivreg2 `working_t1_var' `controls' ///
                (`d'=`z') ///
                if sample_employment & `working_t_var'==`start_work', ///
                cluster(pidp) first

            post `results_mem' ("employment_transition") ("`glabel'") ///
                ("`spec'") ("working_t1") ///
                (`fs_b') (`fs_se') (`fs_F') (`fs_p') ///
                (`iv_b') (`iv_se') (`iv_p') (`ols_b') (`ols_se') (`N')
        }
    }
}
else {
    display as error ///
        "Section 2 skipped: set employment variable names and run_employment_transition=1."
}

*==============================================================================*
* 3. SUBMARKETS: MOBILITY, MATCHING EFFICIENCY, AND STRESS
*==============================================================================*

display as text _newline ///
    "===== 3. RESULTS BY SUBMARKET CHARACTERISTICS ====="

if `run_submarket_analysis' == 1 {

    if "`mobility_var'" == "" | "`matching_efficiency_var'" == "" ///
        | "`stress_var'" == "" {
        display as error ///
            "Set all three submarket-variable macros before running Section 3."
        exit 198
    }

    foreach v in `mobility_var' `matching_efficiency_var' `stress_var' {
        capture confirm variable `v'
        if _rc {
            display as error "Submarket variable `v' was not found."
            exit 111
        }
        summarize `v', detail
    }

    * Lock one sample across all three submarket measures and all plotted IVs.
    capture drop sample_submarket
    gen byte sample_submarket = 1
    foreach v in `y_main' `d' lnw dvage age2 male year pidp ///
        deathfam vacation familyprob anniversary ///
        `mobility_var' `matching_efficiency_var' `stress_var' {
        replace sample_submarket = 0 if missing(`v')
    }

    * Divide each submarket characteristic into terciles in the common sample.
    capture drop mobility_group matching_group stress_group
    xtile mobility_group = `mobility_var' if sample_submarket, nq(3)
    xtile matching_group = `matching_efficiency_var' if sample_submarket, nq(3)
    xtile stress_group = `stress_var' if sample_submarket, nq(3)

    label define tercile_lab 1 "Low" 2 "Middle" 3 "High", replace
    label values mobility_group tercile_lab
    label values matching_group tercile_lab
    label values stress_group tercile_lab

    tabstat `mobility_var', by(mobility_group) ///
        statistics(n min p50 max mean sd)
    tabstat `matching_efficiency_var', by(matching_group) ///
        statistics(n min p50 max mean sd)
    tabstat `stress_var', by(stress_group) ///
        statistics(n min p50 max mean sd)

    foreach dimension in mobility matching stress {
        local groupvar `dimension'_group
        local sourcevar
        if "`dimension'" == "mobility" ///
            local sourcevar "`mobility_var'"
        if "`dimension'" == "matching" ///
            local sourcevar "`matching_efficiency_var'"
        if "`dimension'" == "stress" ///
            local sourcevar "`stress_var'"

        forvalues g = 1/3 {
            local tercile : label tercile_lab `g'
            local glabel "`tercile' `dimension'"

            foreach spec in core A B {
                local z
                if "`spec'" == "core" local z "`z_core'"
                if "`spec'" == "A"    local z "`z_A'"
                if "`spec'" == "B"    local z "`z_B'"

                display as text _newline ///
                    "Submarket: `glabel' | IV set: `spec'"

                * First stage within submarket tercile.
                quietly regress `d' `z' `controls' ///
                    if sample_submarket & `groupvar'==`g', ///
                    vce(cluster pidp)
                local fs_b  = _b[deathfam]
                local fs_se = _se[deathfam]
                quietly test `z'
                local fs_F = r(F)
                local fs_p = r(p)
                noisily regress `d' `z' `controls' ///
                    if sample_submarket & `groupvar'==`g', ///
                    vce(cluster pidp)
                noisily test `z'

                * OLS on the same subgroup sample.
                quietly regress `y_main' `d' `controls' ///
                    if sample_submarket & `groupvar'==`g', ///
                    vce(cluster pidp)
                local ols_b  = _b[`d']
                local ols_se = _se[`d']

                * Second stage.
                quietly ivregress 2sls `y_main' `controls' (`d'=`z') ///
                    if sample_submarket & `groupvar'==`g', ///
                    vce(cluster pidp)
                local iv_b  = _b[`d']
                local iv_se = _se[`d']
                local iv_p  = 2*normal(-abs(`iv_b'/`iv_se'))
                local N     = e(N)

                noisily ivregress 2sls `y_main' `controls' (`d'=`z') ///
                    if sample_submarket & `groupvar'==`g', ///
                    vce(cluster pidp)
                noisily estat firststage
                capture noisily weakiv
                capture noisily ivreg2 `y_main' `controls' (`d'=`z') ///
                    if sample_submarket & `groupvar'==`g', ///
                    cluster(pidp) first

                post `results_mem' ("submarket_`dimension'") ///
                    ("`glabel'") ("`spec'") ("newjob") ///
                    (`fs_b') (`fs_se') (`fs_F') (`fs_p') ///
                    (`iv_b') (`iv_se') (`iv_p') ///
                    (`ols_b') (`ols_se') (`N')
            }
        }
    }
}
else {
    display as error ///
        "Section 3 skipped: set submarket variable names and run_submarket_analysis=1."
}

*==============================================================================*
* 4. EXPORT RESULTS AND COEFFICIENT FIGURES
*==============================================================================*

postclose `results_mem'

preserve
use `results_file', clear

gen iv_lb = iv_b - 1.96*iv_se
gen iv_ub = iv_b + 1.96*iv_se
gen ols_lb = ols_b - 1.96*ols_se
gen ols_ub = ols_b + 1.96*ols_se
gen byte weak_F10 = fs_F < 10 if !missing(fs_F)

order analysis group_name specification outcome N ///
    fs_b fs_se fs_F fs_p iv_b iv_se iv_p iv_lb iv_ub ///
    ols_b ols_se ols_lb ols_ub weak_F10
sort analysis group_name specification

save "$outdir/U1.8_all_subgroup_results.dta", replace
export delimited using "$outdir/U1.8_all_subgroup_results.csv", replace

* Separate files make appendix tables easier to construct.
preserve
keep if analysis=="initial_GHQ"
save "$outdir/U1.8_initial_GHQ_results.dta", replace
export delimited using "$outdir/U1.8_initial_GHQ_results.csv", replace
restore

preserve
keep if analysis=="employment_transition"
save "$outdir/U1.8_employment_transition_results.dta", replace
export delimited using ///
    "$outdir/U1.8_employment_transition_results.csv", replace
restore

preserve
keep if substr(analysis,1,10)=="submarket_"
save "$outdir/U1.8_submarket_results.dta", replace
export delimited using "$outdir/U1.8_submarket_results.csv", replace
restore

list analysis group_name specification outcome fs_F iv_b iv_se iv_p ///
    ols_b ols_se N, noobs sepby(analysis group_name)

restore

display as result _newline ///
    "U1.8 SUPERVISOR HETEROGENEITY AND TRANSITION FILE COMPLETED."
display as text "Output directory: $outdir"

log close main

********************************************************************************
* END OF FILE
********************************************************************************
