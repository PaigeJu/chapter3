clear all
set more off
version 17.0

/**********************************************************************
 Therapy waiting-time IV for GHQ and subsequent job mobility

 Uses:
   1) ind_ghq_lfs.dta: output from U1.1_indresp_ghq_lfs_keep_hidp.do
   2) hidp_geo.dta: UKHLS household-wave geography file
   3) IAPT_LSOA_month_exposure_clean.dta: LSOA-month therapy exposures

 Main instrument: LAD-month mean of delay_6w
 Alternative instrument: LAD-month mean of delay_18w

 The source exposure file has no population weights. LSOAs receive equal
 weight when calculating the LAD-month mean.
**********************************************************************/

*----------------------------- PATHS ---------------------------------
* Change these three paths only if the files are stored elsewhere.
global analysisdir "C:/Users/hm21806/Desktop/chapter3/code202602_newjobf"
global geofile     "C:/Users/hm21806/Desktop/chapter3/UKDA-6666-stata/stata/stata13/ukhls/hidp_geo.dta"
global iaptfile    "C:/Users/hm21806/Desktop/chapter3/IAPT/lsoa_analysis_output/IAPT_LSOA_month_exposure_clean.dta"

cd "$analysisdir"

capture confirm file "$analysisdir/ind_ghq_lfs.dta"
if _rc {
    display as error "Cannot find $analysisdir/ind_ghq_lfs.dta. Run the updated U1.1 cleaning do-file first, or correct global analysisdir."
    exit 601
}
capture confirm file "$geofile"
if _rc {
    display as error "Cannot find $geofile. Correct global geofile."
    exit 601
}
capture confirm file "$iaptfile"
if _rc {
    display as error "Cannot find $iaptfile. Extract IAPT_LSOA_month_exposure_clean.dta from the ZIP and correct global iaptfile."
    exit 601
}

*---------------------- BUILD LAD-MONTH EXPOSURE ---------------------
tempfile iapt_lad_month uk_geo

use "$iaptfile", clear
confirm variable mdate
confirm variable lsoa11cd
confirm variable oslaua
confirm variable delay_6w
confirm variable delay_18w

keep mdate lsoa11cd oslaua delay_6w delay_18w
drop if missing(mdate) | missing(oslaua)

* Equal-weight mean across LSOAs within each LAD and month.
collapse (mean) delay_6w delay_18w ///
         (count) n_lsoa_6w=delay_6w, by(oslaua mdate)
label variable delay_6w  "LAD-month mean LSOA share waiting >6 weeks"
label variable delay_18w "LAD-month mean LSOA share waiting >18 weeks"
label variable n_lsoa_6w "Number of LSOAs contributing to delay_6w mean"
format mdate %tm
isid oslaua mdate
save `iapt_lad_month', replace

*------------------------ PREPARE GEOGRAPHY --------------------------
use "$geofile", clear
confirm variable wave
confirm variable hidp
confirm variable oslaua
keep wave hidp oslaua
drop if missing(wave) | missing(hidp)
isid wave hidp
save `uk_geo', replace

*--------------------- LOAD ANALYSIS SAMPLE --------------------------
use "$analysisdir/ind_ghq_lfs.dta", clear
confirm variable pidp
confirm variable hidp
confirm variable wave
confirm variable idate
confirm variable ghq
confirm variable newjob
confirm variable lnw
confirm variable dvage
confirm variable age2
confirm variable male
confirm variable year

* Attach household-wave local authority to each person-wave.
merge m:1 wave hidp using `uk_geo', keep(master match) nogen

* Convert interview date into Stata monthly date, matching therapy mdate.
gen int mdate = mofd(idate) if !missing(idate)
format mdate %tm
label variable mdate "UKHLS interview month"

* Attach the LAD-month therapy exposure.
merge m:1 oslaua mdate using `iapt_lad_month', keep(master match) gen(_merge_iapt)
label variable _merge_iapt "UKHLS to therapy LAD-month exposure match"

