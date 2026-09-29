version 16.0
clear all
set more off

/*
O*NET stress-tolerance requirements and occupational transition direction.
Inputs: Stress_Tolerance.xlsx; 2019_ONET_to_UK_SOC_Final_Crosswalk.dta;
        ghqevent.dta (unchanged).

CURRENT-DATA ROUTE: exploratory SOC2000 proxy using a sample-derived bridge.
DIRECT ROUTE: optional full-wave person panel with pidp wave jbsoc10_cc lfs.
Do NOT use F.soc10 on the event-only file: it contains waves 1, 2 and 5.

Equal weights mean:
  1. Each distinct matched O*NET occupation gets equal weight within SOC2010
     THREE-digit group. Duplicate paths through four-digit groups do not count.
  2. For the exploratory SOC2000 bridge, each distinct observed SOC2010 group
     gets equal weight within SOC2000. This is NOT an official concordance.
  3. Persons are unweighted here. Crosswalk weights are not survey weights.

The index is a fixed occupational requirement score (Impact, 0-100), not a
worker's experienced stress. Higher/lower refer to the score, not job quality.
Source: https://www.onetonline.org/find/descriptor/result/1.D.4.a
Mapping provenance: supplied import_xwalks.do, O*NET2019 -> US SOC2018 ->
US SOC2010 -> ISCO08 -> UK SOC2010. Unmatched codes are not assigned zero.

No Stata executable was available during preparation. Data calculations were
independently checked in Python; run this do-file and inspect the saved log.
*/

*-------------------------- SETTINGS -----------------------------------*
* Save this do-file and ghqevent.dta in STROOT.
* Excel and crosswalk inputs are located separately below.
global STROOT "C:/Users/hm21806/Desktop/chapter3/code202602_newjobf"
global STONET "C:/Users/hm21806/Desktop/chapter3/onet"
global STOUT "$STROOT/stress_transition_outputs"
capture mkdir "$STOUT"

* Optional: complete waves, including waves 2, 3 and 6 as destinations.
* Keep blank when only ghqevent.dta is available.
local fullpanel ""
* Example: local fullpanel "$STROOT/ukhls_allwaves.dta"

* Optional exploratory regression blocks, disabled by default.
local run_ols 0
local run_iv  0
local tol 1e-8

capture log close stresslog
log using "$STOUT/stress_transition.log", text replace name(stresslog)
confirm file "$STROOT/ghqevent.dta"
local stressfile ""
local crosswalkfile ""
* Search exact filenames; use the first existing copy in the listed order.
* Extract Crosswalks.zip first if the crosswalk is still inside the archive.
foreach folder in "$STONET" "$STROOT" ///
    "$STONET/Crosswalks" "$STROOT/Crosswalks" ///
    "C:/Users/hm21806/Desktop/chapter3/Crosswalks" ///
    "C:/Users/hm21806/Downloads/Crosswalks" ///
    "C:/Users/hm21806/Downloads" {
    if `"`stressfile'"'=="" {
        capture confirm file "`folder'/Stress_Tolerance.xlsx"
        if !_rc local stressfile "`folder'/Stress_Tolerance.xlsx"
    }
    if `"`crosswalkfile'"'=="" {
        capture confirm file "`folder'/2019_ONET_to_UK_SOC_Final_Crosswalk.dta"
        if !_rc local crosswalkfile "`folder'/2019_ONET_to_UK_SOC_Final_Crosswalk.dta"
    }
}
if `"`stressfile'"'=="" {
    display as error "Missing Stress_Tolerance.xlsx. Place it in: $STONET"
    log close stresslog
    exit 601
}
if `"`crosswalkfile'"'=="" {
    display as error "Missing 2019_ONET_to_UK_SOC_Final_Crosswalk.dta"
    display as error "Download/extract this DTA file and place it in: $STONET"
    display as error "Stress_Tolerance.xlsx is a different input and cannot replace the crosswalk."
    log close stresslog
    exit 601
}
display as text "Stress Excel: `stressfile'"
display as text "Crosswalk: `crosswalkfile'"

