clear all
set more off


*** load data, respondents aged 16-65
use ind_ghq_lfs, clear
xtset pidp idate
drop if year == 2024 


* the whole data sample
preserve
duplicates drop pidp , force 
sum pidp 
tab male
restore

tab ghq
tab ghq if ghq >= 0

tab scghqa if scghqa>0
tab scghqb if scghqb>0


*** Drop person-wave observations if ANY GHQ item has a negative (non-valid) code

* complete-case indicator （any ghq <0 ）
egen ghq_rowmin = rowmin(scghqa scghqb scghqc scghqd scghqe scghqf ///
                         scghqg scghqh scghqi scghqj scghqk scghql)
gen byte ghq_complete = (ghq_rowmin >= 1)

tab ghq_complete

*
ttest dvage, by(ghq_complete)
tab male ghq_complete, col

* non-valid answer by each question
preserve
tempfile missstats
tempname post
postfile `post' str10 item long N_miss double p_miss using `missstats', replace

local N = _N
foreach v of varlist scghqa-scghql {
    quietly count if missing(`v') | `v' < 0
    local nm = r(N)
    post `post' ("`v'") (`nm') (100*`nm'/`N')
}
postclose `post'

use `missstats', clear
list, noobs abbreviate(20)
restore

*
drop if scghqa<0 | scghqb<0 | scghqc<0 | scghqd<0 | scghqe<0 | scghqf<0 | scghqg<0 | scghqh<0 | scghqi<0 | scghqj<0 | scghqk<0 | scghql<0


/*
*** 12 questions graph
* White background + softer default look
set scheme s2color

local items scghqa scghqb scghqc scghqd scghqe scghqf scghqg scghqh scghqi scghqj scghqk scghql

local glist
local i = 1
foreach v of local items {

    histogram `v' if inrange(`v',1,4), discrete percent ///
        title("`: variable label `v''", size(vsmall)) ///
        xtitle("") ytitle("") ///
        xlabel(1(1)4, labsize(vsmall)) ///
        ylabel(0(20)100, angle(horizontal) labsize(vsmall) nogrid) ///
        yscale(range(0 100)) ///
        color(eltblue%55) lcolor(eltblue%85) lwidth(vthin) ///
        graphregion(color(white) margin(l=14 r=2 t=2 b=2)) ///
        plotregion(color(white) margin(small)) ///
        name(h`i', replace)

    local glist `glist' h`i'
    local ++i
}

graph combine `glist', col(4) imargin(tiny) iscale(0.85) ///
    graphregion(color(white)) ///
    title("GHQ-12 item response distributions (pooled Waves 1–14)", size(small)) ///
    note("Percent of valid responses (1–4). Non-valid codes (<0) excluded.", size(vsmall))


*/	
	
	
	
	
*** ghq 

// * median ghq over time 
// preserve
// tempfile qstats
// tempname post
// postfile `post' int wave double ghq_p25 ghq_med ghq_p75 using `qstats', replace
//
// levelsof wave, local(waves)
// foreach w of local waves {
//     quietly _pctile ghq if wave==`w' [pw=weightscaled], p(25 50 75)
//     post `post' (`w') (r(r1)) (r(r2)) (r(r3))
// }
// postclose `post'
//
// use `qstats', clear
// sort wave
//
// set scheme s1color
// twoway (rarea ghq_p75 ghq_p25 wave, color(eltblue%20) lcolor(none)) ///
//        (line  ghq_med wave,        lcolor(eltblue%85) lwidth(medthick)), ///
//        ytitle("Weighted GHQ-12 (0–36)") xtitle("Wave") ///
//        xlabel(1(1)14) legend(off) ///
//        graphregion(color(white)) plotregion(color(white)) ///
//        title("Median GHQ-12 (weighted)", size(small)) ///
//        subtitle("Pooled Waves 1–14", size(vsmall))
// restore


* mean， p10 90
* by year
use ind_ghq_lfs, clear
xtset pidp idate
drop if year == 2024 
drop if scghqa<0 | scghqb<0 | scghqc<0 | scghqd<0 | scghqe<0 | scghqf<0 | scghqg<0 | scghqh<0 | scghqi<0 | scghqj<0 | scghqk<0 | scghql<0

preserve
tempfile s
tempname post
postfile `post' int year double mean p10 p50 p90 using "`s'", replace

levelsof year, local(years)
foreach y of local years {

    * --- weighted mean: sum(w*ghq)/sum(w) within year ---
    quietly summarize weightscaled if year==`y', meanonly
    local sumw = r(sum)

    tempvar wg
    gen double `wg' = weightscaled * ghq if year==`y'
    quietly summarize `wg' if year==`y', meanonly
    local sumwg = r(sum)

    local m = `sumwg' / `sumw'
    drop `wg'

    * --- weighted quantiles within year ---
    quietly _pctile ghq if year==`y' [pw=weightscaled], p(10 50 90)

    post `post' (`y') (`m') (r(r1)) (r(r2)) (r(r3))
}

