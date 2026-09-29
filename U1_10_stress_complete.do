version 16.0
clear all
set more off
/* CHAPTER 3: occupational requirements, wages and outward transitions.
   Original input files are never overwritten. No external Stata packages.
   Baseline: adjacent waves, positive interview-date gap, raw occupation codes,
   paid employees/self-employed (jbstat 1 or 2) at origin. Maternity leave and
   other attachment/ambiguous statuses are UNKNOWN, not nonemployment.
   Explicit nonemployment: unemployed, retired, family care, student, LT sick.
   Scores: equal DISTINCT O*NET codes per SOC2010 three-digit occupation.
   SOC2000_PROXY: equal distinct SOC2010 groups per raw co-coded SOC2000 group.
   This empirical bridge is NOT an official concordance.
   Job Zone shares describe preparation requirements, not measured skills.
   All headline results unweighted; origin survey-weight sensitivity separate.
   Wave pairs are not exact calendar years; no annualisation is performed.
   Associations are descriptive, not causal. No automatic IV estimation.
   INPUTS/OUTPUTS AND INTERPRETATION
   - Place this DO and ind_ghq_lfs.dta under ROOT. Excel and crosswalk under ONET.
   - Run the WHOLE do-file. Derived panels, graphs, CSVs and log go under OUT.
   - direction: 0 same occupation; 1 lower; 2 different/equal; 3 higher.
   - delta: destination minus origin; never interpreted as experienced stress.
   - outflow_by_wave: n_leave/n_risk includes other occupation OR nonemployment.
     n_other/n_risk and n_nonemp/n_risk separate those margins.
     n_change_ee/n_ee is occupational switching conditional on two employed ends.
   - outflow_pooled: pooled_pct_leave = ratio of summed counts;
     mean_wave_pct_leave = equal mean of nonmissing wave-specific percentages.
     No netting of inflows. Each person may contribute several wave transitions.
   - weighted outflow uses origin cross-sectional weight as sensitivity only;
     it is not a longitudinal nonresponse correction or complex-survey estimate.
   - Wage: nominal labour income / (reported weekly hours * 52/12), employees
     only. It excludes overtime hours and is an approximation, not a validated
     earnings measure. Year effects absorb common inflation; no real-wage claim.
   - stress10 regression coefficients refer to a TEN-point score difference.
   - Job Zone category shares sum to one; omit zone12 as reference. No numeric
     midpoint is assigned to the combined 1-2 category. Education is categorical.
   - Degree share is worker composition, not an occupational skill requirement.
   - Wage/exit regressions cluster by origin occupation, not simultaneously by
     person. GHQ associations cluster by person. These are descriptive models.
   - Correlations CSV: equal occupational weight, pairwise available cases.
   - Domain FE/within-domain modules run only with a user-provided validated map.
     SOC major groups are NOT treated as skill domains. Continuous skill_*
     variables are optional; their definitions/units must be documented by user.
   - Raw SOC2010 has NO coverage in waves 1 and 2; eventwave direct route thus
     largely concerns wave 5. Proxy results are explicitly separate.
   - Crosswalk version mismatches/unmatched O*NET occupations remain missing.
     The SOC2000 bridge uses all observed co-coded employed person-waves and is
     exploratory. Equal weight does not eliminate concordance measurement error.
   - Main raw-code comparisons can include coding changes. Independent job-move
     evidence is reported separately; same-job contradictions are excluded there.
   - Old newocc definitions retained for comparison only, never overwritten.
   - MODEL FAILED messages identify regressions without usable sample/variation.
   - No causal interpretation or automatically selected life-event instruments.
   Sources: https://www.onetonline.org/help/online/zones
            https://www.onetonline.org/find/descriptor/result/1.D.4.a
   Prepared from supplied files; no Stata executable available for execution.
*/
global ROOT "C:/Users/hm21806/Desktop/chapter3/code202602_newjobf"
global ONET "C:/Users/hm21806/Desktop/chapter3/onet"
global OUT "$ROOT/stress_complete_outputs"
capture mkdir "$OUT"
* Optional REAL skill/domain file (CSV). Leave blank until supplied.
* Required: soc_version (2000/2010), occ3, domain_id (positive integer).
* Optional: numeric skill_* columns with genuine measured skill indices.
* One row per soc_version x occ3. Do NOT supply a SOC2000 map as SOC2010.
local domainfile ""
local tol 1e-8
capture log close stresscomplete
log using "$OUT/analysis.log", text replace name(stresscomplete)
confirm file "$ROOT/ind_ghq_lfs.dta"
local excel ""
local xwalk ""
foreach dir in "$ONET" "$ROOT" "$ONET/Crosswalks" "$ROOT/Crosswalks" {
    capture confirm file "`dir'/Stress_Tolerance.xlsx"
    if !_rc & `"`excel'"'=="" local excel "`dir'/Stress_Tolerance.xlsx"
    capture confirm file "`dir'/2019_ONET_to_UK_SOC_Final_Crosswalk.dta"
    if !_rc & `"`xwalk'"'=="" local xwalk "`dir'/2019_ONET_to_UK_SOC_Final_Crosswalk.dta"
}
if `"`excel'"'=="" | `"`xwalk'"'=="" {
    di as error "Place Stress_Tolerance.xlsx and the final crosswalk DTA in $ONET"
    exit 601
}