*------------------- 1. O*NET score and SOC2010 lookup ------------------*
import excel "`stressfile'", ///
    sheet("Browse by Work Styles") cellrange(A4) firstrow clear
rename Code onetsoc2019code
rename Impact stress_onet
keep onetsoc2019code Occupation stress_onet
replace onetsoc2019code = strtrim(onetsoc2019code)
drop if missing(onetsoc2019code)
capture confirm numeric variable stress_onet
if _rc destring stress_onet, replace
assert inrange(stress_onet,0,100) if !missing(stress_onet)
isid onetsoc2019code
tempfile onet
save `onet'

use "`crosswalkfile'", clear
keep soc2010code_uk onetsoc2019code
replace onetsoc2019code = strtrim(onetsoc2019code)
assert inrange(soc2010code_uk,1000,9999)
gen int soc10_3 = floor(soc2010code_uk/10)
keep soc10_3 onetsoc2019code
duplicates drop soc10_3 onetsoc2019code, force
isid soc10_3 onetsoc2019code
merge m:1 onetsoc2019code using `onet', gen(match_onet)
preserve
    keep if match_onet==2
    keep onetsoc2019code Occupation stress_onet
    export delimited using "$STOUT/onet_unmatched.csv", replace
restore
drop if match_onet==2
gen byte mapped_score = !missing(stress_onet)
bysort soc10_3: gen int n_onet_total = _N
bysort soc10_3: egen int n_onet_scored = total(mapped_score)
gen double onet_equal_weight = 1/n_onet_scored if mapped_score
save "$STOUT/onet_soc2010_3digit_links.dta", replace
collapse (mean) stress10=stress_onet ///
    (firstnm) n_onet_total n_onet_scored, by(soc10_3)
gen double onet_coverage = n_onet_scored/n_onet_total
label var stress10 "Mean O*NET stress-tolerance Impact: equal distinct O*NET weights"
isid soc10_3
save "$STOUT/stress_soc2010_3digit.dta", replace
tempfile lookup10
save `lookup10'

*------------------- 2. Sample-derived SOC2000 proxy -------------------*
* Use raw simultaneous current-job codes, NOT filled soc00/soc10 variables.
* Restrict bridge construction to employed respondents at the same interview.
use "$STROOT/ghqevent.dta", clear
isid pidp wave
tab wave, missing
count if soc10 != jbsoc10_cc & !missing(soc10)
display as text "Above: derived soc10 differs from raw current-job code."
keep if lfs==1 & inrange(jbsoc00_cc,100,999) & inrange(jbsoc10_cc,100,999)
keep jbsoc00_cc jbsoc10_cc
rename jbsoc00_cc soc00_3
rename jbsoc10_cc soc10_3
contract soc00_3 soc10_3, freq(bridge_n_personwaves)
* Frequencies retained for audit only; they are NOT used as weights.
merge m:1 soc10_3 using `lookup10', keep(master match) nogen
bysort soc00_3: gen int n_soc10_links = _N
bysort soc00_3: egen int n_soc10_scored = count(stress10)
gen double bridge_equal_weight = 1/n_soc10_scored if !missing(stress10)
label var bridge_equal_weight "Equal weight across distinct scored SOC2010 groups"
save "$STOUT/empirical_soc2000_soc2010_bridge.dta", replace
collapse (mean) stress00_proxy=stress10 ///
    (sd) bridge_sd=stress10 (min) bridge_min=stress10 ///
    (max) bridge_max=stress10 ///
    (firstnm) n_soc10_links n_soc10_scored, by(soc00_3)
gen double bridge_coverage = n_soc10_scored/n_soc10_links
label var stress00_proxy "Exploratory SOC2000 score: sample-derived equal-weight bridge"
isid soc00_3
save "$STOUT/stress_soc2000_EMPIRICAL_PROXY.dta", replace
tempfile proxy_origin proxy_dest
preserve
    rename soc00_3 st_occ_t
    rename stress00_proxy st_score_t
    rename (n_soc10_links n_soc10_scored bridge_coverage) ///
        (st_links_t st_scored_t st_coverage_t)
    drop bridge_sd bridge_min bridge_max
    save `proxy_origin'
