clear all
set more off
set linesize 255

/***********************************************************************
 IAPT LSOA / OSL AUA / UKHLS / RESIDUAL-IV COMPLETE DO-FILE

 This file:
 1. Cleans the LSOA-month IAPT exposure.
 2. Draws LSOA maps for 2019/20.
 3. Aggregates LSOA exposure to OSL AUA-month.
 4. Matches it to UKHLS through hidp-wave-oslaua.
 5. Merges external local labour-market data.
 6. Residualises waiting time on local labour-market conditions.
 7. Estimates original and residualised IV models.

 IMPORTANT:
 The LSOA exposure is inherited from the CCG. It is not an observed
 LSOA-specific waiting time. The underlying variation remains CCG-month.
***********************************************************************/


/***********************************************************************
 1. PATHS
***********************************************************************/

global iaptfile ///
 "C:/Users/hm21806/Desktop/chapter3/code_iapt/lsoa_output/IAPT_CCG_month_LSOA11_exposure_only.dta"

global shpdir ///
 "C:/Users/hm21806/Desktop/chapter3/IAPT/geo/lsoa_map"

global shpbase ///
 "$shpdir/LSOA11_EW_BGC_2011"

global ukhlsdir ///
 "C:/Users/hm21806/Desktop/chapter3/UKDA-6666-stata/stata/stata13/ukhls"

global geofile ///
 "$ukhlsdir/hidp_geo.dta"

global individualfile ///
 "C:/Users/hm21806/Desktop/chapter3/code202602_newjobf/ind_ghq_lfs.dta"

global labourfile ///
 "C:/Users/hm21806/Desktop/chapter3/IAPT/labour_market/nomis_lad_month.dta"

global outdir ///
 "C:/Users/hm21806/Desktop/chapter3/IAPT/lsoa_analysis_output"

capture mkdir "$outdir"


/***********************************************************************
 2. CHECK FILES
***********************************************************************/

confirm file "$iaptfile"
confirm file "$geofile"
confirm file "$individualfile"
confirm file "$shpbase.shp"
confirm file "$shpbase.dbf"
confirm file "$shpbase.shx"
confirm file "$shpbase.prj"

display as result "Core files found."


/***********************************************************************
 3. CLEAN LSOA-MONTH IAPT EXPOSURE
***********************************************************************/

use "$iaptfile", clear

confirm variable lsoa11cd
confirm variable oslaua
confirm variable mdate
confirm variable access_6w
confirm variable delay_6w
confirm variable access_18w
confirm variable delay_18w
confirm variable over18_rate

replace lsoa11cd = upper(trim(lsoa11cd))
replace oslaua   = upper(trim(oslaua))
format mdate %tm

keep if inrange(mdate, tm(2015m7), tm(2022m6))
keep if substr(oslaua, 1, 1) == "E"

isid lsoa11cd mdate

save "$outdir/IAPT_LSOA_month_exposure_clean.dta", replace


/***********************************************************************
 4. 2019/20 LSOA MAP VALUES
***********************************************************************/

preserve

keep if inrange(mdate, tm(2019m4), tm(2020m3))

collapse (mean) access_6w delay_6w access_18w delay_18w over18_rate ///
         (count) n_months=mdate, by(lsoa11cd)

save "$outdir/IAPT_LSOA_2019_20_map_values.dta", replace

restore


/***********************************************************************
 5. CONVERT SHAPEFILE TO STATA SPATIAL DATASETS
***********************************************************************/

capture which spshape2dta
if _rc != 0 {
    display as error "spshape2dta is unavailable."
    exit 199
}

* spshape2dta requires the source shapefile and the saving() name to
* be in the current directory.  Therefore change to the shapefile folder
* and save the translated map files there.
cd "$shpdir"
spshape2dta LSOA11_EW_BGC_2011, saving("LSOA11_map") replace

confirm file "$shpdir/LSOA11_map.dta"
confirm file "$shpdir/LSOA11_map_shp.dta"


/***********************************************************************
 6. MERGE MAP POLYGONS WITH LSOA VALUES
***********************************************************************/

use "$shpdir/LSOA11_map.dta", clear

capture confirm variable lsoa11cd
if _rc != 0 {
    capture confirm variable LSOA11CD
    if !_rc rename LSOA11CD lsoa11cd
}

replace lsoa11cd = upper(trim(lsoa11cd))
isid lsoa11cd