di as text "UKHLS to therapy exposure merge:" 
tabulate _merge_iapt, missing
count if _merge_iapt==3
local nmatch = r(N)
count if _merge_iapt==1
local nunmatched = r(N)
di as result "Matched person-wave observations: `nmatch'"
di as result "Unmatched person-wave observations: `nunmatched'"

* Encode LAD for fixed effects and cluster-robust standard errors.
encode oslaua, gen(lad_id)
label variable lad_id "Local authority district identifier"

* Use one common estimation sample for the 6-week and 18-week measures.
gen byte therapy_ivsamp = !missing(newjob, ghq, lnw, dvage, age2, male, ///
    year, month, lad_id, delay_6w, delay_18w, mdate)
label variable therapy_ivsamp "Complete case for therapy IV specifications"
count if therapy_ivsamp
local nivsample = r(N)
di as result "Common estimation sample (both therapy measures): `nivsample'"

* Keep a reviewable merged dataset before estimation.
save "ukhls_therapy_waitingtime_merged.dta", replace

*---------------------- OLS COMPARISON -------------------------------
* Same sample and controls as the IV models; LAD and interview-year FE.
reg newjob ghq lnw dvage age2 male i.year i.month i.lad_id ///
    if therapy_ivsamp, vce(cluster lad_id)
estimates store OLS_therapy

* Reduced form: waiting-time exposure and subsequent new-job transition.
reg newjob delay_6w lnw dvage age2 male i.year i.month i.lad_id ///
    if therapy_ivsamp, vce(cluster lad_id)
estimates store RF_delay6

*-------------------- 2SLS: DELAY OVER SIX WEEKS ---------------------
* The outcome newjob is the transition indicator in the cleaned UKHLS file.
* GHQ is measured at the interview; the instrument is the LAD-month therapy
* waiting-time exposure at that interview. Standard errors are clustered at
* LAD, the level at which the exposure is assigned.
ivregress 2sls newjob lnw dvage age2 male i.year i.month i.lad_id ///
    (ghq = delay_6w) if therapy_ivsamp, vce(cluster lad_id)
estimates store IV_delay6
estat firststage
estat endogenous

* Save detailed output.
log using "therapy_waitingtime_IV_results.log", text replace
noisily display "THERAPY WAITING-TIME IV: MAIN SPECIFICATION (delay_6w)"
noisily ivregress 2sls newjob lnw dvage age2 male i.year i.month i.lad_id ///
    (ghq = delay_6w) if therapy_ivsamp, vce(cluster lad_id)
noisily estat firststage
noisily estat endogenous

*----------------- 2SLS: DELAY OVER 18 WEEKS -------------------------
noisily display "THERAPY WAITING-TIME IV: ALTERNATIVE (delay_18w)"
ivregress 2sls newjob lnw dvage age2 male i.year i.month i.lad_id ///
    (ghq = delay_18w) if therapy_ivsamp, vce(cluster lad_id)
estimates store IV_delay18
noisily estat firststage
noisily estat endogenous

* Optional Word table if outreg2 is installed (same style as the life-event do-file).
capture which outreg2
if !_rc {
    estimates restore OLS_therapy
    outreg2 using "therapy_waitingtime_IV_results.doc", replace ///
        ctitle("OLS: GHQ") dec(3)
    estimates restore IV_delay6
    outreg2 using "therapy_waitingtime_IV_results.doc", append ///
        ctitle("2SLS: delay >6 weeks") dec(3)
    estimates restore IV_delay18
    outreg2 using "therapy_waitingtime_IV_results.doc", append ///
        ctitle("2SLS: delay >18 weeks") dec(3)
}
else {
    display as error "outreg2 is not installed; regression results are still saved in therapy_waitingtime_IV_results.log."
}
log close

* Leave the merged analysis data in memory and saved on disk.
use "ukhls_therapy_waitingtime_merged.dta", clear

display as result "Completed. Main output: ukhls_therapy_waitingtime_merged.dta"
display as result "Results log: therapy_waitingtime_IV_results.log"
display as result "Optional table: therapy_waitingtime_IV_results.doc (if outreg2 is installed)"
