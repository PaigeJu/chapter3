clear all
set more off



use ghqevent_nodrop,clear 
//haven't dealed with the negative GHQ 

preserve
duplicates drop pidp , force 
sum pidp 
tab male
restore


*drop unavailable
tab refusal  //0.3%
tab dontknow  //61%
tab nothing  //15%

tab proxy  //0
tab inapplicable if wave==1 //73%

drop if refusal==1 


* conflict answer
count if nothing==1 & anyevent==1  //24
// br pidp event1 event2 event3 event4 impevent1 impevent2 impevent3 impevent4 ghq if nothing==1 & anyevent==1
replace nothing=0 if  anyevent==1

tab anyevent  //58% report at least one event 
*------------------------------------------------------------
* 0) Sample restriction 
*------------------------------------------------------------
keep if inlist(wave,1,2,5)
drop if refusal==1   

*------------------------------------------------------------
* 1) Construct domain indicators (non-mutually exclusive)
*------------------------------------------------------------
gen byte d_health = (ill | hospitalisation | accident | tests | mobilityloss | recovery | healthnec)
label var d_health "Health"

gen byte d_caring = (caring | babysit)
label var d_caring "Caring responsibilities"

gen byte d_education = (schoolstart | schoolleave | furtherstart | furtherleave | quals | studytravel | educnec)
label var d_education "Education"

gen byte d_work = (jobchange | jobplan | jobget | worktrain | redundant | retire | worktravel | workprob | jobsnec)
label var d_work "Work and jobs"

gen byte d_leisure = (vacation | leisure | drive | political | worldevent)
label var d_leisure "Leisure and civic"

gen byte d_family = (friendbeg | friendend | friends | neighbour | nonfamrel | pregnancy | cohabit | engage | ///
                     divorce | leavehome | death | anniversary | birthday | godparent | relatives | familyday | ///
                     familyprob | domestic | pets | familyoth | deathfam)
label var d_family "Family and relationships"

gen byte d_finance = (moneyprob | forcedmove | finimprove | receivemoney | finoth | vehicle | housebuy | repairs | ///
                      prize | present | purchases | moved | moveintend | reshome | movein)
label var d_finance "Finance and housing"

gen byte d_crime = (crime | troublewithpolice)
label var d_crime "Crime and legal issues"

gen byte d_religion = (religionchg | religionoth)
label var d_religion "Religion"

gen byte d_other = (plannot | court | otherlow)
label var d_other "Other"

local domains d_health d_caring d_education d_work d_leisure d_family d_finance d_crime d_religion d_other

drop d_children

save ghqevent, replace




///////////////////////////data cleaning is done//////////////////////////////
*** 
use ghqevent, clear

* Restrict to waves 1, 2, 5 and drop refusals
keep if inlist(wave,1,2,5)
drop if refusal==1

* Collect domain variables (all numeric variables starting with d_)
ds d_*, has(type numeric)
local domains `r(varlist)'

* Drop non-domain variables if accidentally matched by d_*
* (edit this line if you have other non-domain d_* variables)
local domains : list domains - d_indinub_xw

* Check the local macro (DO NOT use "macro list domains")
display "`domains'"

preserve
tempfile domprev
tempname post
postfile `post' str60 domain double prev using "`domprev'", replace

foreach d of local domains {
    quietly summarize `d', meanonly

    local lbl : variable label `d'
    if "`lbl'"=="" local lbl "`d'"

    post `post' ("`lbl'") (100*r(mean))
}
postclose `post'

use "`domprev'", clear
drop if missing(prev)
gsort -prev

set scheme s1color
graph hbar prev, ///
    over(domain, sort(1) descending label(labsize(small))) ///
    ytitle("") ///
    title("Prevalence of reported life-event domains (Waves 1, 2 and 5)", size(small)) ///
    subtitle("Percent of person-wave observations; domains are not mutually exclusive", size(vsmall)) ///
    bar(1, color(eltblue%55) lcolor(eltblue%85) lwidth(vthin)) ///
    graphregion(color(white)) plotregion(color(white)) ///
    ylabel(, angle(horizontal) labsize(small) nogrid)

restore







*/




*pooled 
use ghqevent,clear 
drop if ghq < 0

