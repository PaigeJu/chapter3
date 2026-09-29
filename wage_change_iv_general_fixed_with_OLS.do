*******************************************************
* Outcome: wage change (preferred: dlnw = lnw_{t+1} - lnw_t)
*******************************************************

cls
clear all
set more off
log using "wage", replace 

*-----------------------------------------------------*
*-----------------------------------------------------*
* Choose outcome scale:
*   local wage_mode "dlnw"   -> change in log wage
*   local wage_mode "dw"     -> change in wage level
local wage_mode "dlnw"

* Candidate IV sets (same as in the job-mobility code)
local z_baseline deathfam
local z_expandA  deathfam vacation familyprob
local z_expandB  deathfam vacation familyprob anniversary
local z_full     deathfam familyprob neighbour friendend ///
                 vacation leisure engage birthday anniversary ///
                 godparent relatives friends

*-----------------------------------------------------*
* 1. Load data and clean GHQ
*-----------------------------------------------------*
use ghqevent, clear
replace ghq = . if ghq < 0

*-----------------------------------------------------*
* 2. Construct wage-change outcome
*-----------------------------------------------------*
* Preferred route: use lead variables if they already exist
capture confirm variable lnw_f
local has_lnw_f = (_rc == 0)
capture confirm variable w_f
local has_w_f = (_rc == 0)

capture drop dlnw dw wage_change

if "`wage_mode'" == "dlnw" {
    if `has_lnw_f' {
        gen double dlnw = lnw_f - lnw if !missing(lnw_f, lnw)
    }
    else {
        * Fallback: generate one-period lead within pidp if year is consecutive
        sort pidp year
        by pidp: gen double lnw_lead = lnw[_n+1] if year[_n+1] == year + 1
        gen double dlnw = lnw_lead - lnw if !missing(lnw_lead, lnw)
        drop lnw_lead
    }
    local y dlnw
    local wage_ctrl lnw
}
else if "`wage_mode'" == "dw" {
    if `has_w_f' {
        gen double dw = w_f - w if !missing(w_f, w)
    }
    else {
        * Fallback: generate one-period lead within pidp if year is consecutive
        sort pidp year
        by pidp: gen double w_lead = w[_n+1] if year[_n+1] == year + 1
        gen double dw = w_lead - w if !missing(w_lead, w)
        drop w_lead
    }
    local y dw
    local wage_ctrl w
}
else {
    di as error "Unknown wage_mode. Use dlnw or dw."
    exit 198
}

label var `y' "Wage change outcome"

di as text "Outcome variable = `y'"
summ `y'

*-----------------------------------------------------*
* 3. Controls
*-----------------------------------------------------*
* For wage-change regressions, it is useful to control for baseline wage level.
local controls `wage_ctrl' dvage age2 male i.year

*-----------------------------------------------------*
* 4. Baseline exact-ID specification
*-----------------------------------------------------*
qui ivregress 2sls `y' `controls' (ghq = `z_baseline'), vce(cluster pidp)
gen byte samp_core = e(sample)

* First stage / relevance
reg ghq deathfam `controls' if samp_core, vce(cluster pidp)
summ ghq if e(sample)
di as text "SD of GHQ in estimation sample = " %9.4f r(sd)
di as text "Effect of deathfam on GHQ = " %9.4f _b[deathfam]
di as text "Standardised effect = " %9.4f (_b[deathfam]/r(sd))

* Reduced form: effect of deathfam on wage change
reg `y' deathfam `controls' if samp_core, vce(cluster pidp)

* 2SLS and diagnostics
ivregress 2sls `y' `controls' (ghq = `z_baseline'), vce(cluster pidp)
estimates store iv_baseline
estat firststage
capture noisily estat endogenous
capture noisily weakivtest
capture noisily weakiv

* LIML robustness
ivregress liml `y' `controls' (ghq = `z_baseline'), vce(cluster pidp)
estimates store liml_baseline
capture noisily weakiv

