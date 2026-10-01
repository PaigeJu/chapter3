cls
clear all
set more off



*------------------------------------------------------------------------------------*
*                               core-IV ---- deathfam
*------------------------------------------------------------------------------------*
log using "deathfam_coreIV", replace 

use ghqevent,clear 
replace ghq = . if ghq < 0

*deathfam as the core IV

// my preferred core IV is a bereavement shock from non-partner and non-child family death; it is used as an instrument for psychological distress because it is plausibly relevant for mental health, while I conduct targeted falsification exercises against direct labour-market channels. also, the death happened in (t-1,t) period, the ghq score is the measured mental health at time t, the job movement is observed in (t,t+1) period, so it is less likely the job movement is directly affected by caring pressure change.
tab deathfam

* controls
global X "lnw dvage age2 male i.year"

qui ivregress 2sls newjob $X ///
    (ghq = deathfam), ///
    vce(cluster pidp)

gen samp_core = e(sample)

*individual observed times?
distinct pidp
duplicates report pidp, force 
//1/3 appeared once, 1/3 appeared twice, 1/3 appeared 3 times

*1.1 relevance：deathfam predict ghq or not?
reg ghq deathfam $X if samp_core, vce(cluster pidp)
//treat rows from the same pidp as potentially correlated when computing uncertainty,changes only the standard errors.

sum ghq if e(sample)
//e(sample) is an indicator that equals 1 for observations actually used in that estimation and 0 otherwise.

di "SD of GHQ in estimation sample = " r(sd)
di "Effect of deathfam on GHQ = " _b[deathfam]
di "Standardised effect = " _b[deathfam]/r(sd)

//In the first stage, a non-partner, non-child family death is associated with a 0.574-point increase in GHQ. Given a GHQ standard deviation of 4.955 in the estimation sample, this corresponds to approximately 0.116 standard deviations.


*1.2 reduced form：deathfam predict newjob or not?
reg newjob deathfam $X if samp_core, vce(cluster pidp)

*1.3 check whether deathfam predict some job mobility's direct channels

*1.3.1 number of children in the household comparision between time t and t+1
reg nkids_change deathfam $X if samp_core, vce(cluster pidp)

*1.3.2 hours per week spent caring at time t+1 
reg aidhrs_f deathfam $X if samp_core, vce(cluster pidp)

*1.3.3 Caring prevents paid employment at time t+1
//Question: Thinking about everyone who lives with you that you look after or provide help for - does this extra work looking after [NAME(S)] prevent you from doing a paid job or as much paid work as you might like to do?
reg aideft_f deathfam $X if samp_core, vce(cluster pidp)

*1.3.3 Prefers to move house at time t
//Question: If you could choose, would you stay here in your present home or would you prefer to move somewhere else?
reg lkmove deathfam $X if samp_core, vce(cluster pidp)

*1.3.4 expects to move in next year at time t
//Question: Even though you may not want to move, do you expect you will move in the coming year?
reg xpmove deathfam $X if samp_core, vce(cluster pidp)

*1.3.5 moved for family reasons at time t+1
//Question: if was interviewed at prior wave or has been interviewed previously, And if the HH interviewed at current address previously and respondent is a rejoiner or respondent has not lived at current address continuously since previous interview, or HH interviewed at a different address previously and respondent has not lived at the current address continuously since previous interview, And if moved for family reasons
reg family_f deathfam $X if samp_core, vce(cluster pidp)


* 1.3.6 relationship change 
//marstat_dv is the harmonised facto marital status： 0 "Under 16 years", 1 "Married", 2 "Living as couple", 3 "Widowed", 4 "Divorced", 5 "Separated", and 6 "Never married". -9 "missing"
// br pidp dvage if marstat_dv ==0

count if marstat_dv==-9
count if rls_change==.
tab rls_change,missing  //5% has a relationship change 

probit rls_change deathfam $X if samp_core, vce(cluster pidp)

gen married_couple = (rls_change == 1 & (marstat_dv == 1 | marstat_dv == 2))
probit married_couple deathfam $X if samp_core, vce(cluster pidp)  //negatively correlated, p = 0.02

// effect ?? prob?




gen married = (rls_change == 1 & marstat_dv == 1)
probit married deathfam $X if samp_core, vce(cluster pidp)  //negatively correlated, p = 0.04

gen separated_divorced = (rls_change == 1 & (marstat_dv == 4 | marstat_dv == 5))
probit separated_divorced deathfam $X if samp_core, vce(cluster pidp)  //negatively correlated, p = 0.05

gen divorced = (rls_change == 1 & marstat_dv == 4)
probit divorced deathfam $X if samp_core, vce(cluster pidp)  //negatively correlated, p = 0.28


*exact-ID 2SLS
ivregress 2sls newjob $X  ///
    (ghq = deathfam), ///
    vce(cluster pidp)

estat firststage
estat endogenous

* weak-IV tools
weakivtest
weakiv

*LIML robustness
ivregress liml newjob $X ///
    (ghq = deathfam), ///
    vce(cluster pidp)

weakiv


*------------------------------------------------------------------------------------*
*                 Full single-IV results: coefficient + first stage + reduced form
*------------------------------------------------------------------------------------*
use ghqevent, clear
replace ghq = . if ghq < 0

global X "lnw dvage age2 male i.wave"

local zlist deathfam familyprob neighbour friendend ///
            vacation leisure engage birthday anniversary ///
            godparent relatives friends

* common sample
capture drop sample_all
gen byte sample_all = 1
foreach v in newjob ghq lnw dvage age2 male wave `zlist' {
    replace sample_all = 0 if missing(`v')
}

tab sample_all

* set up postfile
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