* 1. O*NET lookup: retain Job Zone as categorical shares (no arbitrary midpoint).
import excel "`excel'", sheet("Browse by Work Styles") cellrange(A4) firstrow clear
rename Code onetsoc2019code
rename Impact stress_onet
rename JobZone zone_text
capture confirm string variable zone_text
if _rc tostring zone_text, replace
replace zone_text = strtrim(zone_text)
assert inlist(zone_text,"1-2","3","4","5") if !missing(zone_text)
foreach z in 12 3 4 5 {
    local ztext "`z'"
    if `z'==12 local ztext "1-2"
    gen double zone`z' = (zone_text=="`ztext'") if !missing(zone_text)
}
replace onetsoc2019code = strtrim(onetsoc2019code)
capture confirm numeric variable stress_onet
if _rc destring stress_onet, replace
assert inrange(stress_onet,0,100) if !missing(stress_onet)
drop if missing(onetsoc2019code)
isid onetsoc2019code
keep onetsoc2019code Occupation stress_onet zone12 zone3 zone4 zone5
tempfile onet lookup10 lookup00 bridge domains panel
save `onet'
use "`xwalk'", clear
gen int occ3 = floor(soc2010code_uk/10)
keep occ3 onetsoc2019code
replace onetsoc2019code = strtrim(onetsoc2019code)
duplicates drop occ3 onetsoc2019code, force
merge m:1 onetsoc2019code using `onet', gen(match_onet)
preserve
    keep if match_onet==2
    export delimited using "$OUT/onet_unmatched.csv", replace
restore
drop if match_onet==2
bys occ3: gen n_links=_N
bys occ3: egen n_scores=count(stress_onet)
gen equal_weight=1/n_scores if !missing(stress_onet)
save "$OUT/onet_soc2010_links.dta", replace
collapse (mean) stress=stress_onet zone12 zone3 zone4 zone5 ///
    (firstnm) n_links n_scores, by(occ3)
gen coverage=n_scores/n_links
isid occ3
save `lookup10'
save "$OUT/score_SOC2010.dta", replace
export delimited using "$OUT/score_SOC2010.csv", replace

* 2. Load only needed variables; raw occupational codes are kept unfilled.
use pidp wave idate year dvage male jbstat lfs empl jbsoc00_cc jbsoc10_cc ///
    soc00 soc10 fsoc00 newocc newjob hiqual_dv ghq scghq1_dv ///
    jbhrs fimnlabgrs_dv weightscaled jbbgd jbbgm jbbgy ///
    samejob jbsamr jbsoc00chk jbendy4 nunmpsp_dv ///
    impevent1-impevent4s event1-event4s using "$ROOT/ind_ghq_lfs.dta", clear
isid pidp wave
assert inrange(wave,1,14)
rename (newocc newjob) (newocc_old newjob_old)
gen byte employed = 1 if inlist(jbstat,1,2)
replace employed = 0 if inlist(jbstat,3,4,6,7,8)
* All other statuses remain missing: do not misclassify leave/furlough as exits.
gen byte paid = jbstat==2 if jbstat>0 & jbstat<.
gen int occ00=jbsoc00_cc if inrange(jbsoc00_cc,100,999)
gen int occ10=jbsoc10_cc if inrange(jbsoc10_cc,100,999)
gen byte education=hiqual_dv if inlist(hiqual_dv,1,2,3,4,5,9)
gen byte degree = education==1 if !missing(education)
gen double ghq_clean=scghq1_dv if inrange(scghq1_dv,0,36)
* Nominal hourly wage: actual reported employee hours; no full/part-time imputation.
gen double hourly_nominal=fimnlabgrs_dv/(jbhrs*52/12) ///
    if paid==1 & fimnlabgrs_dv>0 & fimnlabgrs_dv<. & jbhrs>0 & jbhrs<.
