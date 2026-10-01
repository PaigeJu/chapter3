********************************************************************************
* U1.7_master_IV_selection_tests.do
* Master do-file: life-event IV selection, diagnostics, and appendix results
* Project: Chapter 3 - mental health and labour-market transitions
*
* Input : C:/Users/hm21806/Desktop/chapter3/code202602_newjobf/ghqevent.dta
* Output: C:/Users/hm21806/Desktop/chapter3/code202602_newjobf/iv_selection_output
*
* IMPORTANT
* 1. All headline IV sets are estimated on one locked common sample.
* 2. All models use the same controls, year fixed effects, and pidp clustering.
* 3. Statistical tests do not establish the exclusion restriction.
* 4. Send all .log, .txt, .csv, .dta and graph files in iv_selection_output.
********************************************************************************

version 17
clear all
set more off
set linesize 255
set maxvar 20000

*==============================================================================*
* 0. PATHS, DATA, PACKAGES, AND LOGS
*==============================================================================*

global project "C:/Users/hm21806/Desktop/chapter3/code202602_newjobf"
global datadir "$project"
global outdir  "$project/iv_selection_output"

capture mkdir "$outdir"
cd "$project"

capture log close _all
log using "$outdir/00_master_IV_selection.log", text replace name(master)

display as text "Project directory: $project"
display as text "Input data:        $datadir/ghqevent.dta"
display as text "Output directory:  $outdir"

* Required user-written commands. Existing code shows these are already used.
local required ivreg2 ranktest weakiv weakivtest
foreach cmd of local required {
    capture which `cmd'
    if _rc {
        display as error "Required command `cmd' is not installed."
        display as error "Install it before re-running this master do-file."
        exit 199
    }
}

use "$datadir/ghqevent.dta", clear

* Clean UKHLS negative non-response codes used in the existing analysis.
replace ghq = . if ghq < 0

* Clean negative UKHLS non-response codes in direct-channel variables.
* nkids_change is excluded because a genuine fall in children can be negative.
foreach v in aidhrs_f aideft_f lkmove xpmove family_f rls_change marstat_dv {
    capture confirm variable `v'
    if !_rc replace `v' = . if `v' < 0
}

* Main variables and instrument sets from the existing do-files.
local y        newjob
local d        ghq
local controls lnw dvage age2 male i.year

local z_core   deathfam
local z_A      deathfam vacation familyprob
local z_B      deathfam vacation familyprob anniversary
local z_full   deathfam familyprob neighbour friendend vacation leisure ///
               engage birthday anniversary godparent relatives friends

* Confirm that every required main variable exists.
foreach v in `y' `d' lnw dvage age2 male year pidp `z_full' {
    capture confirm variable `v'
    if _rc {
        display as error "Required variable `v' is missing from ghqevent.dta."
        exit 111
    }
}

* Basic panel declaration. wave is used only for lags/placebos.
capture confirm variable wave
if !_rc {
    capture isid pidp wave
    if _rc {
        display as error "pidp-wave is not unique; lag/placebo block will be skipped."
        local panel_ok 0
    }
    else {
        xtset pidp wave
        local panel_ok 1
    }
}
else {
    display as error "wave is unavailable; lag/placebo block will be skipped."
    local panel_ok 0
}

*==============================================================================*
* 1. DATA AND CODING AUDIT
*==============================================================================*

display as text _newline "===== 1. DATA AND CODING AUDIT ====="
describe `y' `d' lnw dvage age2 male year wave pidp `z_full'
summarize `y' `d' lnw dvage age2 male `z_full', detail
misstable summarize `y' `d' lnw dvage age2 male year pidp `z_full'

foreach z of local z_full {
    tab `z', missing
    assert inlist(`z',0,1) if !missing(`z')
}