merge 1:1 lsoa11cd using "$outdir/IAPT_LSOA_2019_20_map_values.dta"
tabulate _merge

drop if _merge == 2
drop _merge

save "$outdir/LSOA2019_20_waiting_map_ready.dta", replace


/***********************************************************************
 7. DRAW FOUR LSOA MAPS
***********************************************************************/

capture which spmap
if _rc != 0 ssc install spmap, replace

use "$outdir/LSOA2019_20_waiting_map_ready.dta", clear

spmap access_6w using "$shpdir/LSOA11_map_shp.dta", ///
    id(_ID) clmethod(quantile) clnumber(5) ///
    fcolor(Blues) ocolor(gs12 ..) osize(vthin ..) ///
    ndocolor(gs14) ///
    title("IAPT access within six weeks across LSOAs") ///
    subtitle("Mean monthly CCG rate assigned to LSOAs, 2019/20") ///
    legend(position(5) size(vsmall)) ///
    name(lsoa_access6, replace)

graph export "$outdir/LSOA_access_within_6_weeks_2019_20.png", ///
    width(2400) replace

spmap delay_6w using "$shpdir/LSOA11_map_shp.dta", ///
    id(_ID) clmethod(quantile) clnumber(5) ///
    fcolor(Reds) ocolor(gs12 ..) osize(vthin ..) ///
    ndocolor(gs14) ///
    title("IAPT waiting pressure across LSOAs") ///
    subtitle("Mean monthly share waiting over six weeks, 2019/20") ///
    legend(position(5) size(vsmall)) ///
    name(lsoa_delay6, replace)

graph export "$outdir/LSOA_waiting_over_6_weeks_2019_20.png", ///
    width(2400) replace

spmap access_18w using "$shpdir/LSOA11_map_shp.dta", ///
    id(_ID) clmethod(quantile) clnumber(5) ///
    fcolor(Greens) ocolor(gs12 ..) osize(vthin ..) ///
    ndocolor(gs14) ///
    title("IAPT access within eighteen weeks across LSOAs") ///
    subtitle("Mean monthly CCG rate assigned to LSOAs, 2019/20") ///
    legend(position(5) size(vsmall)) ///
    name(lsoa_access18, replace)

graph export "$outdir/LSOA_access_within_18_weeks_2019_20.png", ///
    width(2400) replace

spmap delay_18w using "$shpdir/LSOA11_map_shp.dta", ///
    id(_ID) clmethod(quantile) clnumber(5) ///
    fcolor(Oranges) ocolor(gs12 ..) osize(vthin ..) ///
    ndocolor(gs14) ///
    title("IAPT waiting pressure across LSOAs") ///
    subtitle("Mean monthly share waiting over eighteen weeks, 2019/20") ///
    legend(position(5) size(vsmall)) ///
    name(lsoa_delay18, replace)

graph export "$outdir/LSOA_waiting_over_18_weeks_2019_20.png", ///
    width(2400) replace


/***********************************************************************
 8. AGGREGATE LSOA EXPOSURE TO OSL AUA-MONTH
***********************************************************************/

use "$outdir/IAPT_LSOA_month_exposure_clean.dta", clear

* Equal-LSOA-weighted local-authority exposure.
generate byte one_lsoa = 1

collapse (mean) access_2w access_4w access_6w delay_6w ///
                 access_12w access_18w delay_18w over18_rate ///
         (sum) n_lsoa=one_lsoa, by(oslaua mdate)

isid oslaua mdate
sort oslaua mdate

label data "Equal-LSOA-weighted IAPT exposure by OSL AUA-month"
label variable n_lsoa "Number of LSOAs contributing to local-authority mean"

save "$outdir/IAPT_OSLAUA_month_exposure_equal_LSOA.dta", replace


/***********************************************************************
 9. PREPARE UKHLS HIDP-WAVE-OSLAUA FILE
***********************************************************************/

use "$geofile", clear

confirm variable hidp
confirm variable wave
confirm variable oslaua

keep hidp wave oslaua oscty
replace oslaua = upper(trim(oslaua))
drop if missing(hidp) | missing(wave)
duplicates drop hidp wave, force
isid hidp wave

save "$outdir/UKHLS_hidp_wave_oslaua.dta", replace


/***********************************************************************
 10. MATCH GEOGRAPHY AND EXPOSURE TO UKHLS
***********************************************************************/