gen double log_hourly=ln(hourly_nominal)
* Job start date: no imputed day/month; used only as supplementary evidence.
gen double start_raw=mdy(jbbgm,jbbgd,jbbgy) ///
    if inrange(jbbgm,1,12) & inrange(jbbgd,1,31) & inrange(jbbgy,1900,2100)
format start_raw %td
* Diagnostics on old construction.
tab lfs empl, missing
count if soc10!=jbsoc10_cc & !missing(soc10)
di "Filled SOC2010 differs from raw: " r(N)
count if newocc_old==1 & newjob_old==0

* Preserve all waves before generating leads; F. cannot cross a missing wave.
xtset pidp wave
foreach v in idate employed paid occ00 occ10 hourly_nominal log_hourly ///
    samejob jbsamr jbsoc00chk start_raw jbendy4 {
    gen double f_`v'=F.`v'
}
gen byte consecutive=!missing(f_idate,idate) & f_idate>idate
gen double gap_months=(f_idate-idate)/30.4375 if consecutive
* A sensitivity marker, not an assumption of exactly annual interviews.
gen byte usual_gap=consecutive & inrange(gap_months,6,18)
gen byte ee=consecutive & employed==1 & f_employed==1
gen byte status_pair=consecutive & employed==1 & !missing(f_employed)
* Independent job-move evidence; occupational-description changes alone excluded.
gen byte job_yes=(f_samejob==2 | f_jbsamr==2 | ///
    (f_start_raw>idate & f_start_raw<=f_idate & !missing(f_start_raw))) if ee
gen byte job_no=(f_samejob==1 | f_jbsamr==1) if ee
gen byte job_conflict=job_yes==1 & job_no==1 if ee
gen byte job_verified=job_yes==1 & job_no==0 if ee
* Event-wave flag is imposed only AFTER leads exist.
gen byte eventwave=inlist(wave,1,2,5)
compress
save `panel'

* 3. Empirical SOC2000 bridge, using raw contemporaneous employed codes only.
keep if employed==1 & !missing(occ00,occ10)
contract occ00 occ10, freq(bridge_personwaves)
rename occ10 occ3
merge m:1 occ3 using `lookup10', keep(master match) nogen
save "$OUT/empirical_SOC2000_SOC2010_bridge.dta", replace
bys occ00: gen n_bridge=_N
bys occ00: egen n_bridge_scored=count(stress)
collapse (mean) stress zone12 zone3 zone4 zone5 ///
    (firstnm) n_bridge n_bridge_scored, by(occ00)
rename occ00 occ3
gen coverage=n_bridge_scored/n_bridge
save `lookup00'
save "$OUT/score_SOC2000_PROXY.dta", replace

* 4. Optional true skills/domain map. An absent map never becomes a proxy domain.
local hasdomains 0
if `"`domainfile'"'!="" {
    import delimited "`domainfile'", clear varnames(1)
    confirm numeric variable soc_version occ3 domain_id
    assert inlist(soc_version,2000,2010)
    assert domain_id>0 & domain_id==floor(domain_id) if !missing(domain_id)
    isid soc_version occ3
    capture ds skill_*, has(type numeric)
    if !_rc {
        local skillvars `r(varlist)'
    }
    else local skillvars ""
    keep soc_version occ3 domain_id `skillvars'
    save `domains'
    local hasdomains 1
}
else {
    di as result "DOMAIN/SKILL MODULE PENDING: supply a validated occupation-domain map."
}

* Regression exporter: reports failure instead of silently claiming results.
tempname results
postfile `results' str28 route str50 model str40 term double b se p N ///
    using "$OUT/regression_results.dta", replace
capture program drop fit_export
program define fit_export
    syntax, HANDLE(name) ROUTE(string) MODEL(string) CMD(string)
    capture noisily `cmd'
    if _rc {
        di as error "MODEL FAILED: `route' / `model', rc=" _rc
        exit
    }
    tempname b V
    matrix `b'=e(b)
    matrix `V'=e(V)
    local terms: colnames `b'
    local j=0
    foreach term of local terms {
        local ++j
        local bb=`b'[1,`j']
        local ss=sqrt(`V'[`j',`j'])
        local pp=.
        if `ss'>0 & `ss'<. local pp=2*ttail(e(df_r),abs(`bb'/`ss'))
        post `handle' ("`route'") ("`model'") ("`term'") (`bb') (`ss') (`pp') (e(N))
    }