* loop over instruments
foreach z of local zlist {

    di "----------------------------------------"
    di "Running single-IV model with instrument: `z'"
    di "----------------------------------------"

    quietly ivregress 2sls newjob $X ///
        (ghq = `z') if sample_all, vce(cluster pidp)

    * directly extract results from r(table)
    matrix T = r(table)
    scalar b  = T[1,1]
    scalar se = T[2,1]
    scalar p  = T[4,1]
    scalar ll = T[5,1]
    scalar ul = T[6,1]
    scalar N  = e(N)

    tempvar esamp
    gen byte `esamp' = e(sample)

    * first stage
    quietly reg ghq `z' $X if `esamp', vce(cluster pidp)
    scalar fs_b  = _b[`z']
    scalar fs_se = _se[`z']
    quietly test `z'
    scalar firstF = r(F)

    * reduced form
    quietly reg newjob `z' $X if `esamp', vce(cluster pidp)
    scalar rf_b  = _b[`z']
    scalar rf_se = _se[`z']

    post `H2' ///
        ("`z'") ///
        (b) (se) (ll) (ul) (p) ///
        (fs_b) (fs_se) (firstF) ///
        (rf_b) (rf_se) ///
        (N)

    drop `esamp'
}

postclose `H2'

use `fullres', clear
sort b
list iv b ll ul p firstF fs_b rf_b N, noobs clean

gen weak10 = (firstF < 10)
gen weak15 = (firstF < 15)
gen str30 ivF = iv + " (F=" + string(firstF, "%4.1f") + ")"
gen id = _n

save singleiv_results_full, replace




*------------------------------------------------------------------------------------*
*                      check whether sensible cluster exist 
*------------------------------------------------------------------------------------*

use singleiv_results_full.dta, clear
list iv b ll ul firstF weak10 weak15 fs_b rf_b N, noobs clean


* all potential IV
twoway ///
    (rcap ll ul id, horizontal) ///
    (scatter id b, msymbol(D) mlabel(iv) mlabposition(0) mlabsize(small)), ///
    yscale(reverse) ///
    ylab(none) ///
    xline(0, lpattern(dash)) ///
    xtitle("Single-IV estimate of effect of ghq on newjob") ///
    ytitle("") ///
    title("Per-instrument just-identified IV estimates")

	
* all potential IV (except for friend)
sort b
gen order = _n

twoway ///
    (rcap ll ul order if iv != "friends", horizontal) ///
    (scatter order b if iv != "friends", ///
        msymbol(D) ///
        mlabel(iv) mlabposition(0) mlabsize(small)), ///
    yscale(reverse) ///
    ylab(none) ///
    xline(0, lpattern(dash)) ///
    xtitle("Single-IV estimate of effect of ghq on newjob") ///
    ytitle("") ///
    title("Per-instrument just-identified IV estimates (excluding friends)")
	
	
* two graph : other IV, friend 	
gen str12 panel = "Other IVs"
replace panel = "friends only" if iv == "friends"

sort panel iv
by panel: gen order_seq = _n

levelsof iv, local(ivlist)
local i = 1
foreach ivname in `ivlist' {
    local ylabel `ylabel' `i' "`ivname'"
    local ++i
}


encode panel, gen(panel_num)  
label define panel_lab 1 "IV with similar scale estimations" 2 "friend"  
label values panel_num panel_lab


twoway ///
    (rcap ll ul order_seq, horizontal) ///
    (scatter order_seq b, msymbol(D)), ///
    by(panel_num, xrescale note("")) ///
    yscale(reverse) ///
    ylabel(none) ///
    xline(0, lpattern(dash)) ///
    xlabel(, labsize(vsmall))                               ///
    xtitle("Single-IV estimate of effect of ghq on newjob") ///
    ytitle("") ///
    title("Per-instrument just-identified IV estimates", size(small)) ///
    legend(label(1 "90% Confidence Interval")               ///
           label(2 "Coefficient estimate")                  ///
           ring(0) position(11) size(small) region(lcolor(none)) )               ///
    graphregion(color(white) fcolor(white) lcolor(white)) plotregion(color(white) fcolor(white) lcolor(white))             ///
	scheme(plain)                                         ///
    name(mygraph, replace)
	

* two graph with weak label: other IV, friend 	
twoway ///
    (rcap ll ul order_seq, horizontal)                                    ///
    (scatter order_seq b if weak10 == 0,                                   ///
        msymbol(D)                                                         ///
        mlabel(ivF) mlabposition(6) mlabsize(vsmall))                     ///
    (scatter order_seq b if weak10 == 1,                                   ///
        msymbol(Oh)                                                        ///
        mlabel(ivF) mlabposition(6) mlabsize(vsmall)),                    ///
    by(panel_num, xrescale note(""))                                       ///
    yscale(reverse)                                                        ///
    ylabel(none)                                                           ///
    xline(0, lpattern(dash))                                               ///
    xlabel(, labsize(vsmall))                                              ///
    xtitle("Single-IV estimate of effect of ghq on newjob")                ///
    ytitle("")                                                             ///
    title("Per-instrument just-identified IV estimates", size(small))      ///
    legend(order(2 "F >= 10" 3 "F < 10")                                   ///
           ring(0) position(11) size(small) region(lcolor(none)))          ///
    graphregion(color(white) lcolor(white) fcolor(white))                  ///
    plotregion(color(white) lcolor(white) fcolor(white))                   ///
    scheme(plain)                                                          ///
    name(mygraph, replace)
	
	

	
* IV with weak label (except for friend 		
twoway ///
    (rcap ll ul order if iv != "friends", horizontal) ///
    (scatter order b if iv != "friends" & weak10 == 0, ///
        msymbol(D) ///
        mlabel(ivF) mlabposition(6) mlabsize(small)) ///
    (scatter order b if iv != "friends" & weak10 == 1, ///
        msymbol(Oh) ///
        mlabel(ivF) mlabposition(6) mlabsize(small)), ///
    yscale(reverse) ///
    ylab(none) ///
    xline(0, lpattern(dash)) ///
    xtitle("Single-IV estimate of effect of ghq on newjob") ///
    ytitle("") ///
    title("Single-IV estimates with first-stage F shown") ///
    legend(order(2 "F >= 10" 3 "F < 10"))
	

//central cluster: deathfam, vacation, familyprob, anniversary, friendend, leisure
log close
	
	
	
*------------------------------------------------------------------------------------*
*              use deathfam as the core-IV, add other IVs, then J-test
*------------------------------------------------------------------------------------*
cls
clear all 
log using "deathfam_coreIV_addingIV", replace 
use ghqevent,clear 
replace ghq = . if ghq < 0

* controls
global X "lnw dvage age2 male i.year"

* baseline 	
ivregress 2sls newjob $X ///
    (ghq = deathfam), ///
    vce(cluster pidp)

estat firststage
weakivtest
weakiv	
	

* add another IV
local addlist vacation familyprob anniversary friendend leisure

foreach z of local addlist {
    di "===================================="
    di "Add instrument: `z'"
    di "===================================="

    ivreg2 newjob $X ///
        (ghq = deathfam `z'), ///
        cluster(pidp) first

}
	
	
	
* add multiple selected IVs	
local combos ///
    "vacation familyprob" ///
    "vacation anniversary" ///
    "familyprob anniversary" ///
    "vacation familyprob anniversary"

foreach s in ///
    `"vacation familyprob"' ///
    `"vacation anniversary"' ///
    `"familyprob anniversary"' ///
    `"vacation familyprob anniversary"' {
    
    di "===================================="
    di `"Added IVs: `s'"'
    di "===================================="

    ivreg2 newjob $X ///
        (ghq = deathfam `s'), ///
        cluster(pidp) first
}


* preferred expanded set 1
ivregress 2sls newjob $X ///
    (ghq = deathfam vacation familyprob), ///
    vce(cluster pidp)

estat firststage
weakiv

ivregress liml newjob $X ///
    (ghq = deathfam vacation familyprob), ///
    vce(cluster pidp)

weakiv

* preferred expanded set 2
ivregress 2sls newjob $X ///
    (ghq = deathfam vacation anniversary), ///
    vce(cluster pidp)

estat firststage
weakiv

ivregress liml newjob $X ///
    (ghq = deathfam vacation anniversary), ///
    vce(cluster pidp)

weakiv


* preferred expanded set 3
ivregress 2sls newjob $X ///
    (ghq = deathfam familyprob anniversary), ///
    vce(cluster pidp)

estat firststage
weakiv

ivregress liml newjob $X ///
    (ghq = deathfam familyprob anniversary), ///
    vce(cluster pidp)

weakiv

* preferred expanded set 4
ivregress 2sls newjob $X ///
    (ghq = deathfam vacation familyprob anniversary), ///
    vce(cluster pidp)

estat firststage
weakiv

ivregress liml newjob $X ///
    (ghq = deathfam vacation familyprob anniversary), ///
    vce(cluster pidp)

weakiv


log close
	

	
*------------------------------------------------------------------------------------*
*              report baseline (deathfam) and expanded IV set 
*------------------------------------------------------------------------------------*
cls
clear all 
log using "deathfam_coreIV_expanded", replace 
use ghqevent,clear 
replace ghq = . if ghq < 0

	
local controls "lnw dvage age2 male i.year"

* baseline
ivregress 2sls newjob `controls' ///
    (ghq = deathfam), ///
    vce(cluster pidp)
estat firststage
weakiv

ivregress liml newjob `controls' ///
    (ghq = deathfam), ///
    vce(cluster pidp)
weakiv

* expanded A
ivregress 2sls newjob `controls' ///
    (ghq = deathfam vacation familyprob), ///
    vce(cluster pidp)
estat firststage
weakiv

ivregress liml newjob `controls' ///
    (ghq = deathfam vacation familyprob), ///
    vce(cluster pidp)
weakiv

* expanded B
ivregress 2sls newjob `controls' ///
    (ghq = deathfam vacation familyprob anniversary), ///
    vce(cluster pidp)
estat firststage
weakiv

ivregress liml newjob `controls' ///
    (ghq = deathfam vacation familyprob anniversary), ///
    vce(cluster pidp)
weakiv
	
*--------------------------------------------------*
* figure: pooled estimates, baseline vs expanded sets
*--------------------------------------------------*
// tempname memhold
// tempfile ivplotdata
//
// postfile `memhold' str15 spec double b se lb ub using `ivplotdata', replace
//
// * baseline
// ivregress 2sls newjob `controls' ///
//     (ghq = deathfam), ///
//     vce(cluster pidp)
// local b  = _b[ghq]
// local se = _se[ghq]
// local lb = `b' - 1.96*`se'
// local ub = `b' + 1.96*`se'
// post `memhold' ("Baseline") (`b') (`se') (`lb') (`ub')
//
// * expanded A
// ivregress 2sls newjob `controls' ///
//     (ghq = deathfam vacation familyprob), ///
//     vce(cluster pidp)
// local b  = _b[ghq]
// local se = _se[ghq]
// local lb = `b' - 1.96*`se'
// local ub = `b' + 1.96*`se'
// post `memhold' ("Expanded A") (`b') (`se') (`lb') (`ub')
//
// * expanded B
// ivregress 2sls newjob `controls' ///
//     (ghq = deathfam vacation familyprob anniversary), ///
//     vce(cluster pidp)
// local b  = _b[ghq]
// local se = _se[ghq]
// local lb = `b' - 1.96*`se'
// local ub = `b' + 1.96*`se'
// post `memhold' ("Expanded B") (`b') (`se') (`lb') (`ub')
//
// postclose `memhold'
//
// use `ivplotdata', clear
//
// gen y = .
// replace y = 3 if spec == "Baseline"
// replace y = 2 if spec == "Expanded A"
// replace y = 1 if spec == "Expanded B"
//
// label define spec_lab 1 "Expanded B" 2 "Expanded A" 3 "Baseline"
// label values y spec_lab
//
// sort y
//
// twoway ///
//     (rcap ub lb y, horizontal lwidth(medium)) ///
//     (scatter y b, msize(medium) msymbol(O)), ///
//     xline(0, lpattern(dash) lcolor(gs8)) ///
//     ylabel(1/3, valuelabel angle(0) noticks) ///
//     yscale(range(0.5 3.5)) ///
//     xtitle("2SLS coefficient on GHQ") ///
//     ytitle("") ///
//     title("Baseline and parsimonious expansions") ///
//     subtitle("Point estimates with 95% confidence intervals") ///
//     legend(off) ///
//     graphregion(color(white)) ///
//     plotregion(color(white)) ///
//     scheme(s1color)
//
// graph export "figure_baseline_expanded_sets.png", replace width(2200)



*--------------------------------------------------*
* Figure: OLS, baseline IV and expanded IV sets
*--------------------------------------------------*

* Lock the common sample used by Expanded B
capture drop sample_plot
gen byte sample_plot = !missing(                         ///
    newjob, ghq, lnw, dvage, age2, male, year, pidp,   ///
    deathfam, vacation, familyprob, anniversary)

tempname memhold
tempfile ivplotdata

postfile `memhold' str15 spec double b se lb ub ///
    using `ivplotdata', replace

* OLS
regress newjob ghq `controls' if sample_plot, ///
    vce(cluster pidp)

local b  = _b[ghq]
local se = _se[ghq]
local lb = `b' - 1.96*`se'
local ub = `b' + 1.96*`se'

post `memhold' ("OLS") (`b') (`se') (`lb') (`ub')

* Baseline IV
ivregress 2sls newjob `controls'                 ///
    (ghq = deathfam) if sample_plot,             ///
    vce(cluster pidp)

local b  = _b[ghq]
local se = _se[ghq]
local lb = `b' - 1.96*`se'
local ub = `b' + 1.96*`se'

post `memhold' ("Baseline") (`b') (`se') (`lb') (`ub')

* Expanded A
ivregress 2sls newjob `controls'                 ///
    (ghq = deathfam vacation familyprob)         ///
    if sample_plot, vce(cluster pidp)

local b  = _b[ghq]
local se = _se[ghq]
local lb = `b' - 1.96*`se'
local ub = `b' + 1.96*`se'

post `memhold' ("Expanded A") (`b') (`se') (`lb') (`ub')

* Expanded B
ivregress 2sls newjob `controls'                 ///
    (ghq = deathfam vacation familyprob anniversary) ///
    if sample_plot, vce(cluster pidp)

local b  = _b[ghq]
local se = _se[ghq]
local lb = `b' - 1.96*`se'
local ub = `b' + 1.96*`se'

post `memhold' ("Expanded B") (`b') (`se') (`lb') (`ub')

postclose `memhold'

preserve
use `ivplotdata', clear

gen byte y = .
replace y = 4 if spec == "OLS"
replace y = 3 if spec == "Baseline"
replace y = 2 if spec == "Expanded A"
replace y = 1 if spec == "Expanded B"

label define spec_lab                       ///
    1 "Expanded B"                         ///
    2 "Expanded A"                         ///
    3 "Baseline IV"                        ///
    4 "OLS"

label values y spec_lab
sort y

twoway                                                  ///
    (rcap ub lb y, horizontal lwidth(medium))           ///
    (scatter y b if spec!="OLS",                        ///
        msize(medium) msymbol(O) mcolor(forest_green))  ///
    (scatter y b if spec=="OLS",                        ///
        msize(medium) msymbol(D) mcolor(navy)),         ///
    xline(0, lpattern(dash) lcolor(gs8))                ///
    ylabel(1/4, valuelabel angle(0) noticks)            ///
    yscale(range(0.5 4.5))                              ///
    xtitle("Coefficient on GHQ")                        ///
    ytitle("")                                          ///
    title("OLS and life-event IV estimates")            ///
    subtitle("Point estimates with 95% confidence intervals") ///
    legend(order(2 "2SLS" 3 "OLS") row(1))             ///
    graphregion(color(white))                           ///
    plotregion(color(white))                            ///
    scheme(s1color)

graph export "estimate_bs_exp.pdf", replace
graph export "estimate_bs_exp.png", replace width(2200)

restore


log close


//I treated deathfam as the baseline core IV and then asked which extra instruments can be added without creating overidentification tension.
//vacation, familyprob, and anniversary survive that screen, while friendend is borderline and leisure is rejected.
//The combined specifications remain negatively signed, become more precise, and do not trigger Hansen J rejection.
//So the paper still looks like Path A rather than Path B: a defensible core-IV design with a small expanded set that appears tolerable.



*------------------------------------------------------------------------------------*
* split sample based on age (baseline as deathfam and expanded IV set)
*------------------------------------------------------------------------------------*
cls
clear all 
// log using "deathfam_coreIV_splitsample", replace 

****************************************************
* Two comparison figures
* Figure 1: baseline pooled vs baseline by age group
* Figure 2: by age group, baseline vs expanded A
****************************************************

use ghqevent, clear
replace ghq = . if ghq < 0

*--------------------------------------------------*
* controls
*--------------------------------------------------*
local controls "lnw dvage age2 male i.year"

*--------------------------------------------------*
* create age groups
*--------------------------------------------------*
gen agegrp = .
replace agegrp = 1 if inrange(dvage,16,29)
replace agegrp = 2 if inrange(dvage,30,39)
replace agegrp = 3 if inrange(dvage,40,49)
replace agegrp = 4 if inrange(dvage,50,59)
replace agegrp = 5 if dvage >= 60 & dvage < .

label define agegrp_lab ///
    1 "16-29" ///
    2 "30-39" ///
    3 "40-49" ///
    4 "50-59" ///
    5 "60+", replace
label values agegrp agegrp_lab

tab agegrp

*--------------------------------------------------*
* store results
* spec = Baseline / Expanded A
* agegrp = 0 means pooled full-sample estimate
*--------------------------------------------------*
tempfile iv_results
tempname memhold

postfile `memhold' ///
    str12 spec ///
    int agegrp ///
    double b se lb ub N ///
    using `iv_results', replace

*==================================================*
* A. BASELINE pooled (full sample)
*==================================================*
di " "
di "===================================================="
di "Baseline pooled full-sample estimate"
di "IV set: deathfam"
di "===================================================="

capture noisily ivregress 2sls newjob `controls' ///
    (ghq = deathfam), ///
    vce(cluster pidp)

if _rc == 0 {
    local b  = _b[ghq]
    local se = _se[ghq]
    local lb = `b' - 1.96*`se'
    local ub = `b' + 1.96*`se'
    local N  = e(N)

    post `memhold' ("Baseline") (0) (`b') (`se') (`lb') (`ub') (`N')

    capture noisily estat firststage
    capture noisily weakiv
}
else {
    di as error "Baseline pooled model failed (rc = " _rc ")."
    post `memhold' ("Baseline") (0) (.) (.) (.) (.) (.)
}

*==================================================*
* B. BASELINE by age group
*==================================================*
forvalues g = 1/5 {

    local glab : label agegrp_lab `g'

    di " "
    di "===================================================="
    di "Baseline | Age group: `glab'"
    di "IV set: deathfam"
    di "===================================================="

    capture noisily ivregress 2sls newjob `controls' ///
        (ghq = deathfam) ///
        if agegrp == `g', vce(cluster pidp)

    if _rc == 0 {
        local b  = _b[ghq]
        local se = _se[ghq]
        local lb = `b' - 1.96*`se'
        local ub = `b' + 1.96*`se'
        local N  = e(N)

        post `memhold' ("Baseline") (`g') (`b') (`se') (`lb') (`ub') (`N')

        capture noisily estat firststage
        capture noisily weakiv
    }
    else {
        di as error "Baseline failed in age group `glab' (rc = " _rc ")."
        post `memhold' ("Baseline") (`g') (.) (.) (.) (.) (.)
    }
}

*==================================================*
* C. EXPANDED A by age group
*==================================================*
forvalues g = 1/5 {

    local glab : label agegrp_lab `g'

    di " "
    di "===================================================="
    di "Expanded A | Age group: `glab'"
    di "IV set: deathfam vacation familyprob"
    di "===================================================="

    capture noisily ivregress 2sls newjob `controls' ///
        (ghq = deathfam vacation familyprob) ///
        if agegrp == `g', vce(cluster pidp)

    if _rc == 0 {
        local b  = _b[ghq]
        local se = _se[ghq]
        local lb = `b' - 1.96*`se'
        local ub = `b' + 1.96*`se'
        local N  = e(N)

        post `memhold' ("Expanded A") (`g') (`b') (`se') (`lb') (`ub') (`N')

        capture noisily estat firststage
        capture noisily weakiv
    }
    else {
        di as error "Expanded A failed in age group `glab' (rc = " _rc ")."
        post `memhold' ("Expanded A") (`g') (.) (.) (.) (.) (.)
    }
}

postclose `memhold'

*--------------------------------------------------*
* load and save results
*--------------------------------------------------*
use `iv_results', clear
label values agegrp agegrp_lab
sort spec agegrp

list, sepby(spec)

save "iv_age_two_figures_results.dta", replace

*==================================================*
* FIGURE 1
* Baseline pooled vs baseline by age group
* Here pooled estimate is repeated as comparison benchmark
*==================================================*
preserve
keep if spec == "Baseline"

quietly summarize b if agegrp == 0, meanonly
local pool_b = r(mean)

quietly summarize lb if agegrp == 0, meanonly
local pool_lb = r(mean)

quietly summarize ub if agegrp == 0, meanonly
local pool_ub = r(mean)

keep if agegrp >= 1

gen b_pool  = `pool_b'
gen lb_pool = `pool_lb'
gen ub_pool = `pool_ub'

gen y_sub  = agegrp - 0.10
gen y_pool = agegrp + 0.10

twoway ///
    (rcap ub lb y_sub if b<., horizontal lwidth(medium)) ///
    (scatter y_sub b if b<., msize(medium) msymbol(O)) ///
    (rcap ub_pool lb_pool y_pool if b_pool<., horizontal lwidth(medium) lpattern(dash)) ///
    (scatter y_pool b_pool if b_pool<., msize(medium) msymbol(Dh)), ///
    ylabel(1 "16-29" 2 "30-39" 3 "40-49" 4 "50-59" 5 "60+") ///
    xline(0, lpattern(dash)) ///
    ytitle("Age group") ///
    xtitle("2SLS coefficient on GHQ") ///
    title("Baseline model: pooled vs age-group estimates") ///
    legend(order(2 "Age-group estimate" 4 "Pooled estimate") row(1)) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    name(g_fig1, replace)

graph export "figure1_baseline_pooled_vs_agegroups.png", replace width(2200)
restore

*==================================================*
* FIGURE 2
* By age group: Baseline vs Expanded A
*==================================================*
preserve
keep if agegrp >= 1

gen y_plot = .
replace y_plot = agegrp - 0.10 if spec == "Baseline"
replace y_plot = agegrp + 0.10 if spec == "Expanded A"

twoway ///
    (rcap ub lb y_plot if spec=="Baseline" & b<., horizontal lwidth(medium)) ///
    (scatter y_plot b if spec=="Baseline" & b<., msize(medium) msymbol(O)) ///
    (rcap ub lb y_plot if spec=="Expanded A" & b<., horizontal lwidth(medium) lpattern(dash)) ///
    (scatter y_plot b if spec=="Expanded A" & b<., msize(medium) msymbol(Dh)), ///
    ylabel(1 "16-29" 2 "30-39" 3 "40-49" 4 "50-59" 5 "60+") ///
    xline(0, lpattern(dash)) ///
    ytitle("Age group") ///
    xtitle("2SLS coefficient on GHQ") ///
    title("By age group: Baseline vs Expanded A") ///
    legend(order(2 "Baseline" 4 "Expanded A") row(1)) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    name(g_fig2, replace)

graph export "figure2_baseline_vs_expandedA_by_age.png", replace width(2200)
restore

//log close

	


*------------------------------------------------------------------------------------*
* split sample based on wage (baseline as deathfam and expanded IV set)
*------------------------------------------------------------------------------------*
*------------------------------------------------------------------------------------*
* split sample based on wage quartiles
* Figure 1: baseline pooled vs baseline by wage group
* Figure 2: by wage group, baseline vs expanded A
*------------------------------------------------------------------------------------*
cls
clear all
//log using "deathfam_coreIV_splitwage", replace

use ghqevent, clear
replace ghq = . if ghq < 0

*--------------------------------------------------*
* controls
* keep the same as your baseline specification
*--------------------------------------------------*
local controls "lnw dvage age2 male i.year"

*--------------------------------------------------*
* create wage groups
* recommended: use raw wage w
* if you prefer lnw, replace w with lnw below
*--------------------------------------------------*
gen wage_ok = (w > 0 & w < .)

* quartiles of wage
xtile wagegrp = w if wage_ok, nq(4)

label define wagegrp_lab ///
    1 "Q1 lowest wage" ///
    2 "Q2" ///
    3 "Q3" ///
    4 "Q4 highest wage", replace
label values wagegrp wagegrp_lab

tab wagegrp if wage_ok

*--------------------------------------------------*
* store results
* spec = Baseline / Expanded A
* wagegrp = 0 means pooled full-sample estimate
*--------------------------------------------------*
tempfile iv_results
tempname memhold

postfile `memhold' ///
    str12 spec ///
    int wagegrp ///
    double b se lb ub N ///
    using `iv_results', replace

*==================================================*
* A. BASELINE pooled (full sample)
*==================================================*
di " "
di "===================================================="
di "Baseline pooled full-sample estimate"
di "IV set: deathfam"
di "===================================================="

capture noisily ivregress 2sls newjob `controls' ///
    (ghq = deathfam) ///
    if wage_ok, vce(cluster pidp)

if _rc == 0 {
    local b  = _b[ghq]
    local se = _se[ghq]
    local lb = `b' - 1.96*`se'
    local ub = `b' + 1.96*`se'
    local N  = e(N)

    post `memhold' ("Baseline") (0) (`b') (`se') (`lb') (`ub') (`N')

    capture noisily estat firststage
    capture noisily weakiv
}
else {
    di as error "Baseline pooled model failed (rc = " _rc ")."
    post `memhold' ("Baseline") (0) (.) (.) (.) (.) (.)
}

*==================================================*
* B. BASELINE by wage group
*==================================================*
forvalues g = 1/4 {

    local glab : label wagegrp_lab `g'

    di " "
    di "===================================================="
    di "Baseline | Wage group: `glab'"
    di "IV set: deathfam"
    di "===================================================="

    capture noisily ivregress 2sls newjob `controls' ///
        (ghq = deathfam) ///
        if wagegrp == `g', vce(cluster pidp)

    if _rc == 0 {
        local b  = _b[ghq]
        local se = _se[ghq]
        local lb = `b' - 1.96*`se'
        local ub = `b' + 1.96*`se'
        local N  = e(N)

        post `memhold' ("Baseline") (`g') (`b') (`se') (`lb') (`ub') (`N')

        capture noisily estat firststage
        capture noisily weakiv
    }
    else {
        di as error "Baseline failed in wage group `glab' (rc = " _rc ")."
        post `memhold' ("Baseline") (`g') (.) (.) (.) (.) (.)
    }
}

*==================================================*
* C. EXPANDED A by wage group
*==================================================*
forvalues g = 1/4 {

    local glab : label wagegrp_lab `g'

    di " "
    di "===================================================="
    di "Expanded A | Wage group: `glab'"
    di "IV set: deathfam vacation familyprob"
    di "===================================================="

    capture noisily ivregress 2sls newjob `controls' ///
        (ghq = deathfam vacation familyprob) ///
        if wagegrp == `g', vce(cluster pidp)

    if _rc == 0 {
        local b  = _b[ghq]
        local se = _se[ghq]
        local lb = `b' - 1.96*`se'
        local ub = `b' + 1.96*`se'
        local N  = e(N)

        post `memhold' ("Expanded A") (`g') (`b') (`se') (`lb') (`ub') (`N')

        capture noisily estat firststage
        capture noisily weakiv
    }
    else {
        di as error "Expanded A failed in wage group `glab' (rc = " _rc ")."
        post `memhold' ("Expanded A") (`g') (.) (.) (.) (.) (.)
    }
}

postclose `memhold'

*--------------------------------------------------*
* load and save results
*--------------------------------------------------*
use `iv_results', clear
label values wagegrp wagegrp_lab
sort spec wagegrp

list, sepby(spec)

save "iv_wage_two_figures_results.dta", replace

*==================================================*
* FIGURE 1
* Baseline pooled vs baseline by wage group
* pooled estimate repeated as benchmark
*==================================================*
preserve
keep if spec == "Baseline"

quietly summarize b if wagegrp == 0, meanonly
local pool_b = r(mean)

quietly summarize lb if wagegrp == 0, meanonly
local pool_lb = r(mean)

quietly summarize ub if wagegrp == 0, meanonly
local pool_ub = r(mean)

keep if wagegrp >= 1

gen b_pool  = `pool_b'
gen lb_pool = `pool_lb'
gen ub_pool = `pool_ub'

gen y_sub  = wagegrp - 0.10
gen y_pool = wagegrp + 0.10

twoway ///
    (rcap ub lb y_sub if b<., horizontal lwidth(medium)) ///
    (scatter y_sub b if b<., msize(medium) msymbol(O)) ///
    (rcap ub_pool lb_pool y_pool if b_pool<., horizontal lwidth(medium) lpattern(dash)) ///
    (scatter y_pool b_pool if b_pool<., msize(medium) msymbol(Dh)), ///
    ylabel(1 "Q1 lowest wage" 2 "Q2" 3 "Q3" 4 "Q4 highest wage") ///
    xline(0, lpattern(dash)) ///
    ytitle("Wage group") ///
    xtitle("2SLS coefficient on GHQ") ///
    title("Baseline model: pooled vs wage-group estimates") ///
    legend(order(2 "Wage-group estimate" 4 "Pooled estimate") row(1)) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    name(g_fig1, replace)

graph export "figure1_baseline_pooled_vs_wagegroups.png", replace width(2200)
restore

*==================================================*
* FIGURE 2
* By wage group: Baseline vs Expanded A
*==================================================*
preserve
keep if wagegrp >= 1

gen y_plot = .
replace y_plot = wagegrp - 0.10 if spec == "Baseline"
replace y_plot = wagegrp + 0.10 if spec == "Expanded A"

twoway ///
    (rcap ub lb y_plot if spec=="Baseline" & b<., horizontal lwidth(medium)) ///
    (scatter y_plot b if spec=="Baseline" & b<., msize(medium) msymbol(O)) ///
    (rcap ub lb y_plot if spec=="Expanded A" & b<., horizontal lwidth(medium) lpattern(dash)) ///
    (scatter y_plot b if spec=="Expanded A" & b<., msize(medium) msymbol(Dh)), ///
    ylabel(1 "Q1 lowest wage" 2 "Q2" 3 "Q3" 4 "Q4 highest wage") ///
    xline(0, lpattern(dash)) ///
    ytitle("Wage group") ///
    xtitle("2SLS coefficient on GHQ") ///
    title("By wage group: Baseline vs Expanded A") ///
    legend(order(2 "Baseline" 4 "Expanded A") row(1)) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    name(g_fig2, replace)

graph export "figure2_baseline_vs_expandedA_by_wage.png", replace width(2200)
restore

//log close









	
// log close




















































*------------------------------------------------------------------------------------*
*              non-linear effect: report baseline (deathfam) and expanded IV set 
*------------------------------------------------------------------------------------*
cls
clear all 
// log using "deathfam_coreIV_expanded_ghq2", replace 

****************************************************
* Linear and quadratic IV specifications for GHQ
****************************************************

use ghqevent, clear
replace ghq = . if ghq < 0

local controls "lnw dvage age2 male i.year"

*--------------------------------------------------*
* 0. Generate quadratic term
*--------------------------------------------------*
gen ghq2 = ghq^2
label var ghq2 "GHQ squared"

*==================================================*
* 1. LINEAR MODELS
*==================================================*

*-----------------------------*
* baseline: linear 2SLS
*-----------------------------*
di "===================================================="
di "Baseline linear 2SLS"
di "===================================================="

ivregress 2sls newjob `controls' ///
    (ghq = deathfam), ///
    vce(cluster pidp)

estat firststage
capture noisily weakiv

*-----------------------------*
* baseline: linear LIML
*-----------------------------*
di "===================================================="
di "Baseline linear LIML"
di "===================================================="

ivregress liml newjob `controls' ///
    (ghq = deathfam), ///
    vce(cluster pidp)

capture noisily weakiv

*-----------------------------*
* expanded A: linear 2SLS
*-----------------------------*
di "===================================================="
di "Expanded A linear 2SLS"
di "===================================================="

ivregress 2sls newjob `controls' ///
    (ghq = deathfam vacation familyprob), ///
    vce(cluster pidp)

estat firststage
capture noisily weakiv

*-----------------------------*
* expanded A: linear LIML
*-----------------------------*
di "===================================================="
di "Expanded A linear LIML"
di "===================================================="

ivregress liml newjob `controls' ///
    (ghq = deathfam vacation familyprob), ///
    vce(cluster pidp)

capture noisily weakiv


*==================================================*
* 2. QUADRATIC IV MODELS
*==================================================*

*--------------------------------------------------*
* baseline quadratic IV: NOT identified
*--------------------------------------------------*
di as error "===================================================="
di as error "Baseline quadratic IV is underidentified"
di as error "have 2 endogenous regressors (ghq and ghq2)"
di as error "but only 1 excluded IV (deathfam)."
di as error "So do NOT estimate: (ghq ghq2 = deathfam)"
di as error "===================================================="


*==================================================*
* 3. EXPANDED A: quadratic IV
*==================================================*

*-----------------------------*
* expanded A: quadratic 2SLS
*-----------------------------*
di "===================================================="
di "Expanded A quadratic 2SLS"
di "===================================================="

ivregress 2sls newjob `controls' ///
    (ghq ghq2 = deathfam vacation familyprob), ///
    vce(cluster pidp)

estat firststage

* does the quadratic term matter?
test ghq2 = 0

* marginal effect at selected GHQ values
di "Marginal effect of GHQ on newjob at selected GHQ values:"
lincom _b[ghq] + 2*0*_b[ghq2]
lincom _b[ghq] + 2*12*_b[ghq2]
lincom _b[ghq] + 2*24*_b[ghq2]
lincom _b[ghq] + 2*36*_b[ghq2]

* turning point
capture noisily nlcom turning_point: -_b[ghq]/(2*_b[ghq2])

* weak-IV robust tests LAST
capture noisily weakiv

*-----------------------------*
* expanded A: quadratic LIML
*-----------------------------*
di "===================================================="
di "Expanded A quadratic LIML"
di "===================================================="

ivregress liml newjob `controls' ///
    (ghq ghq2 = deathfam vacation familyprob), ///
    vce(cluster pidp)

* LIML does not support estat firststage in the same way as 2SLS;
* if needed, rely on the 2SLS first-stage output above

test ghq2 = 0

di "Marginal effect of GHQ on newjob at selected GHQ values:"
lincom _b[ghq] + 2*0*_b[ghq2]
lincom _b[ghq] + 2*12*_b[ghq2]
lincom _b[ghq] + 2*24*_b[ghq2]
lincom _b[ghq] + 2*36*_b[ghq2]

capture noisily nlcom turning_point: -_b[ghq]/(2*_b[ghq2])

capture noisily weakiv


	
	
// log close















































exit 

* example: if you decide vacation + familyprob survives
ivregress 2sls newjob $X ///
    (ghq = deathfam vacation familyprob), ///
    vce(cluster pidp)
weakiv

ivregress liml newjob $X ///
    (ghq = deathfam vacation familyprob), ///
    vce(cluster pidp)
weakiv

	
	
	
//deathfam is our preferred core-IV candidate; it passes relevance and weak-IV diagnostics, and does not show strong evidence of several targeted direct channels.


*adding more IV
foreach z in familyprob neighbour friendend vacation leisure engage birthday anniversary godparent relatives friends {
    di "========== adding `z' =========="
    
    ivregress 2sls newjob $X ///
        (ghq = deathfam `z'), ///
        vce(cluster pidp)

    estat overid
}




/*
*check for underidentification, weak iv, 12 iv are all valid?
log using "underid.log", replace

ivregress 2sls newjob lnw dvage age2 male ///
    (ghq = deathfam familyprob neighbour friendend ///
           vacation leisure engage birthday anniversary godparent relatives friends), ///
    vce(cluster pidp) first	
	
estat firststage



ivreg2 newjob lnw dvage age2 male ///
    (ghq = deathfam familyprob neighbour friendend ///
           vacation leisure engage birthday anniversary godparent relatives friends), ///
    cluster(pidp) first

//The candidate life-event instruments are not underidentified: the cluster-robust Kleibergen–Paap rk LM statistic strongly rejects the null of underidentification. The first stage is not especially weak, although the partial R^2 remains small and the cluster-robust KP rk Wald F should be interpreted cautiously. However, the Hansen J test strongly rejects the joint validity of the full instrument set, implying that at least some of the candidate life events violate the exclusion restriction. Therefore, the key empirical task is no longer to establish basic identification, but to recover a valid subset of instruments from the larger candidate set.	
	

log close




*-----------------------------------------------------*
* Step 1: Build an individual first-stage screening table
*-----------------------------------------------------*
//Given that the full candidate set is not underidentified but the Hansen test rejects the joint validity of all life-event instruments, the empirical strategy proceeds in two steps. First, a light first-stage screening is applied to remove instruments with negligible predictive content for GHQ, thereby stabilising the instrument-specific ratio estimates used in valid-IV selection. Second, the CI method is implemented on the retained candidate set, selecting the largest group of instruments with overlapping confidence intervals, with model choice refined by a downward testing procedure based on the Hansen J test.

local y newjob
local d ghq
local x lnw dvage age2 male
local z deathfam familyprob neighbour friendend ///
        vacation leisure engage birthday anniversary godparent relatives friends

tempname memhold
tempfile firststage_table

postfile `memhold' str20 ivname double b se t p using `firststage_table', replace

foreach v of local z {
    quietly regress `d' `x' `v', vce(cluster pidp)
    local b  = _b[`v']
    local se = _se[`v']
    local t  = _b[`v'] / _se[`v']
    local p  = 2*ttail(e(df_r), abs(`t'))

    post `memhold' ("`v'") (`b') (`se') (`t') (`p')
}

postclose `memhold'

use `firststage_table', clear
gsort p
list, clean noobs


*Baseline screen
gen byte keep_base = (abs(t) >= 1 | p <= 0.30)
list ivname t p keep_base, clean noobs

*Stricter screen
gen byte keep_strict = (abs(t) >= 1.64)
list ivname t p keep_strict, clean noobs

*/



*******************************************************
* CI method with weak-IV pre-screen and valid-subset selection
* Main use: choose one of z_full, z_base, z_core as z_use
* Outcome: newjob
* Endogenous regressor: ghq
* Exogenous controls: lnw dvage age2 male
* Cluster level: pidp
*******************************************************
clear all 

use ghqevent,clear 

log using "ci.log", replace

*******************************************************
* CI method with weak-IV pre-screen and valid-subset selection
* Corrected version
*
* Main use:
*   local z_use `z_base'
*   or
*   local z_use `z_core'
*   or
*   local z_use `z_full'
*******************************************************

set more off

*-----------------------------------------------------*
* 0. Optional package installation
*-----------------------------------------------------*
* ssc install ivreg2, replace
* ssc install ranktest, replace

*-----------------------------------------------------*
* 1. Define variable lists
*-----------------------------------------------------*
local y newjob
local d ghq
local x lnw dvage age2 male

local z_full deathfam familyprob neighbour friendend ///
             vacation leisure engage birthday anniversary godparent relatives friends

local z_base familyprob vacation deathfam friendend ///
             leisure anniversary engage neighbour relatives birthday

local z_core familyprob vacation deathfam friendend ///
             leisure anniversary engage neighbour relatives

*-----------------------------------------------------*
* 2. Choose the candidate set for CI selection
*-----------------------------------------------------*
local z_use `z_base'

*-----------------------------------------------------*
* 3. Clean old variables
*-----------------------------------------------------*
capture drop touse y_r d_r
foreach v of local z_full {
    capture drop `v'_r
}

*-----------------------------------------------------*
* 4. Define a common estimation sample using z_full
*-----------------------------------------------------*
quietly ivregress 2sls `y' `x' (`d' = `z_full')
gen byte touse = e(sample)

count if touse
display as text "Common estimation sample size = " as result r(N)

if r(N) == 0 {
    display as error "No observations in the common estimation sample."
    exit 2000
}

scalar pthr = 0.1 / log(r(N))
display as text "Downward-testing p-value threshold = " ///
    as result %10.6f scalar(pthr)

preserve
keep if touse

*-----------------------------------------------------*
* 5. Partial out exogenous controls from y, d, and z_use
*-----------------------------------------------------*
quietly regress `y' `x'
predict double y_r, resid

quietly regress `d' `x'
predict double d_r, resid

local z_r
foreach v of local z_use {
    quietly regress `v' `x'
    predict double `v'_r, resid
    local z_r `z_r' `v'_r
}

*-----------------------------------------------------*
* 6. Save the working sample before switching datasets
*-----------------------------------------------------*
tempfile worksample
save `worksample', replace

*-----------------------------------------------------*
* 7. Compute instrument-specific just-identified IV estimates
*    IMPORTANT: keep the original z_use order, do not sort
*-----------------------------------------------------*
tempname memhold1
tempfile ci_input

postfile `memhold1' str20 ivname double bhat sehat using `ci_input', replace

foreach zj of local z_r {
    local others : list z_r - zj
    quietly ivreg2 y_r `others' (d_r = `zj'), cluster(pidp)
    post `memhold1' ("`zj'") (_b[d_r]) (_se[d_r])
}

postclose `memhold1'

use `ci_input', clear
gen ivname_clean = subinstr(ivname, "_r", "", .)

display as text "Instrument-specific estimates in original z_use order:"
list ivname_clean bhat sehat, clean noobs

mkmat bhat sehat, matrix(ci_est)
matrix rownames ci_est = `z_use'
matrix colnames ci_est = bhat sehat

*-----------------------------------------------------*
* 8. Mata helper functions
*-----------------------------------------------------*
mata:

real colvector mask_to_idx(real scalar mask, real scalar k)
{
    real colvector idx
    real scalar j

    idx = J(0,1,.)
    for (j=1; j<=k; j++) {
        if (mod(floor(mask / (2^(j-1))), 2) == 1) {
            idx = idx \ j
        }
    }
    return(idx)
}

real colvector unique_sorted(real colvector x)
{
    real colvector xs, out
    real scalar i

    if (rows(x)==0) return(x)

    xs  = sort(x,1)
    out = xs[1]

    for (i=2; i<=rows(xs); i++) {
        if (abs(xs[i] - out[rows(out)]) > 1e-10) {
            out = out \ xs[i]
        }
    }
    return(out)
}

real matrix unique_by_mask(real matrix A)
{
    real matrix S, out
    real colvector ord
    real scalar i

    if (rows(A)==0) return(A)

    ord = order(A[,2], 1)
    S   = A[ord,.]
    out = S[1,.]

    for (i=2; i<=rows(S); i++) {
        if (S[i,2] != out[rows(out),2]) {
            out = out \ S[i,.]
        }
    }

    return(out)
}

real matrix collect_candidate_groups(real colvector b, real colvector se, real colvector psi_vals)
{
    real scalar k, mask, nmask, i, s, bestsize
    real colvector idx, lo, hi
    real matrix allcand, tmp

    k = rows(b)
    nmask = 2^k - 1
    allcand = J(0,3,.)

    for (i=1; i<=rows(psi_vals); i++) {
        bestsize = 0
        tmp = J(0,3,.)

        for (mask=1; mask<=nmask; mask++) {
            idx = mask_to_idx(mask, k)
            s   = rows(idx)

            lo = b[idx] :- psi_vals[i] :* se[idx]
            hi = b[idx] :+ psi_vals[i] :* se[idx]

            if (max(lo) < min(hi)) {
                if (s > bestsize) {
                    bestsize = s
                    tmp = J(0,3,.)
                }
                if (s == bestsize) {
                    tmp = tmp \ (psi_vals[i], mask, s)
                }
            }
        }

        if (rows(tmp) > 0) {
            allcand = allcand \ tmp
        }
    }

    return(unique_by_mask(allcand))
}

end

*-----------------------------------------------------*
* 9. Build CI candidate groups using breakpoints
*-----------------------------------------------------*
mata:

E  = st_matrix("ci_est")
b  = E[,1]
se = E[,2]
k  = rows(b)

bp = J(0,1,.)
for (j=1; j<=k-1; j++) {
    for (r=j+1; r<=k; r++) {
        bp = bp \ (abs(b[j] - b[r]) / (se[j] + se[r]))
    }
}
bp = unique_sorted(bp)

if (rows(bp) > 0) {
    psi_vals = J(rows(bp)+1,1,.)
    psi_vals[1] = max(bp) + 1
    for (i=1; i<=rows(bp); i++) {
        psi_vals[i+1] = bp[rows(bp)-i+1]
    }
}
else {
    psi_vals = 1
}

cand = collect_candidate_groups(b, se, psi_vals)
st_matrix("ci_candidates", cand)

end

matrix colnames ci_candidates = psi mask nvalid

display as text "Candidate CI groups:"
matrix list ci_candidates

*-----------------------------------------------------*
* 10. Restore the working sample before evaluating candidates
*-----------------------------------------------------*
use `worksample', clear

*-----------------------------------------------------*
* 11. Evaluate each candidate group using clustered post-selection 2SLS
*-----------------------------------------------------*
tempname memhold2
tempfile candidate_eval

postfile `memhold2' double psi mask nvalid J Jp beta using `candidate_eval', replace

scalar ncand = rowsof(ci_candidates)

forvalues r = 1/`=scalar(ncand)' {

    local valid
    local invalid

    scalar mask_now = el(ci_candidates, `r', 2)
    scalar psi_now  = el(ci_candidates, `r', 1)
    scalar nval_now = el(ci_candidates, `r', 3)

    local j = 1
    foreach v of local z_use {
        scalar bit = mod(floor(mask_now / (2^(`j'-1))), 2)

        if scalar(bit) == 1 {
            local valid `valid' `v'
        }
        else {
            local invalid `invalid' `v'
        }

        local ++j
    }

    local nvalid : word count `valid'

    if "`invalid'" == "" {
        quietly ivreg2 `y' `x' (`d' = `valid'), cluster(pidp)
    }
    else {
        quietly ivreg2 `y' `x' `invalid' (`d' = `valid'), cluster(pidp)
    }

    local beta = _b[`d']
    local J  = .
    local Jp = .

    if `nvalid' > 1 {
        capture local J  = e(j)
        capture local Jp = e(jp)
    }

    post `memhold2' (scalar(psi_now)) (scalar(mask_now)) (`nvalid') ///
        (`J') (`Jp') (`beta')
}

postclose `memhold2'

use `candidate_eval', clear
gsort -nvalid -Jp
display as text "Candidate evaluation table:"
list, clean noobs

*-----------------------------------------------------*
* 12. Downward testing:
*     choose the largest valid set with Hansen J p-value > pthr
*-----------------------------------------------------*
gen byte pass = (nvalid >= 2 & Jp > scalar(pthr))

count if pass == 1

if r(N) > 0 {
    gsort -pass -nvalid -Jp
    keep if pass == 1
    keep in 1
}
else {
    display as error "No overidentified candidate passes the Hansen threshold."
    display as error "Fallback: choosing the candidate with the largest nvalid and highest Hansen p-value."
    gsort -nvalid -Jp
    keep in 1
}

scalar final_mask = mask[1]
scalar final_psi  = psi[1]
scalar final_nval = nvalid[1]
scalar final_J    = J[1]
scalar final_Jp   = Jp[1]
scalar final_beta = beta[1]

display as text "Final selected psi        = " as result %10.6f scalar(final_psi)
display as text "Final selected mask       = " as result %10.0f scalar(final_mask)
display as text "Final number of valid IVs = " as result %10.0f scalar(final_nval)
display as text "Final Hansen J statistic  = " as result %10.6f scalar(final_J)
display as text "Final Hansen J p-value    = " as result %10.6f scalar(final_Jp)
display as text "Final beta on ghq         = " as result %10.6f scalar(final_beta)

*-----------------------------------------------------*
* 13. Decode the final valid and invalid sets
*-----------------------------------------------------*
local valid_final
local invalid_final

local j = 1
foreach v of local z_use {
    scalar bit = mod(floor(scalar(final_mask) / (2^(`j'-1))), 2)

    if scalar(bit) == 1 {
        local valid_final `valid_final' `v'
    }
    else {
        local invalid_final `invalid_final' `v'
    }

    local ++j
}

display as text "Selected valid instruments:   `valid_final'"
display as text "Selected invalid instruments: `invalid_final'"

*-----------------------------------------------------*
* 14. Restore the working sample and run final post-selection 2SLS
*-----------------------------------------------------*
use `worksample', clear

local nvalid_final : word count `valid_final'

if `nvalid_final' == 0 {
    display as error "No valid instruments selected."
}
else {
    if "`invalid_final'" == "" {
        ivreg2 `y' `x' (`d' = `valid_final'), cluster(pidp) first
    }
    else {
        ivreg2 `y' `x' `invalid_final' (`d' = `valid_final'), cluster(pidp) first
    }
}

restore

*******************************************************
* End of corrected CI method routine
*******************************************************

log close














ex

// //original
// local negset deathfam familyprob neighbour friendend
// local posset vacation leisure engage birthday anniversary godparent relatives friends
//
// ivregress 2sls newjob lnw dvage age2 male (ghq = `negset' `posset'), vce(cluster pidp) first


*CI method

*******************************************************
* Confidence Interval (CI) method for selecting valid IVs
* Single endogenous regressor: ghq
* Outcome: newjob
* Candidate instruments: life events
*
* Paper-faithful selection stage:
* 1. Partial out exogenous controls
* 2. Compute instrument-specific just-identified IV estimates
* 3. Build CI groups
* 4. Use Sargan-based downward testing
*
* Practical reporting stage:
* Final post-selection 2SLS is reported with clustered SEs
*******************************************************

version 18
set more off
mata clear

*-----------------------------------------------------*
* 1. Define variable lists
*-----------------------------------------------------*
local y newjob
local d ghq
local x lnw dvage age2 male

local negset deathfam familyprob neighbour friendend
local posset vacation leisure engage birthday anniversary godparent relatives friends
local z `negset' `posset'

*-----------------------------------------------------*
* 2. Clean previously created variables if they exist
*-----------------------------------------------------*
capture drop touse y_r d_r
foreach v of local z {
    capture drop `v'_r
}

*-----------------------------------------------------*
* 3. Define the estimation sample using the baseline IV model
*-----------------------------------------------------*
quietly ivregress 2sls `y' `x' (`d' = `z')
gen byte touse = e(sample)

count if touse
display as text "Estimation sample size = " as result r(N)

if r(N) == 0 {
    display as error "No observations in e(sample). Check variable names and missing values."
    exit 2000
}

preserve
keep if touse

*-----------------------------------------------------*
* 4. Partial out exogenous controls from y, d, and z
*-----------------------------------------------------*
quietly regress `y' `x'
predict double y_r, resid

quietly regress `d' `x'
predict double d_r, resid

local z_r
foreach v of local z {
    quietly regress `v' `x'
    predict double `v'_r, resid
    local z_r `z_r' `v'_r
}

*-----------------------------------------------------*
* 5. Compute instrument-specific just-identified IV estimates
*    Each instrument is used as the single excluded IV,
*    while all other candidate instruments are treated as invalid
*    and therefore included as regressors
*-----------------------------------------------------*
local kz : word count `z'

tempname B SE
matrix `B'  = J(`kz',1,.)
matrix `SE' = J(`kz',1,.)

local j = 1
foreach zj of local z_r {
    local others : list z_r - zj

    quietly ivregress 2sls y_r `others' (d_r = `zj')
    matrix `B'[`j',1]  = _b[d_r]
    matrix `SE'[`j',1] = _se[d_r]

    local ++j
}

matrix inst_est = `B', `SE'
matrix rownames inst_est = `z'
matrix colnames inst_est = bhat se

display as text "Instrument-specific just-identified IV estimates:"
matrix list inst_est

*-----------------------------------------------------*
* 6. Mata helper functions
*-----------------------------------------------------*
mata:

real colvector mask_to_idx(real scalar mask, real scalar k)
{
    real colvector idx
    real scalar j

    idx = J(0,1,.)
    for (j=1; j<=k; j++) {
        if (mod(floor(mask / (2^(j-1))), 2) == 1) {
            idx = idx \ j
        }
    }
    return(idx)
}

real colvector complement_idx(real colvector idx, real scalar k)
{
    real colvector all, keep
    all  = (1::k)
    keep = J(k,1,1)
    if (rows(idx) > 0) keep[idx] = J(rows(idx),1,0)
    return(select(all, keep))
}

real colvector unique_sorted(real colvector x)
{
    real colvector xs, out
    real scalar i

    if (rows(x)==0) return(x)

    xs  = sort(x,1)
    out = xs[1]

    for (i=2; i<=rows(xs); i++) {
        if (abs(xs[i] - out[rows(out)]) > 1e-10) {
            out = out \ xs[i]
        }
    }
    return(out)
}

real rowvector post2sls_sargan(real colvector y, real colvector d, real matrix Z, real colvector valid)
{
    real scalar n, k, df, p, S
    real colvector invalid, u
    real matrix PZ, X, XPZX, theta

    n = rows(Z)
    k = cols(Z)

    invalid = complement_idx(valid, k)

    X = d
    if (rows(invalid) > 0) {
        X = X, Z[, invalid]
    }

    PZ   = Z * invsym(quadcross(Z,Z)) * Z'
    XPZX = quadcross(X, PZ*X)
    theta = invsym(XPZX) * quadcross(X, PZ*y)

    u = y - X*theta

    S  = quadcross(u, PZ*u) / (quadcross(u,u) / n)
    df = rows(valid) - 1

    if (df > 0) p = chi2tail(df, S)
    else        p = .

    return((S, p, theta[1,1]))
}

real matrix largest_overlap_groups(real colvector b, real colvector se, real scalar psi,
                                   real colvector y, real colvector d, real matrix Z)
{
    real scalar k, mask, nmask, bestsize, s
    real colvector idx, lo, hi
    real rowvector info
    real matrix out

    k      = rows(b)
    nmask  = 2^k - 1
    bestsize = 0
    out = J(0,5,.)

    for (mask=1; mask<=nmask; mask++) {
        idx = mask_to_idx(mask, k)
        s   = rows(idx)

        lo = b[idx] :- psi * se[idx]
        hi = b[idx] :+ psi * se[idx]

        * Strict overlap rule, matching the breakpoint logic in the paper
        if (max(lo) < min(hi)) {
            if (s > bestsize) {
                bestsize = s
                out = J(0,5,.)
            }

            if (s == bestsize) {
                info = post2sls_sargan(y, d, Z, idx)
                out  = out \ (mask, s, info[1], info[2], info[3])
            }
        }
    }

    return(out)
}

end

*-----------------------------------------------------*
* 7. Run the CI method and Sargan-based downward testing
*-----------------------------------------------------*
mata:

E  = st_matrix("inst_est")
b  = E[,1]
se = E[,2]

y  = st_data(., "y_r")
d  = st_data(., "d_r")
Z  = st_data(., tokens(st_local("z_r")))

n  = rows(Z)
k  = cols(Z)

* Sargan p-value threshold suggested in the paper
pthr = 0.1 / log(n)

* Breakpoints psi*_jr = |b_j - b_r| / (se_j + se_r)
bp = J(0,1,.)
for (j=1; j<=k-1; j++) {
    for (r=j+1; r<=k; r++) {
        bp = bp \ (abs(b[j] - b[r]) / (se[j] + se[r]))
    }
}
bp = unique_sorted(bp)

* Build descending psi values:
* first a value above the largest breakpoint for the all-valid model,
* then all breakpoints in descending order
if (rows(bp) > 0) {
    psi_vals = J(rows(bp)+1,1,.)
    psi_vals[1] = max(bp) + 1
    for (i=1; i<=rows(bp); i++) {
        psi_vals[i+1] = bp[rows(bp)-i+1]
    }
}
else {
    psi_vals = 1
}

* Store all candidate groups:
* columns = psi, mask, nvalid, Sargan, pvalue, beta_post
All = J(0,6,.)
for (i=1; i<=rows(psi_vals); i++) {
    G = largest_overlap_groups(b, se, psi_vals[i], y, d, Z)
    if (rows(G) > 0) {
        All = All \ (J(rows(G),1,psi_vals[i]), G)
    }
}

* For each valid-set size, keep the candidate with the minimum Sargan statistic
Best = J(0,6,.)
for (s=k; s>=1; s--) {
    idx = selectindex(All[,3] :== s)
    if (rows(idx) > 0) {
        sub = All[idx,]
        pos = order(sub[,4], 1)[1]
        Best = Best \ sub[pos,]
    }
}

* Choose the largest valid set that passes the Sargan threshold
finalrow = .
passflag = 0

for (i=1; i<=rows(Best); i++) {
    if (Best[i,3] >= 2 & Best[i,5] > pthr) {
        finalrow = i
        passflag = 1
        break
    }
}

* Fallback if no overidentified model passes the threshold
if (missing(finalrow)) {
    idx = selectindex(Best[,3] :>= 2)
    if (rows(idx) > 0) {
        sub = Best[idx,]
        pos = order(sub[,4], 1)[1]
        finalrow = idx[pos]
    }
    else {
        finalrow = 1
    }
}

st_numscalar("pthr", pthr)
st_numscalar("passflag", passflag)

st_numscalar("final_psi",   Best[finalrow,1])
st_numscalar("final_mask",  Best[finalrow,2])
st_numscalar("final_nval",  Best[finalrow,3])
st_numscalar("final_S",     Best[finalrow,4])
st_numscalar("final_p",     Best[finalrow,5])
st_numscalar("final_beta",  Best[finalrow,6])

st_matrix("ci_size_results", Best)

end

matrix colnames ci_size_results = psi mask nvalid sargan pvalue beta_post

display as text "Sargan p-value threshold = " as result %9.6f scalar(pthr)
display as text "Candidate models by valid-set size (best Sargan within each size):"
matrix list ci_size_results

display as text "Final selected psi      = " as result %10.6f scalar(final_psi)
display as text "Final selected mask     = " as result %10.0f scalar(final_mask)
display as text "Final number of valid IVs = " as result %10.0f scalar(final_nval)
display as text "Final Sargan statistic  = " as result %10.6f scalar(final_S)
display as text "Final Sargan p-value    = " as result %10.6f scalar(final_p)
display as text "Final post-selection beta on residualized data = " as result %10.6f scalar(final_beta)

if scalar(passflag)==1 {
    display as text "A model passed the Sargan threshold."
}
else {
    display as error "No overidentified model passed the Sargan threshold."
    display as error "Fallback: the code selected the model with the smallest Sargan statistic."
}

*-----------------------------------------------------*
* 8. Decode the final valid and invalid instrument sets
*-----------------------------------------------------*
local valid
local invalid
local j = 1

foreach v of local z {
    scalar bit = mod(floor(scalar(final_mask) / (2^(`j'-1))), 2)

    if scalar(bit) == 1 {
        local valid `valid' `v'
    }
    else {
        local invalid `invalid' `v'
    }

    local ++j
}

display as text "Selected valid instruments:   `valid'"
display as text "Selected invalid instruments: `invalid'"

*-----------------------------------------------------*
* 9. Run the final post-selection 2SLS on original variables
*    Invalid instruments are included as controls
*    Valid instruments remain excluded IVs
*-----------------------------------------------------*
local nvalid : word count `valid'

if `nvalid' == 0 {
    display as error "No valid instruments selected."
}
else {
    if "`invalid'" == "" {
        ivregress 2sls `y' `x' (`d' = `valid'), vce(cluster pidp) first
    }
    else {
        ivregress 2sls `y' `x' `invalid' (`d' = `valid'), vce(cluster pidp) first
    }

    if `nvalid' > 1 {
        capture noisily estat overid
    }
}

restore

*******************************************************
* End of CI method routine
*******************************************************