*-----------------------------------------------------*
* 5. Single-IV screening on a common sample
*-----------------------------------------------------*
use ghqevent, clear
replace ghq = . if ghq < 0

capture drop dlnw dw
capture confirm variable lnw_f
local has_lnw_f = (_rc == 0)
capture confirm variable w_f
local has_w_f = (_rc == 0)

if "`wage_mode'" == "dlnw" {
    if `has_lnw_f' {
        gen double dlnw = lnw_f - lnw if !missing(lnw_f, lnw)
    }
    else {
        sort pidp year
        by pidp: gen double lnw_lead = lnw[_n+1] if year[_n+1] == year + 1
        gen double dlnw = lnw_lead - lnw if !missing(lnw_lead, lnw)
        drop lnw_lead
    }
    local y dlnw
    global X lnw dvage age2 male i.wave
}
else {
    if `has_w_f' {
        gen double dw = w_f - w if !missing(w_f, w)
    }
    else {
        sort pidp year
        by pidp: gen double w_lead = w[_n+1] if year[_n+1] == year + 1
        gen double dw = w_lead - w if !missing(w_lead, w)
        drop w_lead
    }
    local y dw
    global X w dvage age2 male i.wave
}

local zlist deathfam familyprob neighbour friendend ///
            vacation leisure engage birthday anniversary ///
            godparent relatives friends