postclose `post'

use "`s'", clear
sort year
list, sep(0)

set scheme s1color
twoway ///
    (line mean year, lwidth(medthick)) ///
    (line p10  year, lwidth(medthick)) ///
    (line p50  year, lwidth(medthick)) ///
    (line p90  year, lwidth(medthick)), ///
    legend(order(1 "Mean" 2 "p10" 3 "Median (p50)" 4 "p90") ///
           cols(2) pos(12) ring(1) region(lstyle(none))) ///
    ytitle("Weighted GHQ-12 (0–36)") ///
    xtitle("Year") ///
    graphregion(color(white)) ///
    plotregion(color(white))

restore




* by sex 
use ind_ghq_lfs, clear
xtset pidp idate
drop if year == 2024 
drop if scghqa<0 | scghqb<0 | scghqc<0 | scghqd<0 | scghqe<0 | scghqf<0 | scghqg<0 | scghqh<0 | scghqi<0 | scghqj<0 | scghqk<0 | scghql<0

set scheme s1color

capture label define male_lbl 0 "Female" 1 "Male", replace
capture label values male male_lbl

* Female
histogram ghq if male==0 & !missing(ghq), percent start(0) width(1) ///
    title("Female", size(small)) ///
    xtitle("") ytitle("") ///
    xlabel(0(5)35, labsize(vsmall)) ///
    ylabel(0(5)20, angle(horizontal) labsize(vsmall) nogrid) ///
    yscale(range(0 20)) ///
    color(eltblue%55) lcolor(eltblue%85) lwidth(vthin) ///
    graphregion(color(white) margin(l=14 r=2 t=2 b=2)) ///
    plotregion(color(white) margin(small)) ///
    name(g_female, replace)

* Male
histogram ghq if male==1 & !missing(ghq), percent start(0) width(1) ///
    title("Male", size(small)) ///
    xtitle("") ytitle("") ///
    xlabel(0(5)35, labsize(vsmall)) ///
    ylabel(0(5)20, angle(horizontal) labsize(vsmall) nogrid) ///
    yscale(range(0 20)) ///
    color(eltblue%55) lcolor(eltblue%85) lwidth(vthin) ///
    graphregion(color(white) margin(l=14 r=2 t=2 b=2)) ///
    plotregion(color(white) margin(small)) ///
    name(g_male, replace)

* Combine
graph combine g_female g_male, col(2) imargin(tiny) iscale(0.95) ///
    title("GHQ-12 Likert total score (0–36)", size(small)) ///
    subtitle("Pooled Waves 1–14", size(vsmall)) ///
    note("Percent of valid GHQ total scores (0–36).", size(vsmall)) ///
    graphregion(color(white))
	
	
	
* cdf by gender
use ind_ghq_lfs, clear
xtset pidp idate
drop if year == 2024 
drop if scghqa<0 | scghqb<0 | scghqc<0 | scghqd<0 | scghqe<0 | scghqf<0 | scghqg<0 | scghqh<0 | scghqi<0 | scghqj<0 | scghqk<0 | scghql<0

set scheme s1color

capture label define male_lbl 0 "Female" 1 "Male", replace
capture label values male male_lbl

preserve
keep if !missing(ghq, male)
keep ghq male

* Count frequency at each GHQ score within sex
contract male ghq

* Total frequency within sex
bys male: egen total = total(_freq)

* Cumulative distribution function in percent
bys male (ghq): gen cdf = 100 * sum(_freq) / total

* Keep only what we need
keep male ghq cdf

* Reshape wide: cdf0 = Female, cdf1 = Male
reshape wide cdf, i(ghq) j(male)

* Make sure all GHQ values 0–36 appear on x-axis
tempfile cdfdata
save `cdfdata', replace

clear
set obs 37
gen ghq = _n - 1

merge 1:1 ghq using `cdfdata', nogen

* Fill in missing CDF values so lines run continuously
foreach v in cdf0 cdf1 {
    replace `v' = 0 if ghq == 0 & missing(`v')
    forvalues i = 2/37 {
        replace `v' = `v'[`i'-1] if missing(`v') in `i'
    }
}