use "$individualfile", clear

confirm variable pidp
confirm variable hidp
confirm variable wave
confirm variable ghq
confirm variable newjob
confirm variable year
confirm variable month

generate int mdate = ym(year, month)
format mdate %tm

merge m:1 hidp wave using "$outdir/UKHLS_hidp_wave_oslaua.dta"
tabulate _merge

keep if _merge == 3
drop _merge

replace oslaua = upper(trim(oslaua))
keep if substr(oslaua, 1, 1) == "E"

merge m:1 oslaua mdate using ///
    "$outdir/IAPT_OSLAUA_month_exposure_equal_LSOA.dta"
tabulate _merge

keep if _merge == 3
drop _merge

save "$outdir/UKHLS_IAPT_OSLAUA_month_analysis.dta", replace


/***********************************************************************
 11. BASIC DIAGNOSTICS
***********************************************************************/

summarize access_6w delay_6w access_18w delay_18w over18_rate
tabulate wave
tabulate mdate
tabulate oscty


/***********************************************************************
 12. CHECK AND MERGE NOMIS LABOUR-MARKET DATA

 Required variables in nomis_lad_month.dta:
   oslaua
   mdate
   claimant_rate

 Optional labour-market controls (used automatically if present):
   employment_rate
   inactivity_rate
   median_earnings

 mdate must be a Stata monthly date.
***********************************************************************/

confirm file "$labourfile"

use "$labourfile", clear

confirm variable oslaua
confirm variable mdate

* Accept the common alternative name unemployment_rate as well.
capture confirm variable claimant_rate
if _rc {
    capture confirm variable unemployment_rate
    if !_rc rename unemployment_rate claimant_rate
}
confirm variable claimant_rate

* Build a control list from the variables actually present in the file.
* This lets the code run with claimant rate alone or with richer controls.
local lm_controls claimant_rate
capture confirm variable employment_rate
if !_rc local lm_controls `lm_controls' employment_rate
capture confirm variable inactivity_rate
if !_rc local lm_controls `lm_controls' inactivity_rate
capture confirm variable median_earnings
if !_rc local lm_controls `lm_controls' median_earnings
display as text "Labour-market controls used: `lm_controls'"

replace oslaua = upper(trim(oslaua))
format mdate %tm
keep if substr(oslaua, 1, 1) == "E"
keep if inrange(mdate, tm(2015m7), tm(2022m6))
isid oslaua mdate

egen lad_id = group(oslaua), label

save "$outdir/labour_market_clean.dta", replace

use "$outdir/IAPT_OSLAUA_month_exposure_equal_LSOA.dta", clear

merge 1:1 oslaua mdate using "$outdir/labour_market_clean.dta"
tabulate _merge

keep if _merge == 3
drop _merge

* lad_id is already supplied by the labour-market file merged above.
confirm variable lad_id
xtset lad_id mdate

save "$outdir/IAPT_OSLAUA_labour_market_panel.dta", replace


/***********************************************************************
 13. WAITING-TIME REGRESSIONS AND RESIDUALS
***********************************************************************/

capture which reghdfe
if _rc {
    ssc install ftools, replace
    ssc install reghdfe, replace
}

* Model 1: claimant rate only.
reghdfe access_6w claimant_rate, ///
    absorb(lad_id mdate) vce(cluster lad_id)
estimates store wait_claimant6
predict double access6_resid_claimant if e(sample), residuals

reghdfe delay_6w claimant_rate, ///
    absorb(lad_id mdate) vce(cluster lad_id)
estimates store delay_claimant6
predict double delay6_resid_claimant if e(sample), residuals

* Model 2: all labour-market controls available in the file.
reghdfe access_6w `lm_controls', ///
    absorb(lad_id mdate) vce(cluster lad_id)
estimates store wait_full6
predict double access6_resid_full if e(sample), residuals

reghdfe delay_6w `lm_controls', ///
    absorb(lad_id mdate) vce(cluster lad_id)
estimates store delay_full6
predict double delay6_resid_full if e(sample), residuals

* Model 3: predetermined labour-market controls.
generate double claimant_rate_lag1 = L1.claimant_rate
generate double claimant_rate_lag12 = L12.claimant_rate

reghdfe access_6w claimant_rate_lag1 claimant_rate_lag12, ///
    absorb(lad_id mdate) vce(cluster lad_id)