capture drop sample_all
gen byte sample_all = 1
foreach v in `y' ghq dvage age2 male wave `zlist' {
    replace sample_all = 0 if missing(`v')
}
if "`wage_mode'" == "dlnw" replace sample_all = 0 if missing(lnw)
if "`wage_mode'" == "dw"   replace sample_all = 0 if missing(w)

tab sample_all

capture postutil clear
tempname H2
tempfile fullres

postfile `H2' ///
    str20 iv ///
    b se ll ul p ///
    fs_b fs_se firstF ///
    rf_b rf_se ///
    N ///
    using `fullres', replace

foreach z of local zlist {

    di "----------------------------------------"
    di "Running single-IV model with instrument: `z'"
    di "----------------------------------------"

    quietly ivregress 2sls `y' $X (ghq = `z') if sample_all, vce(cluster pidp)

    matrix T = r(table)
    scalar b  = T[1,1]
    scalar se = T[2,1]
    scalar p  = T[4,1]
    scalar ll = T[5,1]
    scalar ul = T[6,1]
    scalar N  = e(N)

    tempvar esamp
    gen byte `esamp' = e(sample)

    quietly reg ghq `z' $X if `esamp', vce(cluster pidp)
    scalar fs_b  = _b[`z']
    scalar fs_se = _se[`z']
    quietly test `z'
    scalar firstF = r(F)

    quietly reg `y' `z' $X if `esamp', vce(cluster pidp)
    scalar rf_b  = _b[`z']
    scalar rf_se = _se[`z']

    post `H2' ("`z'") (b) (se) (ll) (ul) (p) ///
        (fs_b) (fs_se) (firstF) (rf_b) (rf_se) (N)

    drop `esamp'
}

postclose `H2'
use `fullres', clear
sort b
list iv b ll ul p firstF fs_b rf_b N, noobs clean
save singleiv_results_wagechange, replace

* Simple plot of just-identified IV estimates
sort b
gen order = _n

twoway ///
    (rcap ll ul order if iv != "friends", horizontal) ///
    (scatter order b if iv != "friends", ///
        msymbol(D) mlabel(iv) mlabposition(0) mlabsize(small)), ///
    yscale(reverse) ///
    ylab(none) ///
    xline(0, lpattern(dash)) ///
    xtitle("Single-IV estimate of effect of ghq on `y'") ///
    ytitle("") ///
    title("Per-instrument just-identified IV estimates")

graph export "singleiv_wagechange.png", replace width(2200)

*-----------------------------------------------------*
* 6. Baseline and parsimonious expansions
*-----------------------------------------------------*
use ghqevent, clear
replace ghq = . if ghq < 0

capture drop dlnw dw
capture confirm variable lnw_f
local has_lnw_f = (_rc == 0)
capture confirm variable w_f
local has_w_f = (_rc == 0)

if "`wage_mode'" == "dlnw" {
    if `has_lnw_f' {
        gen double dlnw = lnw_f - lnw if !missing(lnw_f, lnw)
    }
    else {
        sort pidp year
        by pidp: gen double lnw_lead = lnw[_n+1] if year[_n+1] == year + 1
        gen double dlnw = lnw_lead - lnw if !missing(lnw_lead, lnw)
        drop lnw_lead
    }
    local y dlnw
    local controls lnw dvage age2 male i.year
}
else {
    if `has_w_f' {
        gen double dw = w_f - w if !missing(w_f, w)
    }
    else {
        sort pidp year
        by pidp: gen double w_lead = w[_n+1] if year[_n+1] == year + 1
        gen double dw = w_lead - w if !missing(w_lead, w)
        drop w_lead
    }
    local y dw
    local controls w dvage age2 male i.year
}

* Use one common sample for OLS and all three IV specifications.
* Expanded B contains every instrument used in the plotted IV models.
capture drop sample_wage_plot
gen byte sample_wage_plot = !missing(`y', ghq, `wage_ctrl', dvage, age2, ///
    male, year, pidp, deathfam, vacation, familyprob, anniversary)

count if sample_wage_plot
di as result "Common wage-change plot sample N = " r(N)

tempname memhold
tempfile ivplotdata
postfile `memhold' str15 spec double b se lb ub N using `ivplotdata', replace

* OLS on exactly the same sample and with exactly the same controls
regress `y' ghq `controls' if sample_wage_plot, vce(cluster pidp)
local b  = _b[ghq]
local se = _se[ghq]
local lb = `b' - 1.96*`se'
local ub = `b' + 1.96*`se'
local N  = e(N)
post `memhold' ("OLS") (`b') (`se') (`lb') (`ub') (`N')
estimates store A_OLS

* Baseline
ivregress 2sls `y' `controls' (ghq = `z_baseline') ///
    if sample_wage_plot, vce(cluster pidp)
local b  = _b[ghq]
local se = _se[ghq]
local lb = `b' - 1.96*`se'
local ub = `b' + 1.96*`se'
local N  = e(N)
post `memhold' ("Baseline") (`b') (`se') (`lb') (`ub') (`N')
estimates store A_baseline

* Expanded A
ivregress 2sls `y' `controls' (ghq = `z_expandA') ///
    if sample_wage_plot, vce(cluster pidp)
local b  = _b[ghq]
local se = _se[ghq]
local lb = `b' - 1.96*`se'
local ub = `b' + 1.96*`se'
local N  = e(N)
post `memhold' ("Expanded A") (`b') (`se') (`lb') (`ub') (`N')
estimates store A_expandA
capture noisily estat overid

* Expanded B
ivregress 2sls `y' `controls' (ghq = `z_expandB') ///
    if sample_wage_plot, vce(cluster pidp)
local b  = _b[ghq]
local se = _se[ghq]
local lb = `b' - 1.96*`se'
local ub = `b' + 1.96*`se'
local N  = e(N)
post `memhold' ("Expanded B") (`b') (`se') (`lb') (`ub') (`N')
estimates store A_expandB
capture noisily estat overid

postclose `memhold'

use `ivplotdata', clear
gen y_plot = .
replace y_plot = 4 if spec == "OLS"
replace y_plot = 3 if spec == "Baseline"
replace y_plot = 2 if spec == "Expanded A"
replace y_plot = 1 if spec == "Expanded B"
label define spec_lab 1 "Expanded B" 2 "Expanded A" ///
    3 "Baseline IV" 4 "OLS", replace