* Plot overlaid CDFs
twoway ///
    (line cdf0 ghq, sort lcolor(eltblue) lwidth(medthick)) ///
    (line cdf1 ghq, sort lcolor(navy)    lwidth(medthick)), ///
    title("GHQ-12 Likert total score (0–36)", size(small)) ///
    subtitle("Empirical cumulative distribution by sex", size(vsmall)) ///
    xtitle("GHQ total score") ///
    ytitle("Cumulative percent") ///
    xlabel(0(5)35, labsize(vsmall)) ///
    ylabel(0(20)100, angle(horizontal) labsize(vsmall) nogrid) ///
    legend(order(1 "Female" 2 "Male") cols(2) pos(6) ring(0) region(lstyle(none))) ///
    graphregion(color(white) margin(l=14 r=2 t=2 b=2)) ///
    plotregion(color(white) margin(small))

restore




	
* by age group 
use ind_ghq_lfs, clear
xtset pidp idate
drop if year == 2024 
drop if scghqa<0 | scghqb<0 | scghqc<0 | scghqd<0 | scghqe<0 | scghqf<0 | scghqg<0 | scghqh<0 | scghqi<0 | scghqj<0 | scghqk<0 | scghql<0

capture drop agegrp
gen byte agegrp = .
replace agegrp = 1 if !missing(dvage) & dvage <= 25
replace agegrp = 2 if !missing(dvage) & inrange(dvage, 26, 44)
replace agegrp = 3 if !missing(dvage) & dvage >= 45

label define agegrp_lbl 1 "Young (<=25)" 2 "Mid (26–44)" 3 "Senior (>=45)", replace
label values agegrp agegrp_lbl
label var agegrp "Age group"


set scheme s1color

levelsof agegrp, local(grps)