restore
rename soc00_3 st_occ_f
rename stress00_proxy st_score_f
rename (n_soc10_links n_soc10_scored bridge_coverage) ///
    (st_links_f st_scored_f st_coverage_f)
drop bridge_sd bridge_min bridge_max
save `proxy_dest'

*------------------- 3. Common transition-analysis programme -----------*
capture program drop st_analyse
program define st_analyse
    syntax, TAG(string) TOL(real) OLS(integer) IV(integer)
    * st_pair is route-specific and never treats a missing destination as zero.
    gen double st_delta = st_score_f-st_score_t if st_pair
    gen byte st_occ_change = (st_occ_t!=st_occ_f) if st_pair
    gen byte st_down = (st_delta < -`tol') if st_pair
    gen byte st_up = (st_delta > `tol') if st_pair
    gen byte st_equal = (abs(st_delta)<=`tol') if st_pair
    assert st_down+st_up+st_equal==1 if st_pair
    assert abs(st_delta)<=`tol' if st_pair & st_occ_change==0

    * Four categories separate staying in an occupation from an equal-score move.
    gen byte st_direction = 0 if st_pair & st_occ_change==0
    replace st_direction = 1 if st_occ_change==1 & st_down==1
    replace st_direction = 2 if st_occ_change==1 & st_equal==1
    replace st_direction = 3 if st_occ_change==1 & st_up==1
    label define stdir 0 "Same occupation" 1 "Move to lower score" ///
        2 "Different occupation, equal score" 3 "Move to higher score", replace
    label values st_direction stdir
    label var st_delta "Destination minus origin stress-tolerance score"
    label var st_occ_change "Occupation codes differ across endpoints"
    label var st_down "Lower-score destination; same occupation counts as zero"
    label var st_up "Higher-score destination; same occupation counts as zero"

    * Tolerance sensitivity: scores within 5 points are treated as similar.
    gen byte st_direction5 = 0 if st_pair & st_occ_change==0
    replace st_direction5 = 1 if st_occ_change==1 & st_delta < -5
    replace st_direction5 = 2 if st_occ_change==1 & abs(st_delta)<=5
    replace st_direction5 = 3 if st_occ_change==1 & st_delta > 5 & st_delta<.
    label define stdir5 0 "Same occupation" 1 "Lower by more than 5" ///
        2 "Different occupation, within 5" 3 "Higher by more than 5", replace
    label values st_direction5 stdir5

    * Existing newocc may impose additional restrictions (e.g. job change).
    * Keep that definition separate; do not silently overwrite it.
    gen byte st_oldnewocc_sample = st_pair & newocc==1
    gen byte st_confirmed_jobmove = st_pair & st_occ_change==1 & newjob==1
    tab newocc st_occ_change if st_pair, missing
    tab st_direction if st_pair, missing
    tab st_direction if st_occ_change==1, missing
    tab st_direction if st_oldnewocc_sample, missing
    tab st_direction if st_confirmed_jobmove, missing
    tab wave st_pair, row
    summarize st_score_t st_score_f st_delta if st_pair, detail
    summarize st_delta if st_occ_change==1, detail
    save "$STOUT/transitions_`tag'.dta", replace

    quietly count if st_pair
    if r(N)==0 {
        display as error "No usable pairs in `tag'; check destination data and coverage."
        exit
    }
    preserve
        keep if st_pair
        contract wave st_direction, freq(N)
        bysort wave: egen double N_pair = total(N)
        gen double pct_all_pairs = 100*N/N_pair
        bysort wave: egen double N_movers = total(N*(st_direction!=0))
        gen double pct_movers = 100*N/N_movers if st_direction!=0 & N_movers>0
        export delimited using "$STOUT/direction_summary_`tag'.csv", replace
    restore
    preserve
        keep if st_pair
        contract st_occ_t st_occ_f st_score_t st_score_f st_delta, freq(N)
        gsort -N
        export delimited using "$STOUT/occupation_flows_`tag'.csv", replace
    restore
    quietly count if st_occ_change==1
    if r(N)>0 {
        histogram st_delta if st_occ_change==1, percent xline(0) ///
            xtitle("Destination minus origin stress-tolerance score") ///
            title("Occupational movers: `tag'") name(sthist, replace)
        graph export "$STOUT/delta_`tag'.png", replace width(1800)
    }

    * Optional regressions: condition on observed, scored endpoints, NOT movers.
    * Conditioning on employment/observability may induce selection. The proxy
    * also contains generated-index uncertainty not captured by these SEs.
    * Conventional IV SEs are NOT weak-IV-robust inference.
    if `ols'==1 | `iv'==1 {
        replace ghq=. if ghq<0
        local X "lnw dvage age2 male i.year"
        foreach y in st_delta st_down st_up {
            if `ols'==1 {
                capture noisily regress `y' ghq `X' if st_pair, vce(cluster pidp)
                if !_rc estimates save "$STOUT/ols_`y'_`tag'.ster", replace
            }
            if `iv'==1 {
                capture noisily ivregress 2sls `y' `X' (ghq=deathfam) ///
                    if st_pair, vce(cluster pidp)
                if !_rc {
                    estimates save "$STOUT/iv_`y'_`tag'.ster", replace
                    estat firststage
                }
            }
        }
    }
