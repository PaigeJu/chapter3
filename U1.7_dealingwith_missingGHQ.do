cls
clear all
set more off



*------------------------------------------------------------------------------------*
*                               investigate missing GHQ 
*------------------------------------------------------------------------------------*
// log using "missingGHQ", replace 

use ind_ghq_lfs, clear
xtset pidp wave
drop if year == 2024 
// order pidp wave ghq weightscaled indsc*
// most observations with a negative GHQ are assigned with a 0 weight (Cross-sectional adult self-completion interview weight).


global X "lnw dvage age2 male i.year"

*1. missing 
tab ghq 
label variable ghq "sum of 12 ghq, 0-36, the higher the worse. -9missing,-8 inapplicable,-7proxy. == scghq1_dv."
//missing GHQ can become an identification issue if response to the GHQ module is related to family death, future job moves, or unobserved distress.  

gen missingGHQ = (ghq < 0)
label variable missingGHQ "=1 if GHQ is missing, less than 0, -9missing,-8 inapplicable,-7proxy"


* 2.1 basic descriptive 
tab missingGHQ  //12% GHQ <0

tab wave missingGHQ, row  //wave 1: 22% GHQ <0, wave 2: 21% GHQ <0, wave 5: 16% GHQ <0. less missing values in later waves, wave 7-10, less than 10% missing, wave 11-14, less than 5% missing. 

tab wave  //wave 5 count for 8% of observations, while wave 1 and 2 count for 9% and 10%. smaller proportion in later waves. 

*2.1.1 missing rate per wave 
/////////////
tab ghq wave if ghq <0

tab ghq wave if ghq < 0, col



////////
bys wave: gen n_perwave = _N
bysort wave: egen n_missingperwave = total(missingGHQ == 1)
tab n_missingperwave wave, row
gen missingrate_wave = n_missingperwave/n_perwave
label variable missingrate_wave "n(missing GHQ observations) / n(total observations per wave)"

tab missingrate_wave wave, row  //

preserve
keep wave n_perwave n_missingperwave missingrate_wave
bysort wave: keep if _n == 1
sort wave
* missingrate_wave is stored as 0-1, convert to percent for plotting
capture drop missingrate_pct
gen missingrate_pct = 100*missingrate_wave