end

* 5. Run distinct routes. Never pool direct and proxy occupational scores.
foreach route in SOC2010 SOC2000_PROXY {
    local code occ10
    local ver 2010
    local lookup `lookup10'
    if "`route'"=="SOC2000_PROXY" {
        local code occ00
        local ver 2000
        local lookup `lookup00'
    }
    use `panel', clear
    gen int occ3=`code'
    gen int dest_occ=f_`code'
    merge m:1 occ3 using `lookup', keep(master match) nogen
    rename stress stress_t
    rename coverage coverage_t
    preserve
        use `lookup', clear
        keep occ3 stress coverage
        rename (occ3 stress coverage) (dest_occ stress_f coverage_f)
        tempfile destination
        save `destination'
    restore
    merge m:1 dest_occ using `destination', keep(master match) nogen
    local skills ""
    if `hasdomains' {
        gen int soc_version=`ver'
        merge m:1 soc_version occ3 using `domains', keep(master match) nogen
        capture ds skill_*, has(type numeric)
        if !_rc local skills `r(varlist)'
        preserve
            use `domains', clear
            keep if soc_version==`ver'
            keep occ3 domain_id
            rename (occ3 domain_id) (dest_occ domain_f)
            tempfile df
            save `df'
        restore
        merge m:1 dest_occ using `df', keep(master match) nogen
    }
    gen byte occ_pair=ee & !missing(occ3,dest_occ)
    gen byte occ_change=occ3!=dest_occ if occ_pair
    gen byte score_pair=occ_pair & !missing(stress_t,stress_f)
    gen double delta=stress_f-stress_t if score_pair
    gen byte direction=0 if score_pair & occ_change==0
    replace direction=1 if score_pair & occ_change==1 & delta < -`tol'
    replace direction=2 if score_pair & occ_change==1 & abs(delta)<=`tol'
    replace direction=3 if score_pair & occ_change==1 & delta > `tol'
    label define direction_lbl 0 "Same occupation" 1 "Lower score" ///
        2 "Different occupation, equal score" 3 "Higher score", replace
    label values direction direction_lbl
    gen byte direction5=direction
    replace direction5=2 if score_pair & occ_change==1 & abs(delta)<=5
    label values direction5 direction_lbl
    assert abs(delta)<`tol' if score_pair & occ_change==0
    gen byte confirmed_mover=occ_change==1 & job_verified==1
    gen byte old_mover=newocc_old==1 & score_pair
    * Exit definitions: exclude unknown employed destinations from ALL-exit denominator.
    gen byte risk_all=status_pair & !missing(occ3) & ///
        (f_employed==0 | !missing(dest_occ))
    gen byte leave_occ=(f_employed==0 | (f_employed==1 & dest_occ!=occ3)) if risk_all
    gen byte nonemp_exit=f_employed==0 if risk_all
    gen byte other_occ_exit=f_employed==1 & dest_occ!=occ3 if risk_all
    gen byte retained= f_employed==1 & dest_occ==occ3 if risk_all
    assert leave_occ==nonemp_exit+other_occ_exit if risk_all
    assert retained+leave_occ==1 if risk_all
    gen byte unknown_status=employed==1 & !status_pair
    gen byte unknown_dest=status_pair & f_employed==1 & missing(dest_occ)
    gen byte st_down=direction==1 if score_pair
    gen byte st_up=direction==3 if score_pair
    gen double stress10=stress_t/10
    gen byte wage_sample=paid==1 & !missing(log_hourly,stress_t)
    * Main effects cluster by origin occupation: score varies at this level.
    * Longitudinal transition/GHQ models below cluster by person.
    fit_export, handle(`results') route("`route'") model("wage_raw") ///
        cmd("reg log_hourly stress10 if wage_sample, vce(cluster occ3)")
    gen byte wage_common=wage_sample & !missing(education,dvage,male,year,zone3,zone4,zone5)
    fit_export, handle(`results') route("`route'") model("wage_common_year_demographics") ///
        cmd("reg log_hourly stress10 c.dvage##c.dvage i.male i.year if wage_common, vce(cluster occ3)")
    fit_export, handle(`results') route("`route'") model("wage_conditional_education_preparation") ///
        cmd("reg log_hourly stress10 i.education zone3 zone4 zone5 c.dvage##c.dvage i.male i.year if wage_common, vce(cluster occ3)")
    fit_export, handle(`results') route("`route'") model("exit_conditional_education_preparation") ///
        cmd("reg leave_occ stress10 i.education zone3 zone4 zone5 c.dvage##c.dvage i.male i.year, vce(cluster occ3)")
    foreach y in st_down st_up occ_change {
        fit_export, handle(`results') route("`route'") model("GHQ_association_`y'") ///
            cmd("reg `y' ghq_clean i.education c.dvage##c.dvage i.male i.year, vce(cluster pidp)")
    }
    local route_domains 0
    if `hasdomains' {
        quietly count if !missing(domain_id) & employed==1
        local route_domains=r(N)>0
    }
    if `route_domains' {
        gen byte within_domain=domain_id==domain_f if occ_pair & !missing(domain_id,domain_f)
        fit_export, handle(`results') route("`route'") model("wage_domainFE_skills") ///
            cmd("reg log_hourly stress10 `skills' i.domain_id i.education c.dvage##c.dvage i.male i.year if wage_sample, vce(cluster occ3)")
        fit_export, handle(`results') route("`route'") model("exit_domainFE_skills") ///
            cmd("reg leave_occ stress10 `skills' i.domain_id i.education c.dvage##c.dvage i.male i.year, vce(cluster occ3)")
        local dlevels ""
        capture quietly levelsof domain_id if !missing(domain_id) & wage_sample, local(dlevels)
        foreach dom of local dlevels {
            quietly count if wage_sample & domain_id==`dom'
            if r(N)>=30 {
                fit_export, handle(`results') route("`route'") model("wage_within_domain_`dom'") ///
                    cmd("reg log_hourly stress10 `skills' i.education c.dvage##c.dvage i.male i.year if wage_sample & domain_id==`dom', vce(cluster occ3)")
            }
        }
        preserve
            keep if employed==1 & !missing(domain_id,occ3)
            collapse (count) origin_N=pidp (mean) stress_t leave_occ occ_change, by(domain_id)
            export delimited using "$OUT/domain_outflow_`route'.csv", replace
        restore
        count if score_pair & occ_change==1 & within_domain==1
        if r(N)>0 {
            preserve
                keep if score_pair & occ_change==1 & within_domain==1
                contract domain_id direction, freq(N)
                bys domain_id: egen total=total(N)
                gen percent=100*N/total
                export delimited using "$OUT/within_domain_direction_`route'.csv", replace
            restore
        }
    }
    save "$OUT/panel_`route'.dta", replace
    tempfile rp
    save `rp'
    * Coverage exported: zero counts explicitly show waves without SOC2010.
    preserve
        gen byte row=1
        collapse (sum) N=row consecutive ee occ_pair score_pair ///
            (mean) coverage_t coverage_f, by(wave)
        export delimited using "$OUT/coverage_`route'.csv", replace
    restore
    * Coverage and old-variable consistency, shown in log.
    tab wave score_pair, missing
    tab newocc_old occ_change, missing
    tab direction if newocc_old==1, missing
    summarize gap_months if occ_pair, detail
    * Direction summaries + histograms; every record is a PERSON transition.
    foreach sample in all event verified old usual {
        local sel "score_pair & occ_change==1"
        if "`sample'"=="event" local sel "`sel' & eventwave"
        if "`sample'"=="verified" local sel "`sel' & confirmed_mover"
        if "`sample'"=="old" local sel "score_pair & newocc_old==1"
        if "`sample'"=="usual" local sel "`sel' & usual_gap"
        count if `sel'
        if r(N)>0 {
            histogram delta if `sel', percent width(2) xline(0) ///
                xtitle("Destination minus origin score (points)") ///
                title("`route': `sample'") name(delta_graph, replace)
            graph export "$OUT/delta_`route'_`sample'.png", replace width(1800)
            preserve
                keep if `sel'
                contract wave direction, freq(N)
                bys wave: egen denominator=total(N)
                gen percent=100*N/denominator
                export delimited using "$OUT/direction_`route'_`sample'.csv", replace
            restore
        }
    }
    preserve
        keep if occ_pair
        collapse (count) N=pidp (mean) delta, by(occ3 dest_occ)
        export delimited using "$OUT/flows_`route'.csv", replace
    restore
    * Origin-occupation x wave gross outflow, rates and missing-follow-up counts.
    gen byte origin=employed==1 & !missing(occ3)
    gen byte one=1
    preserve
        keep if origin
        collapse (sum) n_origin=one n_risk=risk_all n_ee=occ_pair ///
            n_leave=leave_occ n_other=other_occ_exit n_nonemp=nonemp_exit ///
            n_change_ee=occ_change n_unknown_status=unknown_status n_unknown_occ=unknown_dest ///
            (mean) stress_t, by(occ3 wave)
        gen pct_leave=100*n_leave/n_risk
        gen pct_other=100*n_other/n_risk
        gen pct_nonemp=100*n_nonemp/n_risk
        gen pct_change_ee=100*n_change_ee/n_ee
        gen followup_coverage=n_risk/n_origin
        export delimited using "$OUT/outflow_by_wave_`route'.csv", replace
        collapse (sum) n_origin n_risk n_ee n_leave n_other n_nonemp n_change_ee ///
            (mean) mean_wave_pct_leave=pct_leave stress_t, by(occ3)
        gen pooled_pct_leave=100*n_leave/n_risk
        gen pooled_pct_change_ee=100*n_change_ee/n_ee
        gen small_denominator=n_risk<30
        export delimited using "$OUT/outflow_pooled_`route'.csv", replace
        twoway scatter pooled_pct_leave stress_t if n_risk>=30, ///
            xtitle("Occupational stress-tolerance score") ytitle("Gross exit (%)")
        graph export "$OUT/stress_outflow_`route'.png", replace width(1800)
    restore
    preserve
        keep if risk_all & weightscaled>0 & weightscaled<.
        collapse (mean) leave_occ nonemp_exit other_occ_exit [aw=weightscaled], by(occ3)
        foreach v in leave_occ nonemp_exit other_occ_exit {
            replace `v'=100*`v'
        }
        export delimited using "$OUT/outflow_origin_weighted_`route'.csv", replace
    restore
    * Equal-occupation correlations: raw and year-adjusted mean log wage.
    quietly reg log_hourly i.year if wage_sample
    predict double wage_residual if e(sample), residuals
    local skillcollapse ""
    if "`skills'"!="" local skillcollapse "(firstnm) `skills'"
    preserve
        keep if employed==1 & !missing(occ3,stress_t)
        collapse (mean) stress_t zone12 zone3 zone4 zone5 degree ///
            mean_log_wage=log_hourly adjusted_log_wage=wage_residual ///
            (count) n_wage=log_hourly `skillcollapse', by(occ3)
        export delimited using "$OUT/occupation_wage_preparation_`route'.csv", replace
        tempfile occtable
        save `occtable'
        tempname corrpost
        postfile `corrpost' str40 variable double correlation N using "$OUT/correlations_`route'.dta", replace
        foreach cv in mean_log_wage adjusted_log_wage zone3 zone4 zone5 degree `skills' {
            capture correlate stress_t `cv'
            if !_rc {
                matrix CC=r(C)
                post `corrpost' ("`cv'") (CC[1,2]) (r(N))
            }
        }
        postclose `corrpost'
        use "$OUT/correlations_`route'.dta", clear
        export delimited using "$OUT/correlations_`route'.csv", replace
        use `occtable', clear
        correlate stress_t mean_log_wage adjusted_log_wage zone3 zone4 zone5 degree
        if "`skills'"!="" correlate stress_t `skills'
        twoway scatter adjusted_log_wage stress_t if n_wage>=30, ///
            xtitle("Occupational stress-tolerance score") ytitle("Year-adjusted mean log wage")
        graph export "$OUT/stress_wage_`route'.png", replace width(1800)
    restore
}
postclose `results'
use "$OUT/regression_results.dta", clear
export delimited using "$OUT/regression_results.csv", replace
log close stresscomplete
di as result "Completed. Read analysis.log and the route-specific coverage tables."