end

*------------------- 4. Usable now: exploratory SOC2000 route -----------*
use "$STROOT/ghqevent.dta", clear
gen int st_occ_t = soc00 if inrange(soc00,100,999)
gen int st_occ_f = fsoc00 if inrange(fsoc00,100,999)
merge m:1 st_occ_t using `proxy_origin', keep(master match) nogen
merge m:1 st_occ_f using `proxy_dest', keep(master match) nogen
* fsoc00 is inherited from the user's upstream construction. Its t+1 label
* cannot establish that wave gaps were excluded. Verify upstream before paper use.
* lfs_f is NOT used: its variable label says previous interview, so timing is unclear.
gen byte st_pair = lfs==1 & !missing(st_occ_t,st_occ_f,st_score_t,st_score_f)
gen str32 st_method = "SOC2000_EMPIRICAL_PROXY"
st_analyse, tag(SOC2000_PROXY) tol(`tol') ols(`run_ols') iv(`run_iv')

*------------------- 5. Optional direct SOC2010 route ------------------*
if `"`fullpanel'"'!="" {
    confirm file `"`fullpanel'"'
    use pidp wave jbsoc10_cc lfs using `"`fullpanel'"', clear
    isid pidp wave
    assert wave==floor(wave) & !missing(wave)
    gen int soc10_3=jbsoc10_cc if inrange(jbsoc10_cc,100,999) & lfs==1
    merge m:1 soc10_3 using `lookup10', keep(master match) nogen
    keep pidp wave lfs soc10_3 stress10
    tempfile direct_origin direct_dest
    preserve
        rename (lfs soc10_3 stress10) (st_lfs_t st_occ_t st_score_t)
        save `direct_origin'
    restore
    rename (lfs soc10_3 stress10) (st_lfs_f st_occ_f st_score_f)
    * Merge wave t+1 onto event wave t; no bridging of missing waves.
    gen int st_wave_f=wave
    replace wave=wave-1
    save `direct_dest'
    use "$STROOT/ghqevent.dta", clear
    isid pidp wave
    merge 1:1 pidp wave using `direct_origin', keep(master match) nogen
    merge 1:1 pidp wave using `direct_dest', keep(master match) gen(st_dest_merge)
    assert st_wave_f==wave+1 if st_dest_merge==3
    gen byte st_pair = st_lfs_t==1 & st_lfs_f==1 & ///
        !missing(st_occ_t,st_occ_f,st_score_t,st_score_f)
    gen str32 st_method = "SOC2010_DIRECT"
    st_analyse, tag(SOC2010_DIRECT) tol(`tol') ols(`run_ols') iv(`run_iv')
}
else {
    display as text "Direct SOC2010 analysis not run: fullpanel is blank."
    display as text "Current results use a sample-derived SOC2000 proxy, not an official crosswalk."
}
log close stresslog