levelsof wave, local(waves)
twoway ///
    (bar n_perwave wave, ///
        base(0) barwidth(0.75) ///
        color(gs12) lcolor(gs8) ///
        yaxis(1)) ///
    (bar n_missingperwave wave, ///
        base(0) barwidth(0.45) ///
        color(navy%70) lcolor(navy) ///
        yaxis(1)) ///
    (scatter missingrate_pct wave, ///
        connect(l) sort ///
        msymbol(O) msize(small) ///
        mlabel(missingrate_pct) mlabformat(%4.1f) ///
        mlabposition(12) mlabsize(tiny) ///
        yaxis(2)), ///
    xlabel(`waves') ///
    xtitle("Wave") ///
    ytitle("Number of observations", axis(1)) ///
    ytitle("Missing GHQ rate (%)", axis(2)) ///
    ylabel(, axis(2) format(%4.1f)) ///
    title("GHQ missingness by wave") ///
    subtitle("Grey bars = total observations; blue bars = missing observations", size(small)) ///
    legend(order(1 "Total observations" 2 "Missing observations" 3 "Missing rate")) ///
    graphregion(color(white)) ///
//     plotregion(color(white))
	
restore

* 2.1.2 demographic comparision between whole sample and people with at least one missing GHQ
bys pidp: egen evermissGHQ = max(missingGHQ)
label variable evermissGHQ "=1 if the individual at least reported 1 missing GHQ"


* 2.1.2.1 gender
preserve
//keep one row per individual
egen tagpid = tag(pidp)
keep if tagpid

//save whole-sample version
tempfile base subset
save `base'

//create subset: individuals with at least one missing GHQ
keep if evermissGHQ == 1
gen samplegrp = 2
save `subset'

//reload whole sample and append subset
use `base', clear
gen samplegrp = 1
append using `subset'

label define samplegrp 1 "Whole sample" 2 "At least one missing GHQ"
label values samplegrp samplegrp

//graph 
gen female = 1 - male
	
	graph bar (mean) female male, ///
    over(samplegrp) ///
    percentages stack ///
    bar(1, color("230 220 255") lcolor("200 185 235")) ///
    bar(2, color("210 240 210") lcolor("170 210 170")) ///
    title("Gender composition: whole sample vs ever-missing GHQ") ///
    subtitle("Person-level sample", size(small)) ///
    ytitle("Percent") ///
    legend(order(1 "Female" 2 "Male")) ///
    blabel(bar, format(%4.1f)) ///
    graphregion(color(white))
	
restore 

* 2.1.2.2 age 
preserve
//keep one row per individual
egen tagpid = tag(pidp)
keep if tagpid

//save whole-sample version
tempfile base subset
save `base'

//create subset: individuals with at least one missing GHQ
keep if evermissGHQ == 1
gen samplegrp = 2
save `subset'

//reload whole sample and append subset
use `base', clear
gen samplegrp = 1
append using `subset'

label define samplegrp 1 "Whole sample" 2 "At least one missing GHQ"
label values samplegrp samplegrp

//graph 
gen midage = (young==0 & senior==0)
label variable midage "age is in [26,44]"

//young =1 if age<=25, senior =1 if age>=45	
graph bar (mean) young midage senior, ///
    over(samplegrp) ///
    percentages stack ///
    bar(1, color("230 220 255") lcolor("200 185 235")) ///
    bar(2, color("210 240 210") lcolor("170 210 170")) ///
	bar(3, color("210 230 255") lcolor("210 230 255")) ///
    title("Age composition: whole sample vs ever-missing GHQ") ///
    subtitle("Person-level sample", size(small)) ///
    ytitle("Percent") ///
    legend(order(1 "young" 2 "midage" 3 "senior")) ///
    blabel(bar, format(%4.1f)) ///
    graphregion(color(white))
	
restore 


* education 
// preserve
// //keep one row per individual
// egen tagpid = tag(pidp)
// keep if tagpid
//
// //save whole-sample version
// tempfile base subset
// save `base'
//
// //create subset: individuals with at least one missing GHQ
// keep if evermissGHQ == 1
// gen samplegrp = 2
// save `subset'
//
// //reload whole sample and append subset
// use `base', clear
// gen samplegrp = 1
// append using `subset'
//
// label define samplegrp 1 "Whole sample" 2 "At least one missing GHQ"
// label values samplegrp samplegrp
//
// //graph 
// //edu_g1 is highest education level, edu_g2 is the middle, edu_g3 is the lowest education level  	
// graph bar (mean) edu_g1 edu_g2 edu_g3, ///
//     over(samplegrp) ///
//     percentages stack ///
//     bar(1, color("230 220 255") lcolor("200 185 235")) ///
//     bar(2, color("210 240 210") lcolor("170 210 170")) ///
// 	bar(3, color("210 230 255") lcolor("210 230 255")) ///
//     title("Education composition: whole sample vs ever-missing GHQ") ///
//     subtitle("Person-level sample", size(small)) ///
//     ytitle("Percent") ///
//     legend(order(1 "hightest" 2 "mid" 3 "lowest")) ///
//     blabel(bar, format(%4.1f)) ///
//     graphregion(color(white))
//	
// restore 


* relationship status 
preserve
//keep one row per individual
egen tagpid = tag(pidp)
keep if tagpid

//save whole-sample version
tempfile base subset
save `base'

//create subset: individuals with at least one missing GHQ
keep if evermissGHQ == 1
gen samplegrp = 2
save `subset'

//reload whole sample and append subset
use `base', clear
gen samplegrp = 1
append using `subset'

label define samplegrp 1 "Whole sample" 2 "At least one missing GHQ"
label values samplegrp samplegrp

//graph 
//marstat_dv is the harmonised facto marital status： 0 "Under 16 years", 1 "Married", 2 "Living as couple", 3 "Widowed", 4 "Divorced", 5 "Separated", and 6 "Never married". -9 "missing"
// br pidp dvage if marstat_dv ==0
replace marstat_dv = 6 if dvage <18  //295 individuals aged over 16 but recorded as 0 "under 16 years"
replace marstat_dv = -9 if dvage >=18 & marstat_dv==0 //2 individuals aged 19, 33 but recorded as 0 "under 16 years", change them to -9 missing 

count if marstat_dv==-9

gen Married = (marstat_dv==1)
gen Couple = (marstat_dv==2)
gen Widowed = (marstat_dv==3)
gen Divorced = (marstat_dv==4)
gen Separated = (marstat_dv==5)
gen Never_married = (marstat_dv==6)

graph bar (mean) Married Never_married Couple Divorced Widowed Separated, ///
    over(samplegrp) ///
    percentages stack ///
    bar(1, color("230 220 255") lcolor("200 185 235")) ///
    bar(2, color("240 235 210") lcolor("215 205 170")) ///
    bar(3, color("210 240 210") lcolor("170 210 170")) ///
    bar(4, color("255 225 210") lcolor("235 190 170")) ///
    bar(5, color("210 230 255") lcolor("180 205 235")) ///
    bar(6, color("245 220 230") lcolor("220 185 200")) ///
    title("Relationship type composition: whole sample vs ever-missing GHQ", size(Medium)) ///
    subtitle("Person-level sample", size(small)) ///
    ytitle("Percent") ///
    legend(order(1 "Married" 2 "Never married" 3 "Couple" 4 "Divorced" 5 "Widowed" 6 "Separated")) ///
    blabel(bar, position(center) size(vsamll) format(%4.1f)) ///
    graphregion(color(white))
	
restore 

* labour force status 
preserve
//keep one row per individual
egen tagpid = tag(pidp)
keep if tagpid

//save whole-sample version
tempfile base subset
save `base'

//create subset: individuals with at least one missing GHQ
keep if evermissGHQ == 1
gen samplegrp = 2
save `subset'

//reload whole sample and append subset
use `base', clear
gen samplegrp = 1
append using `subset'

label define samplegrp 1 "Whole sample" 2 "At least one missing GHQ"
label values samplegrp samplegrp

//graph 
//lfs: labour force status, 1 employed/self-employed,2 unemployed, 3 incative
gen employed_selfemployed = (lfs==1)
gen unemployed = (lfs==2)
gen incative = (lfs==3)

graph bar (mean) employed_selfemployed incative unemployed, ///
    over(samplegrp) ///
    percentages stack ///
    bar(1, color("230 220 255") lcolor("200 185 235")) ///
    bar(2, color("210 240 210") lcolor("170 210 170")) ///
	bar(3, color("210 230 255") lcolor("210 230 255")) ///
    title("labour force status: whole sample vs ever-missing GHQ") ///
    subtitle("Person-level sample", size(small)) ///
    ytitle("Percent") ///
    legend(order(1 "employed/self-employed" 2 "incative" 3 "unemployed")) ///
	blabel(bar, position(center) size(vsamll) format(%4.1f)) ///
    graphregion(color(white))
	
restore 


* if have other GHQ record, the average GHQ over the years 



* physical health?
//health: Long-standing illness or disability. Question:Do you have any long-standing physical or mental impairment, illness or disability? By 'long-standing' I mean anything that has troubled you over a period of at least 12 months or that is likely to trouble you over a period of at least 12 months. -9, missing; -2, refusal; -1 don't know; 1 yes; 2 no. 
//hcond: Diagnosed health conditions. 
//sf1(wave 1-5) & scsf1(wave 6-14): general health. Question: In general, would you say [NAME]'s health is...? -9, missing; -8, inapplicable; 1, excellent; 2, very good; 3, good; 4,fair; 5, poor. 





* 2.2 whether GHQ at t-1 can predict missing GHQ at t  
order wave pidp newjob ghq ghq_l missingGHQ

preserve
keep if ghq_l <.
tab missingGHQ  //5.5% missingGHQ = 1
probit missingGHQ ghq_l $X i.wave //in the whole sample (14 waves), positively correlated, but p-value = 0.38
restore
//


* 2.3 whether report negative life-event could predict missing GHQ 
sort pidp wave 
merge pidp wave using ind_event
sort pidp wave 
order pidp wave newjob ghq ghq_l missingGHQ anyevent pstvevent ngtvevent 

// keep if inlist(wave, 1, 2, 3, 5, 6)
xtset pidp wave
gen anyevent_l = L.anyevent
gen pstvevent_l = L.pstvevent
gen ngtvevent_l = L.ngtvevent
order pidp wave newjob ghq ghq_l missingGHQ anyevent* pstvevent* ngtvevent*

preserve
keep if !missing(anyevent_l, pstvevent_l, ngtvevent_l)

tab missingGHQ anyevent_l, row
tab missingGHQ pstvevent_l, row
tab missingGHQ ngtvevent_l, row

probit missingGHQ anyevent_l $X  //in the life-event sample (125 waves), negatively correlated
probit missingGHQ pstvevent_l $X  //in the life-event sample (125 waves), negatively correlated
probit missingGHQ ngtvevent_l $X  //in the life-event sample (125 waves), negatively correlated
restore

gen event1_l =L.event1
probit missingGHQ anyevent_l $X i.wave if event1_l >0  //in the life-event sample (125 waves), negatively correlated
reg missingGHQ anyevent_l $X i.wave if event1_l >0  //in the life-event sample (125 waves), negatively correlated

tab anyevent_l

br anyevent event*


// log close 





exit 

/////////////////////////////GPT
* 1. Recode invalid GHQ values
replace ghq = . if ghq < 0

* 2. Define usable estimation sample
gen samp = !missing(ghq, deathfam, newjob_f, lnw, dvage, age2, male)

* 3. Selection diagnostic
logit samp deathfam male c.dvage##c.dvage i.wave ///
      i.lfs_lag ghq_lag lnw_lag nkids_lag

* 4. Predicted response probability
predict phat if e(sample), pr

* 5. IPW
gen ipw = 1/phat if samp==1

* optional trimming of extreme weights
sum ipw if samp==1, detail
replace ipw = r(p99) if ipw > r(p99) & ipw < .

* 6. Baseline complete-case IV
ivregress 2sls newjob_f lnw dvage age2 male i.wave ///
    (ghq = deathfam) if samp==1, vce(cluster pidp)

* 7. IPW IV robustness
ivregress 2sls newjob_f lnw dvage age2 male i.wave ///
    (ghq = deathfam) [pw=ipw] if samp==1, vce(cluster pidp)
	
	
exit 













replace ghq = . if ghq < 0


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


*1.3 exact-ID 2SLS
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



exit 
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
	
	
log close

//I treated deathfam as the baseline core IV and then asked which extra instruments can be added without creating overidentification tension.
//vacation, familyprob, and anniversary survive that screen, while friendend is borderline and leisure is rejected.
//The combined specifications remain negatively signed, become more precise, and do not trigger Hansen J rejection.
//So the paper still looks like Path A rather than Path B: a defensible core-IV design with a small expanded set that appears tolerable.


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