estimates store wait_lagged6
predict double access6_resid_lagged if e(sample), residuals

reghdfe delay_6w claimant_rate_lag1 claimant_rate_lag12, ///
    absorb(lad_id mdate) vce(cluster lad_id)
estimates store delay_lagged6
predict double delay6_resid_lagged if e(sample), residuals

save "$outdir/IAPT_OSLAUA_labour_market_residuals.dta", replace


/***********************************************************************
 14. MERGE ORIGINAL AND RESIDUALISED IVS TO UKHLS
***********************************************************************/

use "$outdir/UKHLS_IAPT_OSLAUA_month_analysis.dta", clear

drop access_2w access_4w access_6w delay_6w ///
     access_12w access_18w delay_18w over18_rate n_lsoa

merge m:1 oslaua mdate using ///
    "$outdir/IAPT_OSLAUA_labour_market_residuals.dta"
tabulate _merge

keep if _merge == 3
drop _merge

replace ghq = . if ghq < 0
replace newjob = . if newjob < 0

keep if !missing(ghq, newjob, access_6w, delay_6w, ///
                  access6_resid_full, delay6_resid_full)

save "$outdir/UKHLS_IAPT_original_and_residual_IV_ready.dta", replace


/***********************************************************************
 15. FIRST-STAGE REGRESSIONS
***********************************************************************/

reghdfe ghq access_6w `lm_controls' lnw dvage age2 male, ///
    absorb(lad_id mdate) vce(cluster lad_id)
estimates store fs_access6_original

reghdfe ghq delay_6w `lm_controls' lnw dvage age2 male, ///
    absorb(lad_id mdate) vce(cluster lad_id)
estimates store fs_delay6_original

reghdfe ghq access6_resid_full `lm_controls' lnw dvage age2 male, ///
    absorb(lad_id mdate) vce(cluster lad_id)
estimates store fs_access6_residual

reghdfe ghq delay6_resid_full `lm_controls' lnw dvage age2 male, ///
    absorb(lad_id mdate) vce(cluster lad_id)
estimates store fs_delay6_residual


/***********************************************************************
 16. 2SLS ORIGINAL VERSUS RESIDUALISED INSTRUMENT
***********************************************************************/

capture which ivreghdfe
if _rc {
    ssc install ivreg2, replace
    net install ivreghdfe, ///
        from("https://raw.githubusercontent.com/sergiocorreia/ivreghdfe/master/src/") ///
        replace
}

ivreghdfe newjob `lm_controls' lnw dvage age2 male ///
    (ghq = access_6w), ///
    absorb(lad_id mdate) cluster(lad_id) first
estimates store iv_access6_original

ivreghdfe newjob `lm_controls' lnw dvage age2 male ///
    (ghq = delay_6w), ///
    absorb(lad_id mdate) cluster(lad_id) first
estimates store iv_delay6_original

ivreghdfe newjob `lm_controls' lnw dvage age2 male ///
    (ghq = access6_resid_full), ///
    absorb(lad_id mdate) cluster(lad_id) first
estimates store iv_access6_residual

ivreghdfe newjob `lm_controls' lnw dvage age2 male ///
    (ghq = delay6_resid_full), ///
    absorb(lad_id mdate) cluster(lad_id) first
estimates store iv_delay6_residual


/***********************************************************************
 17. REDUCED-FORM AND RESIDUAL CORRELATION CHECKS
***********************************************************************/

reghdfe newjob access_6w `lm_controls' lnw dvage age2 male, ///
    absorb(lad_id mdate) vce(cluster lad_id)
estimates store rf_access6

reghdfe newjob access6_resid_full `lm_controls' lnw dvage age2 male, ///
    absorb(lad_id mdate) vce(cluster lad_id)
estimates store rf_access6_residual

correlate access6_resid_full claimant_rate
correlate delay6_resid_full claimant_rate

capture which esttab
if !_rc {
    esttab fs_access6_original fs_access6_residual ///
           iv_access6_original iv_access6_residual ///
        using "$outdir/IAPT_IV_results.rtf", replace ///
        se star(* 0.10 ** 0.05 *** 0.01) ///
        mtitles("FS original" "FS residual" "IV original" "IV residual")
}

save "$outdir/UKHLS_IAPT_final_IV_analysis.dta", replace

display as result "============================================================"
display as result "Completed. Output folder:"
display as result "$outdir"
display as result "============================================================"

clear