local evlist ///
    ill hospitalisation accident tests mobilityloss recovery healthnec ///
    caring babysit ///
    schoolstart schoolleave furtherstart furtherleave quals studytravel educnec ///
    jobchange jobplan jobget worktrain redundant retire worktravel workprob jobsnec ///
    vacation leisure drive political worldevent ///
    friendbeg friendend friends neighbour nonfamrel pregnancy cohabit engage divorce leavehome death anniversary birthday godparent ///
    relatives familyday familyprob domestic pets ///
    familyoth moneyprob forcedmove finimprove receivemoney finoth vehicle housebuy repairs prize present purchases ///
    moved moveintend reshome movein ///
    crime religionchg religionoth plannot court otherlow

// sum `evlist'	
	
reg ghq `evlist' i.wave, vce(cluster pidp)
outreg2 using "lifeevent.doc", replace ctitle("OLS: GHQ on life event") dec(3)





*******************graph********************************


*graph1 : coefficient of events
preserve

matrix b = e(b)
matrix V = e(V)

tempfile coefdata
postfile hh str40 varname str200 varlab double beta se lo hi pval using "`coefdata'", replace

foreach v of local evlist {
    local col = colnumb(b, "`v'")
    if `col' < . {
        scalar bb = b[1,`col']
        scalar ss = sqrt(V[`col',`col'])
        scalar ll = bb - 1.96*ss
        scalar uu = bb + 1.96*ss
        scalar tt = bb/ss
        scalar pp = 2*ttail(e(df_r), abs(tt))

        local lab : variable label `v'
        if "`lab'"=="" local lab "`v'"

        post hh ("`v'") ("`lab'") (bb) (ss) (ll) (uu) (pp)
    }
}
postclose hh
use "`coefdata'", clear

* Option A: only significant
keep if pval < 0.05
* Option B (recommended for transparency): plot all
* keep if !missing(beta)

* Sort by effect size (absolute) or by beta
gen absb = abs(beta)
gsort -absb
gen order = _n

* Build y-axis labels
levelsof order, local(ords)
local yspec
foreach o of local ords {
    local lbl "`=varlab[`o']'"
    local yspec `yspec' `o' "`lbl'"
}

set scheme s1color

twoway ///
    (rcap lo hi order, horizontal lcolor(eltblue%85) lwidth(thin)) ///
    (scatter order beta, mcolor(eltblue%85) msymbol(O) msize(small)), ///
    xline(0, lpattern(dash) lcolor(gs8)) ///
    ylabel(`yspec', angle(0) labsize(vsmall) nogrid) ///
    xtitle("Coefficient on event indicator (GHQ points)", size(small)) ///
    ytitle("") ///
    title("Life events and GHQ-12: conditional associations", size(medsmall)) ///
    subtitle("OLS with wave fixed effects; 95% CI; SEs clustered by individual", size(vsmall)) ///
    legend(off) ///
    plotregion(color(white) margin(small)) ///
    graphregion(color(white) margin(l=40 r=10 t=10 b=10)) ///
    xsize(12) ysize(7)


	
	
	
/////////////////////////////////	
* pooled and event specific estimation 
use ghqevent,clear 
drop if ghq < 0

global X "lnw dvage age2 male i.year"

local evlist ///
    ill hospitalisation accident tests mobilityloss recovery healthnec ///
    caring babysit ///
    schoolstart schoolleave furtherstart furtherleave quals studytravel educnec ///
    jobchange jobplan jobget worktrain redundant retire worktravel workprob jobsnec ///
    vacation leisure drive political worldevent ///
    friendbeg friendend friends neighbour nonfamrel pregnancy cohabit engage divorce leavehome death anniversary birthday godparent ///
    relatives familyday familyprob domestic pets ///
    familyoth moneyprob forcedmove finimprove receivemoney finoth vehicle housebuy repairs prize present purchases ///
    moved moveintend reshome movein ///
    crime religionchg religionoth plannot court otherlow

capture postclose memhold
tempfile results

postfile memhold ///
    str20 event ///
    double b se t p ll ul N ///
    using `results', replace

foreach ev of local evlist {
    quietly regress ghq `ev' $X i.wave, vce(cluster pidp)

    * store the full estimation result in memory
    estimates store m_`ev'

    * extract coefficient, SE, p-value, and 95% CI for the event variable
    local b  = _b[`ev']
    local se = _se[`ev']
    local t  = `b' / `se'
    local p  = 2*ttail(e(df_r), abs(`t'))
    local crit = invttail(e(df_r), 0.025)
    local ll = `b' - `crit'*`se'
    local ul = `b' + `crit'*`se'

    post memhold ("`ev'") (`b') (`se') (`t') (`p') (`ll') (`ul') (e(N))
}

postclose memhold

use `results', clear
sort p
list, clean


* Option A: only significant
keep if p < 0.05

* Option B: plot all
* keep if !missing(b)

* Create a nicer label variable (initially same as event)
gen evlabel = event

* If you want, manually rename some labels for presentation
replace evlabel = "Illness/injury"          if event == "ill"
replace evlabel = "Hospitalisation"         if event == "hospitalisation"
replace evlabel = "Accident"                if event == "accident"
replace evlabel = "Tests/exams"             if event == "tests"
replace evlabel = "Mobility loss"           if event == "mobilityloss"
replace evlabel = "Recovery"                if event == "recovery"
replace evlabel = "Health-related necessity" if event == "healthnec"
replace evlabel = "Caring responsibilities" if event == "caring"
replace evlabel = "Babysitting"             if event == "babysit"
replace evlabel = "Job change"              if event == "jobchange"
replace evlabel = "Redundancy"              if event == "redundant"
replace evlabel = "Retirement"              if event == "retire"
replace evlabel = "Work-related problem"    if event == "workprob"
replace evlabel = "Leisure"                 if event == "leisure"
replace evlabel = "Vacation"                if event == "vacation"
replace evlabel = "Friendship began"        if event == "friendbeg"
replace evlabel = "Friendship ended"        if event == "friendend"
replace evlabel = "Pregnancy"               if event == "pregnancy"
replace evlabel = "Cohabitation"            if event == "cohabit"
replace evlabel = "Engagement"              if event == "engage"
replace evlabel = "Divorce/separation"      if event == "divorce"
replace evlabel = "Family death"            if event == "death"
replace evlabel = "Birthday"                if event == "birthday"
replace evlabel = "Family problems"         if event == "familyprob"
replace evlabel = "Money problems"          if event == "moneyprob"
replace evlabel = "Forced move"             if event == "forcedmove"
replace evlabel = "Move residence"          if event == "moved"
replace evlabel = "Crime victimisation"     if event == "crime"
replace evlabel = "Court appearance"        if event == "court"
replace evlabel = "Other low event"         if event == "otherlow"

* Sort by absolute effect size
gen absb = abs(b)
gsort -absb

* Order for plotting
gen order = _n

* Build y-axis labels from evlabel
levelsof order, local(ords)
local yspec
foreach o of local ords {
    levelsof evlabel if order == `o', local(lbl)
    local yspec `yspec' `o' `"`lbl'"'
}

set scheme s1color

twoway ///
    (rcap ll ul order, horizontal lcolor(eltblue%85) lwidth(thin)) ///
    (scatter order b, mcolor(eltblue%85) msymbol(O) msize(small)), ///
    xline(0, lpattern(dash) lcolor(gs8)) ///
    ylabel(`yspec', angle(0) labsize(vsmall) nogrid) ///
    xtitle("Coefficient on event indicator (GHQ points)", size(small)) ///
    ytitle("") ///
    title("Life events and GHQ-12: single-event associations", size(medsmall)) ///
    subtitle("OLS with wave fixed effects; 95% CI; SEs clustered by individual", size(vsmall)) ///
    legend(off) ///
    plotregion(color(white) margin(small)) ///
    graphregion(color(white) margin(l=40 r=10 t=10 b=10)) ///
    xsize(12) ysize(7)





ex

*** IV 

* deathfam 
tab deathfam  //6.5%
reg newjob ghq lnw male dvage age2 i.year, vce(cluster pidp)


ivregress 2sls newjob lnw dvage age2 male i.year (ghq = deathfam), vce(cluster pidp)
estat firststage

outreg2 using "newjob_ghq.doc", replace ctitle("LPM: newjob on GHQ") dec(3)