local glist
foreach g of local grps {
    local ttl : label (agegrp) `g'
    if "`ttl'"=="" local ttl "Age group `g'"

    histogram ghq if agegrp==`g' & !missing(ghq), percent start(0) width(1) ///
        title("`ttl'", size(small)) ///
        xtitle("") ytitle("") ///
        xlabel(0(5)35, labsize(vsmall)) ///
        ylabel(0(5)20, angle(horizontal) labsize(vsmall) nogrid) ///
        yscale(range(0 20)) ///
        color(eltblue%55) lcolor(eltblue%85) lwidth(vthin) ///
        graphregion(color(white) margin(l=14 r=2 t=2 b=2)) ///
        plotregion(color(white) margin(small)) ///
        name(g_age`g', replace)

    local glist `glist' g_age`g'
}

graph combine `glist', col(2) imargin(tiny) iscale(0.95) ///
    title("GHQ-12 Likert total score (0–36)", size(small)) ///
    subtitle("Pooled Waves 1–14", size(vsmall)) ///
    note("Percent of valid GHQ total scores (0–36).", size(vsmall)) ///
    graphregion(color(white))	
	
	
	
* cdf by age
use ind_ghq_lfs, clear
xtset pidp idate
drop if year == 2024 
drop if scghqa<0 | scghqb<0 | scghqc<0 | scghqd<0 | scghqe<0 | scghqf<0 | scghqg<0 | scghqh<0 | scghqi<0 | scghqj<0 | scghqk<0 | scghql<0

capture drop agegrp
gen byte agegrp = .
replace agegrp = 1 if !missing(dvage) & dvage <= 25
replace agegrp = 2 if !missing(dvage) & inrange(dvage, 26, 44)
replace agegrp = 3 if !missing(dvage) & dvage >= 45

label define agegrp_lbl 1 "Young (<=25)" 2 "Mid (26–44)" 3 "Senior (>=45)", replace
label values agegrp agegrp_lbl
label var agegrp "Age group"

set scheme s1color
tempfile cdf_age

preserve
keep if !missing(ghq, agegrp)
keep ghq agegrp
contract agegrp ghq
bys agegrp: egen total = total(_freq)
bys agegrp (ghq): gen cdf = 100 * sum(_freq) / total
save `cdf_age', replace
restore

levelsof agegrp, local(grps)

local glist
foreach g of local grps {

    local ttl : label agegrp_lbl `g'
    if "`ttl'"=="" local ttl "Age group `g'"

    * Load the CDF data fresh each loop
    use `cdf_age', clear
    keep if agegrp==`g'
    keep ghq cdf

    * Ensure all GHQ values 0–36 appear
    tempfile onegrp
    save `onegrp', replace

    clear
    set obs 37
    gen ghq = _n - 1

    merge 1:1 ghq using `onegrp', nogen

    * Fill forward so the CDF is continuous
    replace cdf = 0 if ghq == 0 & missing(cdf)
    forvalues i = 2/37 {
        replace cdf = cdf[`i'-1] if missing(cdf) in `i'
    }

    twoway ///
        (line cdf ghq, sort lcolor(eltblue) lwidth(medthick)), ///
        title("`ttl'", size(small)) ///
        xtitle("") ytitle("") ///
        xlabel(0(5)35, labsize(vsmall)) ///
        ylabel(0(20)100, angle(horizontal) labsize(vsmall) nogrid) ///
        yscale(range(0 100)) ///
        graphregion(color(white) margin(l=14 r=2 t=2 b=2)) ///
        plotregion(color(white) margin(small)) ///
        name(g_age`g', replace)

    local glist `glist' g_age`g'
}

graph combine `glist', col(2) imargin(tiny) iscale(0.95) ///
    title("GHQ-12 Likert total score (0–36)", size(small)) ///
    subtitle("Empirical cumulative distribution by age group", size(vsmall)) ///
    note("Cumulative percent of valid GHQ total scores (0–36).", size(vsmall)) ///
    graphregion(color(white))
	
	
	
	
	
	
* cdf by age
use ind_ghq_lfs, clear
xtset pidp idate
drop if year == 2024 
drop if scghqa<0 | scghqb<0 | scghqc<0 | scghqd<0 | scghqe<0 | scghqf<0 | scghqg<0 | scghqh<0 | scghqi<0 | scghqj<0 | scghqk<0 | scghql<0

capture drop agegrp
gen byte agegrp = .
replace agegrp = 1 if !missing(dvage) & dvage <= 25
replace agegrp = 2 if !missing(dvage) & inrange(dvage, 26, 44)
replace agegrp = 3 if !missing(dvage) & dvage >= 45

label define agegrp_lbl 1 "Young (<=25)" 2 "Mid (26–44)" 3 "Senior (>=45)", replace
label values agegrp agegrp_lbl
label var agegrp "Age group"

set scheme s1color

preserve
keep if !missing(ghq, agegrp)
keep ghq agegrp

* Frequency by age group and GHQ
contract agegrp ghq

* Total within age group
bys agegrp: egen total = total(_freq)

* Empirical CDF in percent
bys agegrp (ghq): gen cdf = 100 * sum(_freq) / total

keep agegrp ghq cdf
tempfile cdf_age
save `cdf_age', replace
restore

* Create full GHQ support 0-36 and merge each age group CDF onto it
clear
set obs 37
gen ghq = _n - 1

tempfile base
save `base', replace

use `cdf_age', clear
keep if agegrp==1
keep ghq cdf
rename cdf cdf1
merge 1:1 ghq using `base', nogen
sort ghq
replace cdf1 = 0 if ghq==0 & missing(cdf1)
forvalues i = 2/37 {
    replace cdf1 = cdf1[`i'-1] if missing(cdf1) in `i'
}
keep ghq cdf1
tempfile t1
save `t1', replace

use `cdf_age', clear
keep if agegrp==2
keep ghq cdf
rename cdf cdf2
merge 1:1 ghq using `base', nogen
sort ghq
replace cdf2 = 0 if ghq==0 & missing(cdf2)
forvalues i = 2/37 {
    replace cdf2 = cdf2[`i'-1] if missing(cdf2) in `i'
}
keep ghq cdf2
tempfile t2
save `t2', replace

use `cdf_age', clear
keep if agegrp==3
keep ghq cdf
rename cdf cdf3
merge 1:1 ghq using `base', nogen
sort ghq
replace cdf3 = 0 if ghq==0 & missing(cdf3)
forvalues i = 2/37 {
    replace cdf3 = cdf3[`i'-1] if missing(cdf3) in `i'
}
keep ghq cdf3
tempfile t3
save `t3', replace

use `base', clear
merge 1:1 ghq using `t1', nogen
merge 1:1 ghq using `t2', nogen
merge 1:1 ghq using `t3', nogen

twoway ///
    (line cdf1 ghq, sort lwidth(medthick)) ///
    (line cdf2 ghq, sort lwidth(medthick)) ///
    (line cdf3 ghq, sort lwidth(medthick)), ///
    title("GHQ-12 Likert total score (0–36)", size(small)) ///
    subtitle("Empirical cumulative distribution by age group", size(vsmall)) ///
    xtitle("GHQ total score") ///
    ytitle("Cumulative percent") ///
    xlabel(0(5)35, labsize(vsmall)) ///
    ylabel(0(20)100, angle(horizontal) labsize(vsmall) nogrid) ///
    yscale(range(0 100)) ///
    legend(order(1 "Young (<=25)" 2 "Mid (26–44)" 3 "Senior (>=45)") ///
           cols(1) pos(6) ring(0) region(lstyle(none))) ///
    graphregion(color(white) margin(l=14 r=2 t=2 b=2)) ///
    plotregion(color(white) margin(small))

twoway ///
    (line cdf1 ghq if ghq <= 16, sort lcolor(forest_green) lpattern(solid)     lwidth(medthick)) ///
    (line cdf2 ghq if ghq <= 16, sort lcolor(orange_red)   lpattern(dash)      lwidth(medthick)) ///
    (line cdf3 ghq if ghq <= 16, sort lcolor(navy)         lpattern(shortdash) lwidth(medthick)), ///
    xtitle("GHQ total score") ///
    ytitle("Cumulative percent") ///
    xlabel(0(2)16, labsize(vsmall)) ///
    ylabel(0(10)90, angle(horizontal) labsize(vsmall) nogrid) ///
    xscale(range(0 16)) ///
    yscale(range(0 90)) ///
    legend(order(1 "Young (<=25)" 2 "Mid (26–44)" 3 "Senior (>=45)") ///
           cols(1) pos(3) ring(0) region(lstyle(none))) ///
    graphregion(color(white)) ///
    plotregion(color(white))

	
	

* CDF by age group — SAME SCALE as gender figure
twoway ///
    (line cdf1 ghq, sort lcolor(forest_green) lpattern(solid)     lwidth(medthick)) ///
    (line cdf2 ghq, sort lcolor(orange_red)   lpattern(dash)      lwidth(medthick)) ///
    (line cdf3 ghq, sort lcolor(navy)         lpattern(shortdash) lwidth(medthick)), ///
    title("GHQ-12 Likert total score (0–36)", size(small)) ///
    subtitle("Empirical cumulative distribution by age group", size(vsmall)) ///
    xtitle("GHQ total score") ///
    ytitle("Cumulative percent") ///
    xlabel(0(5)35, labsize(vsmall)) ///
    ylabel(0(20)100, angle(horizontal) labsize(vsmall) nogrid) ///
    xscale(range(0 36)) ///
    yscale(range(0 100)) ///
    legend(order(1 "Young (<=25)" 2 "Mid (26–44)" 3 "Senior (>=45)") ///
           cols(1) pos(6) ring(0) region(lstyle(none))) ///
    graphregion(color(white) margin(l=14 r=2 t=2 b=2)) ///
    plotregion(color(white) margin(small))


















	
//////////////
use ind_ghq_lfs, clear
xtset pidp idate
drop if year == 2024 
drop if scghqa<0 | scghqb<0 | scghqc<0 | scghqd<0 | scghqe<0 | scghqf<0 | scghqg<0 | scghqh<0 | scghqi<0 | scghqj<0 | scghqk<0 | scghql<0

capture drop agegrp
gen byte agegrp = .
replace agegrp = 1 if !missing(dvage) & dvage <= 25
replace agegrp = 2 if !missing(dvage) & inrange(dvage, 26, 44)
replace agegrp = 3 if !missing(dvage) & dvage >= 45

label define agegrp_lbl 1 "Young (<=25)" 2 "Mid (26–44)" 3 "Senior (>=45)", replace
label values agegrp agegrp_lbl
label var agegrp "Age group"

save ghq_sample, replace

//////////////////////////

use ghq_sample,clear 


*newjob 
reg newjob dvage age2 male lnw ghq i.year, vce(cluster pidp)
outreg2 using "newjob_ghq.doc", replace ctitle("LPM: newjob on GHQ") dec(3)

xtreg newjob dvage age2 lnw ghq i.year, fe robust
outreg2 using "newjob_ghq.doc", append ctitle("FE: pidp FE + year FE") dec(3)



*wage change 
reg lnw_diff dvage age2 male lnw ghq i.year, vce(cluster pidp)
outreg2 using "lnw_diff_ghq.doc", replace ctitle("LPM: newjob on GHQ") dec(3)

xtreg lnw_diff dvage age2 lnw ghq i.year, fe robust
outreg2 using "lnw_diff_ghq.doc", append ctitle("FE: pidp FE + year FE") dec(3)






