label values y_plot spec_lab
sort y_plot

gen str20 coef_label = ""
replace coef_label = string(b,"%6.4f") if spec == "OLS"

twoway ///
    (rcap ub lb y_plot, horizontal lwidth(medium) lcolor(forest_green)) ///
    (scatter y_plot b if spec != "OLS", msize(medium) ///
        msymbol(O) mcolor(forest_green)) ///
    (scatter y_plot b if spec == "OLS", msize(medium) ///
        msymbol(D) mcolor(navy) mlabel(coef_label) ///
        mlabposition(3) mlabcolor(navy)), ///
    xline(0, lpattern(dash) lcolor(gs8)) ///
    ylabel(1/4, valuelabel angle(0) noticks) ///
    yscale(range(0.5 4.5)) ///
    xtitle("Coefficient on GHQ") ///
    ytitle("") ///
    title("OLS and IV estimates for wage growth") ///
    subtitle("Point estimates with 95% confidence intervals") ///
    legend(order(2 "2SLS" 3 "OLS") row(1)) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    scheme(s1color)

graph export "figure_wagechange_baseline_expanded.png", replace width(2200)
graph export "figure_wagechange_baseline_expanded.pdf", replace

* Optional comparison table if esttab is installed
capture which esttab
if _rc == 0 {
    esttab A_baseline A_expandA A_expandB using wagechange_parsimonious.tex, replace ///
        keep(ghq) b(%9.4f) se(%9.4f) ///
        mtitles("Baseline" "Expanded A" "Expanded B") ///
        stats(N, fmt(%9.0fc) labels("Observations")) ///
        star(* 0.10 ** 0.05 *** 0.01) label booktabs
}

*-----------------------------------------------------*
* 7. Full candidate set and weak-ID diagnostics
*-----------------------------------------------------*
* Reload the estimation data because the plotting step above replaced the
* dataset in memory with the temporary coefficient-plot file.
use ghqevent, clear
replace ghq = . if ghq < 0

capture drop dlnw dw
capture confirm variable lnw_f
local has_lnw_f = (_rc == 0)
capture confirm variable w_f
local has_w_f = (_rc == 0)

if "`wage_mode'" == "dlnw" {
    if `has_lnw_f' {
        gen double dlnw = lnw_f - lnw if !missing(lnw_f, lnw)
    }
    else {
        sort pidp year
        by pidp: gen double lnw_lead = lnw[_n+1] if year[_n+1] == year + 1
        gen double dlnw = lnw_lead - lnw if !missing(lnw_lead, lnw)
        drop lnw_lead
    }
    local y dlnw
    local controls lnw dvage age2 male i.year
}
else {
    if `has_w_f' {
        gen double dw = w_f - w if !missing(w_f, w)
    }
    else {
        sort pidp year
        by pidp: gen double w_lead = w[_n+1] if year[_n+1] == year + 1
        gen double dw = w_lead - w if !missing(w_lead, w)
        drop w_lead
    }
    local y dw
    local controls w dvage age2 male i.year
}

capture which ivreg2
if _rc == 0 {
    ivreg2 `y' `controls' (ghq = `z_full'), cluster(pidp) first
}
else {
    di as error "ivreg2 is not installed. Run: ssc install ivreg2"
}

*-----------------------------------------------------*
* 8. Notes for adaptation
*-----------------------------------------------------*
* (i) If you want level wages rather than changes, replace the outcome with lnw_f or w_f,
*     and then remove the corresponding contemporaneous wage control from `controls'.
* (ii) If you want individual fixed effects for wage changes, use xtset pidp year and
*      estimate within-person models separately as an additional robustness check.
* (iii) Direct-channel tests should be rewritten for wage-specific outcomes; the newjob-
*       based family/moving outcomes are not a direct template for wage changes.

*******************************************************
log close
*******************************************************