assert inrange(`d',0,36) if !missing(`d')
assert inlist(`y',0,1) if !missing(`y')

* Direct-channel variables already used in U1.6.
local channels nkids_change aidhrs_f aideft_f lkmove xpmove family_f ///
               rls_change marstat_dv
foreach v of local channels {
    capture confirm variable `v'
    if !_rc {
        tab `v', missing
        summarize `v', detail
    }
}

*==============================================================================*
* 2. LOCK ONE COMMON SAMPLE FOR ALL COMPETING IV SETS
*==============================================================================*

display as text _newline "===== 2. COMMON ESTIMATION SAMPLE ====="

capture drop sample_iv
gen byte sample_iv = 1
foreach v in `y' `d' lnw dvage age2 male year pidp `z_full' {
    replace sample_iv = 0 if missing(`v')
}

count if sample_iv
display as result "Locked common IV sample N = " r(N)
tab year if sample_iv, missing
egen byte tag_pidp = tag(pidp) if sample_iv
count if tag_pidp
display as result "Unique individuals in locked sample = " r(N)
drop tag_pidp

label variable sample_iv "Locked common sample for all life-event IV sets"
save "$outdir/analysis_sample_with_sample_iv.dta", replace

* Export an auditable sample-count file.
preserve
keep if sample_iv
contract year, freq(N)
export delimited using "$outdir/01_common_sample_by_year.csv", replace
restore

*==============================================================================*
* 3. DESCRIPTIVE RELEVANCE SCREEN - NOT AN IV VALIDITY TEST
*==============================================================================*

display as text _newline "===== 3. JOINT FIRST-STAGE RELEVANCE SCREEN ====="

regress `d' `z_full' `controls' if sample_iv, vce(cluster pidp)
test `z_full'

tempname fs_mem
tempfile fs_results
postfile `fs_mem' str20 instrument double b se t p using `fs_results', replace

foreach z of local z_full {
    local b  = _b[`z']
    local se = _se[`z']
    local t  = `b'/`se'
    local p  = 2*normal(-abs(`t'))
    post `fs_mem' ("`z'") (`b') (`se') (`t') (`p')
}
postclose `fs_mem'

preserve
use `fs_results', clear
gen lb = b - 1.96*se
gen ub = b + 1.96*se
sort p
encode instrument, gen(inst_n)
export delimited using "$outdir/02_candidate_IV_joint_firststage.csv", replace
save "$outdir/02_candidate_IV_joint_firststage.dta", replace

twoway (rcap lb ub inst_n, horizontal) ///
       (scatter inst_n b, msymbol(O)), ///
       xline(0, lpattern(dash) lcolor(gs8)) ///
       ylabel(1(1)12, valuelabel angle(0) labsize(small)) ///
       xtitle("Coefficient in joint GHQ first stage") ytitle("") ///
       title("Candidate life events and GHQ") ///
       subtitle("Common sample; 95% clustered confidence intervals") ///
       legend(off) graphregion(color(white))
graph export "$outdir/02_candidate_IV_joint_firststage.png", replace width(2400)
restore

*==============================================================================*
* 4. CORE-IV FIRST STAGE, REDUCED FORM, AND 2SLS
*==============================================================================*

display as text _newline "===== 4. CORE IV: DEATHFAM ====="

* 4.1 First stage: coefficient, partial R-squared, and clustered F.
regress `d' `z_core' `controls' if sample_iv, vce(cluster pidp)
test `z_core'
summarize `d' if e(sample)
display as result "Standardised deathfam first stage = " _b[deathfam]/r(sd)

* 4.2 Reduced form. This is not an exclusion test.
regress `y' `z_core' `controls' if sample_iv, vce(cluster pidp)

* 4.3 Exact-ID 2SLS and standard diagnostics.
ivregress 2sls `y' `controls' (`d' = `z_core') if sample_iv, ///
    vce(cluster pidp)
estimates store IV_core_2SLS
estat firststage
capture noisily estat endogenous

* 4.4 Weak-IV diagnostics and weak-IV-robust inference.
capture noisily weakivtest
capture noisily weakiv

* 4.5 LIML robustness. Exact-ID LIML equals 2SLS in point estimation.
ivregress liml `y' `controls' (`d' = `z_core') if sample_iv, ///
    vce(cluster pidp)
estimates store IV_core_LIML
capture noisily weakiv

* 4.6 ivreg2 output: KP underidentification and weak-ID diagnostics.
ivreg2 `y' `controls' (`d' = `z_core') if sample_iv, ///
    cluster(pidp) first

*==============================================================================*
* 5. TARGETED EXCLUSION/FALSIFICATION CHECKS FOR DEATHFAM
*==============================================================================*

display as text _newline "===== 5. TARGETED CHANNEL AND FALSIFICATION CHECKS ====="

tempname ch_mem
tempfile channel_results
postfile `ch_mem' str32 outcome double b se p N using `channel_results', replace

* These are observable direct channels, not formal exclusion tests.
foreach q in nkids_change aidhrs_f aideft_f lkmove xpmove family_f {
    capture confirm variable `q'
    if !_rc {
        quietly regress `q' deathfam `controls' if sample_iv, vce(cluster pidp)
        local b  = _b[deathfam]
        local se = _se[deathfam]
        local p  = 2*normal(-abs(`b'/`se'))
        post `ch_mem' ("`q'") (`b') (`se') (`p') (e(N))
        noisily regress `q' deathfam `controls' if sample_iv, vce(cluster pidp)
    }
}

* Relationship outcomes used in the existing code.
capture confirm variable rls_change
local has_rls = !_rc
capture confirm variable marstat_dv
local has_mar = !_rc
if `has_rls' & `has_mar' {
    capture drop married_couple married separated_divorced divorced
    gen byte married_couple = (rls_change==1 & inlist(marstat_dv,1,2)) ///
        if !missing(rls_change,marstat_dv)
    gen byte married = (rls_change==1 & marstat_dv==1) ///
        if !missing(rls_change,marstat_dv)
    gen byte separated_divorced = (rls_change==1 & inlist(marstat_dv,4,5)) ///
        if !missing(rls_change,marstat_dv)
    gen byte divorced = (rls_change==1 & marstat_dv==4) ///
        if !missing(rls_change,marstat_dv)

    foreach q in rls_change married_couple married separated_divorced divorced {
        quietly regress `q' deathfam `controls' if sample_iv, vce(cluster pidp)
        local b  = _b[deathfam]
        local se = _se[deathfam]
        local p  = 2*normal(-abs(`b'/`se'))
        post `ch_mem' ("`q'") (`b') (`se') (`p') (e(N))
        noisily regress `q' deathfam `controls' if sample_iv, vce(cluster pidp)
    }
}

* Pre-event outcomes and future-event placebo, where panel structure permits.
if `panel_ok' {
    capture drop L_newjob L_lnw L_ghq F_deathfam
    gen double L_newjob  = L.newjob
    gen double L_lnw     = L.lnw
    gen double L_ghq     = L.ghq
    gen double F_deathfam = F.deathfam

    foreach q in L_newjob L_lnw L_ghq {
        quietly regress `q' deathfam `controls' if sample_iv, vce(cluster pidp)
        local b  = _b[deathfam]
        local se = _se[deathfam]
        local p  = 2*normal(-abs(`b'/`se'))
        post `ch_mem' ("`q'") (`b') (`se') (`p') (e(N))
        noisily regress `q' deathfam `controls' if sample_iv, vce(cluster pidp)
    }

    * A future bereavement should not predict current GHQ or current mobility.
    foreach q in ghq newjob {
        quietly regress `q' F_deathfam `controls' if sample_iv, vce(cluster pidp)
        local b  = _b[F_deathfam]
        local se = _se[F_deathfam]
        local p  = 2*normal(-abs(`b'/`se'))
        post `ch_mem' ("`q'_on_Fdeathfam") (`b') (`se') (`p') (e(N))
        noisily regress `q' F_deathfam `controls' if sample_iv, vce(cluster pidp)
    }
}

postclose `ch_mem'
preserve
use `channel_results', clear
gen lb = b - 1.96*se
gen ub = b + 1.96*se
export delimited using "$outdir/03_deathfam_channels_placebos.csv", replace
save "$outdir/03_deathfam_channels_placebos.dta", replace
restore

* Attrition/outcome-observability variables are not defined in the supplied
* code. If they are later added to ghqevent.dta under these names, this block
* runs automatically. Otherwise the log records that the test was unavailable.
local attrition_vars response_t1 observed_newjob_t1 observed_lnw_diff_t1
foreach q of local attrition_vars {
    capture confirm variable `q'
    if !_rc {
        regress `q' deathfam `controls' if sample_iv, vce(cluster pidp)
    }
    else {
        display as error "Attrition variable `q' not found: test not run."
    }
}

*==============================================================================*
* 6. BASELINE, EXPANDED A, EXPANDED B, AND FULL SET
*==============================================================================*

display as text _newline "===== 6. COMPARISON OF IV SETS ====="

tempname set_mem
tempfile set_results
postfile `set_mem' str18 specification str8 estimator double b se p N ///
    using `set_results', replace

foreach spec in core A B full {
    local z
    if "`spec'" == "core" local z "`z_core'"
    if "`spec'" == "A"    local z "`z_A'"
    if "`spec'" == "B"    local z "`z_B'"
    if "`spec'" == "full" local z "`z_full'"
    if "`z'" == "" {
        display as error "Instrument-set mapping failed for specification `spec'."
        exit 198
    }

    display as text _newline "----- IV set: `spec' | Instruments: `z' -----"

    * Joint first stage and cluster-robust excluded-instrument F.
    regress `d' `z' `controls' if sample_iv, vce(cluster pidp)
    test `z'

    * 2SLS, first stage, weak-IV robust inference.
    ivregress 2sls `y' `controls' (`d' = `z') if sample_iv, ///
        vce(cluster pidp)
    estimates store IV_`spec'_2SLS
    local b  = _b[`d']
    local se = _se[`d']
    local p  = 2*normal(-abs(`b'/`se'))
    post `set_mem' ("`spec'") ("2SLS") (`b') (`se') (`p') (e(N))
    estat firststage
    capture noisily estat endogenous
    capture noisily weakivtest
    capture noisily weakiv
    if "`spec'" != "core" capture noisily estat overid

    * LIML robustness.
    ivregress liml `y' `controls' (`d' = `z') if sample_iv, ///
        vce(cluster pidp)
    estimates store IV_`spec'_LIML
    local b  = _b[`d']
    local se = _se[`d']
    local p  = 2*normal(-abs(`b'/`se'))
    post `set_mem' ("`spec'") ("LIML") (`b') (`se') (`p') (e(N))
    capture noisily weakiv

    * ivreg2 supplies KP rk LM, KP rk Wald F, AR, and Hansen J.
    ivreg2 `y' `controls' (`d' = `z') if sample_iv, ///
        cluster(pidp) first
}
postclose `set_mem'

preserve
use `set_results', clear
gen lb = b - 1.96*se
gen ub = b + 1.96*se
export delimited using "$outdir/04_IV_set_estimates.csv", replace
save "$outdir/04_IV_set_estimates.dta", replace

encode specification, gen(spec_n)
gen yplot = spec_n + cond(estimator=="LIML",0.10,-0.10)
twoway (rcap lb ub yplot if estimator=="2SLS", horizontal) ///
       (scatter yplot b if estimator=="2SLS", msymbol(O)) ///
       (rcap lb ub yplot if estimator=="LIML", horizontal lpattern(dash)) ///
       (scatter yplot b if estimator=="LIML", msymbol(D)), ///
       xline(0, lpattern(dash) lcolor(gs8)) ///
       ylabel(1(1)4, valuelabel angle(0)) ///
       xtitle("Coefficient on GHQ") ytitle("") ///
       title("Life-event IV specifications") ///
       legend(order(2 "2SLS" 4 "LIML")) graphregion(color(white))
graph export "$outdir/04_IV_set_estimates.png", replace width(2400)
restore

*==============================================================================*
* 7. CONDITIONAL C TESTS FOR INCREMENTAL INSTRUMENTS
*==============================================================================*

display as text _newline "===== 7. CONDITIONAL C TESTS ====="
display as text "Interpret each C test conditional on deathfam being valid."

* Test each added instrument separately, maintaining deathfam as core.
foreach z in vacation familyprob anniversary friendend leisure {
    display as text _newline "C test for added instrument: `z'"
    capture noisily ivreg2 `y' `controls' (`d' = deathfam `z') ///
        if sample_iv, cluster(pidp) orthog(`z') first
}

* Test additions jointly in Expanded A and Expanded B.
capture noisily ivreg2 `y' `controls' ///
    (`d' = deathfam vacation familyprob) if sample_iv, ///
    cluster(pidp) orthog(vacation familyprob) first

capture noisily ivreg2 `y' `controls' ///
    (`d' = deathfam vacation familyprob anniversary) if sample_iv, ///
    cluster(pidp) orthog(vacation familyprob anniversary) first

*==============================================================================*
* 8. EACH CANDIDATE AS A SINGLE IV ON THE SAME COMMON SAMPLE
*==============================================================================*

display as text _newline "===== 8. SINGLE-CANDIDATE IV RESULTS ====="

tempname one_mem
tempfile one_results
postfile `one_mem' str20 instrument double fs_b fs_se fs_F rf_b rf_se ///
    iv_b iv_se ar_p N using `one_results', replace

foreach z of local z_full {
    quietly regress `d' `z' `controls' if sample_iv, vce(cluster pidp)
    local fs_b  = _b[`z']
    local fs_se = _se[`z']
    quietly test `z'
    local fs_F = r(F)

    quietly regress `y' `z' `controls' if sample_iv, vce(cluster pidp)
    local rf_b  = _b[`z']
    local rf_se = _se[`z']

    quietly ivregress 2sls `y' `controls' (`d' = `z') if sample_iv, ///
        vce(cluster pidp)
    local iv_b  = _b[`d']
    local iv_se = _se[`d']

    * weakiv must immediately follow ivregress/ivregress liml.
    noisily ivregress 2sls `y' `controls' (`d' = `z') if sample_iv, ///
        vce(cluster pidp)
    capture noisily weakiv

    * AR p-value for H0: beta=0 from ivreg2 output is displayed in the log.
    * It is not reliably stored under one universal scalar across versions.
    noisily ivreg2 `y' `controls' (`d' = `z') if sample_iv, ///
        cluster(pidp) first
    local ar_p = .

    post `one_mem' ("`z'") (`fs_b') (`fs_se') (`fs_F') ///
        (`rf_b') (`rf_se') (`iv_b') (`iv_se') (`ar_p') (e(N))
}
postclose `one_mem'

preserve
use `one_results', clear
gen iv_lb = iv_b - 1.96*iv_se
gen iv_ub = iv_b + 1.96*iv_se
gen weak_flag = fs_F < 10
sort iv_b
encode instrument, gen(inst_n)
export delimited using "$outdir/05_single_candidate_IV_results.csv", replace
save "$outdir/05_single_candidate_IV_results.dta", replace

twoway (rcap iv_lb iv_ub inst_n, horizontal) ///
       (scatter inst_n iv_b if weak_flag==0, msymbol(O)) ///
       (scatter inst_n iv_b if weak_flag==1, msymbol(X) mcolor(red)), ///
       xline(0, lpattern(dash) lcolor(gs8)) ///
       ylabel(1(1)12, valuelabel angle(0) labsize(small)) ///
       xtitle("Just-identified 2SLS coefficient on GHQ") ytitle("") ///
       title("Instrument-specific IV estimates") ///
       subtitle("X marks first-stage F below 10; common sample") ///
       legend(order(2 "F >= 10" 3 "F < 10")) graphregion(color(white))
graph export "$outdir/05_single_candidate_IV_results.png", replace width(2400)
restore

*==============================================================================*
* 9. FIRST-STAGE HETEROGENEITY AND SUBGROUP IV ESTIMATES
*==============================================================================*

display as text _newline "===== 9. HETEROGENEITY ====="

capture drop agegrp wagegrp
gen byte agegrp = .
replace agegrp = 1 if inrange(dvage,16,29)
replace agegrp = 2 if inrange(dvage,30,39)
replace agegrp = 3 if inrange(dvage,40,49)
replace agegrp = 4 if inrange(dvage,50,59)
replace agegrp = 5 if dvage>=60 & dvage<=65
label define agegrp_lab 1 "16-29" 2 "30-39" 3 "40-49" 4 "50-59" 5 "60-65"
label values agegrp agegrp_lab

xtile wagegrp = lnw if sample_iv, nq(4)
label define wagegrp_lab 1 "Q1" 2 "Q2" 3 "Q3" 4 "Q4"
label values wagegrp wagegrp_lab

tempname het_mem
tempfile het_results
postfile `het_mem' str8 dimension byte group str8 specification ///
    double fs_b fs_se fs_F iv_b iv_se N using `het_results', replace

foreach dim in agegrp wagegrp {
    levelsof `dim' if sample_iv, local(levels)
    foreach g of local levels {
        foreach spec in core A {
            local z
            if "`spec'" == "core" local z "`z_core'"
            if "`spec'" == "A"    local z "`z_A'"
            if "`z'" == "" {
                display as error "Instrument-set mapping failed for specification `spec'."
                exit 198
            }
            quietly regress `d' `z' `controls' if sample_iv & `dim'==`g', ///
                vce(cluster pidp)
            local fs_b = _b[deathfam]
            local fs_se = _se[deathfam]
            quietly test `z'
            local fs_F = r(F)

            quietly ivregress 2sls `y' `controls' (`d'=`z') ///
                if sample_iv & `dim'==`g', vce(cluster pidp)
            local iv_b = _b[`d']
            local iv_se = _se[`d']
            post `het_mem' ("`dim'") (`g') ("`spec'") ///
                (`fs_b') (`fs_se') (`fs_F') (`iv_b') (`iv_se') (e(N))
            noisily estat firststage
            capture noisily weakiv
        }
    }
}
postclose `het_mem'

preserve
use `het_results', clear
gen iv_lb = iv_b - 1.96*iv_se
gen iv_ub = iv_b + 1.96*iv_se
export delimited using "$outdir/06_heterogeneity_results.csv", replace
save "$outdir/06_heterogeneity_results.dta", replace
restore

*==============================================================================*
* 10. WAGE-GROWTH OUTCOME, IF AVAILABLE
*==============================================================================*

display as text _newline "===== 10. WAGE-GROWTH OUTCOME ====="
capture confirm variable lnw_diff
if !_rc {
    capture drop sample_wage_iv
    gen byte sample_wage_iv = sample_iv & !missing(lnw_diff)
    count if sample_wage_iv
    display as result "Locked wage-growth IV sample N = " r(N)

    foreach spec in core A B full {
        local z
        if "`spec'" == "core" local z "`z_core'"
        if "`spec'" == "A"    local z "`z_A'"
        if "`spec'" == "B"    local z "`z_B'"
        if "`spec'" == "full" local z "`z_full'"
        if "`z'" == "" {
            display as error "Instrument-set mapping failed for specification `spec'."
            exit 198
        }
        display as text _newline "Wage outcome, IV set `spec': `z'"
        ivregress 2sls lnw_diff `controls' (`d'=`z') if sample_wage_iv, ///
            vce(cluster pidp)
        estimates store WAGE_`spec'_2SLS
        estat firststage
        capture noisily weakiv
        if "`spec'"!="core" capture noisily estat overid

        ivregress liml lnw_diff `controls' (`d'=`z') if sample_wage_iv, ///
            vce(cluster pidp)
        estimates store WAGE_`spec'_LIML
        capture noisily weakiv

        ivreg2 lnw_diff `controls' (`d'=`z') if sample_wage_iv, ///
            cluster(pidp) first
    }
}
else {
    display as error "lnw_diff not found; wage-growth IV block not run."
}

*==============================================================================*
* 11. NON-LINEAR GHQ SPECIFICATION - APPENDIX ONLY
*==============================================================================*

display as text _newline "===== 11. QUADRATIC GHQ SPECIFICATION ====="
capture drop ghq2
gen double ghq2 = ghq^2

display as text "The core model cannot identify two endogenous terms with one IV."
display as text "Quadratic specification is estimated only with Expanded A/B."

foreach spec in A B {
    local z
    if "`spec'" == "A" local z "`z_A'"
    if "`spec'" == "B" local z "`z_B'"
    if "`z'" == "" {
        display as error "Instrument-set mapping failed for specification `spec'."
        exit 198
    }
    ivregress 2sls `y' `controls' (`d' ghq2 = `z') if sample_iv, ///
        vce(cluster pidp)
    estimates store QUAD_`spec'_2SLS
    estat firststage
    test ghq2
    capture noisily weakiv

    ivregress liml `y' `controls' (`d' ghq2 = `z') if sample_iv, ///
        vce(cluster pidp)
    estimates store QUAD_`spec'_LIML
    capture noisily weakiv
}

*==============================================================================*
* 12. RESULTS MANIFEST AND FINAL INSTRUCTIONS
*==============================================================================*

display as text _newline "===== 12. RESULTS MANIFEST ====="
display as text "Please send the complete iv_selection_output folder, especially:"
display as text "00_master_IV_selection.log"
display as text "01_common_sample_by_year.csv"
display as text "02_candidate_IV_joint_firststage.csv/.dta/.png"
display as text "03_deathfam_channels_placebos.csv/.dta"
display as text "04_IV_set_estimates.csv/.dta/.png"
display as text "05_single_candidate_IV_results.csv/.dta/.png"
display as text "06_heterogeneity_results.csv/.dta"
display as text "analysis_sample_with_sample_iv.dta (only if file size permits)"

display as result _newline "MASTER IV TEST FILE COMPLETED SUCCESSFULLY."
log close master

********************************************************************************
* END OF FILE
********************************************************************************
