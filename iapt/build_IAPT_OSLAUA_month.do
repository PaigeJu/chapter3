clear all
set more off

**************************************************************************
* Purpose:
*   Convert CCG-month IAPT access/delay measures to oslaua-month measures
*   using annual LSOA11 -> CCG -> LAD lookup files.
*
* Geography supplied:
*   July 2015 and April 2016-2021 lookup files.
*
* Weighting supplied by this file:
*   Each LSOA receives equal weight. Hence the LAD-CCG weight is the share
*   of a LAD's LSOAs assigned to each CCG. This is an approximation to a
*   resident-population weight, because no LSOA population file was supplied.
**************************************************************************

* EDIT THESE PATHS IF NEEDED
global datadir   "C:/Users/hm21806/Desktop/chapter3/code_iapt"
global lookupdir "C:/Users/hm21806/Desktop/chapter3/code_iapt"
global outdir    "C:/Users/hm21806/Desktop/chapter3/code_iapt"

capture mkdir "$outdir"

tempfile lu2015 lu2016 lu2017 lu2018 lu2019 lu2020 lu2021 all_lookup weights

**************************************************************************
* A. Import and harmonise the seven annual lookup files
*
* Use CCGxxCDH, not CCGxxCD:
*   CCGxxCDH contains the three-character NHS code used by IAPT (e.g. 00K).
*   CCGxxCD contains the nine-character ONS code (e.g. E38000075).
**************************************************************************

import delimited using ///
    "$lookupdir/Lower_Layer_Super_Output_Area_(2011)_to_Clinical_Commissioning_Group_to_Local_Authority_District_(July_2015)_Lookup_in_England.csv", ///
    clear varnames(1) case(lower) stringcols(_all)

rename ccg15cdh ccg_code
rename lad15cd  oslaua
keep lsoa11cd ccg_code oslaua
gen int vintage = 2015
replace ccg_code = upper(trim(ccg_code))
replace oslaua   = upper(trim(oslaua))
isid lsoa11cd
save `lu2015'

import delimited using ///
    "$lookupdir/Lower_Layer_Super_Output_Area_(2011)_to_Clinical_Commissioning_Group_to_Local_Authority_District_(April_2016)_Lookup_in_England (1).csv", ///
    clear varnames(1) case(lower) stringcols(_all)

rename ccg16cdh ccg_code
rename lad16cd  oslaua
keep lsoa11cd ccg_code oslaua
gen int vintage = 2016
replace ccg_code = upper(trim(ccg_code))
replace oslaua   = upper(trim(oslaua))
isid lsoa11cd
save `lu2016'

import delimited using ///
    "$lookupdir/Lower_Layer_Super_Output_Area_(2011)_to_Clinical_Commissioning_Group_to_Local_Authority_District_(April_2017)_Lookup_in_England_(Version_4).csv", ///
    clear varnames(1) case(lower) stringcols(_all)

rename ccg17cdh ccg_code
rename lad17cd  oslaua
keep lsoa11cd ccg_code oslaua
gen int vintage = 2017
replace ccg_code = upper(trim(ccg_code))
replace oslaua   = upper(trim(oslaua))
isid lsoa11cd
save `lu2017'

import delimited using ///
    "$lookupdir/Lower_Layer_Super_Output_Area_(2011)_to_Clinical_Commissioning_Group_to_Local_Authority_District_(April_2018)_Lookup_in_England.csv", ///
    clear varnames(1) case(lower) stringcols(_all)

rename ccg18cdh ccg_code
rename lad18cd  oslaua
keep lsoa11cd ccg_code oslaua
gen int vintage = 2018
replace ccg_code = upper(trim(ccg_code))
replace oslaua   = upper(trim(oslaua))
isid lsoa11cd
save `lu2018'

import delimited using ///
    "$lookupdir/LSOA11_CCG19_LAD19_EN_LU_b15d0240099643b6a303f24ccc04da06_6577294720128586166.csv", ///
    clear varnames(1) case(lower) stringcols(_all)

rename ccg19cdh ccg_code
rename lad19cd  oslaua
keep lsoa11cd ccg_code oslaua
gen int vintage = 2019
replace ccg_code = upper(trim(ccg_code))
replace oslaua   = upper(trim(oslaua))
isid lsoa11cd
save `lu2019'

import delimited using ///
    "$lookupdir/LSOA11_CCG20_LAD20_EN_LU_70eab767c27c42bfb95aab5f67d05cdc_4133347202906010943.csv", ///
    clear varnames(1) case(lower) stringcols(_all)

rename ccg20cdh ccg_code
rename lad20cd  oslaua
keep lsoa11cd ccg_code oslaua
gen int vintage = 2020
replace ccg_code = upper(trim(ccg_code))
replace oslaua   = upper(trim(oslaua))
isid lsoa11cd
save `lu2020'

import delimited using ///
    "$lookupdir/LSOA11_CCG21_LAD21_EN_LU_b6ad2e7a1bd74f88992e94126570be36_4922878688532686284.csv", ///
    clear varnames(1) case(lower) stringcols(_all)

rename ccg21cdh ccg_code
rename lad21cd  oslaua
keep lsoa11cd ccg_code oslaua
gen int vintage = 2021
replace ccg_code = upper(trim(ccg_code))
replace oslaua   = upper(trim(oslaua))
isid lsoa11cd
save `lu2021'

**************************************************************************
* B. Append annual lookups and audit their structure
**************************************************************************

use `lu2015', clear
append using `lu2016' `lu2017' `lu2018' `lu2019' `lu2020' `lu2021'

drop if trim(lsoa11cd) == "" | trim(ccg_code) == "" | trim(oslaua) == ""
isid vintage lsoa11cd

save `all_lookup'
save "$outdir/LSOA11_CCG_LAD_2015_2021_harmonised.dta", replace

preserve
    contract vintage ccg_code oslaua
    bysort vintage oslaua: gen n_ccg_per_lad = _N
    bysort vintage ccg_code: gen n_lad_per_ccg = _N
    collapse (count) n_ccg_lad_pairs=ccg_code ///
             (max) max_ccg_per_lad=n_ccg_per_lad ///
             (max) max_lad_per_ccg=n_lad_per_ccg, by(vintage)
    save "$outdir/CCG_LAD_structure_audit.dta", replace
restore

**************************************************************************
* C. Construct LAD-CCG weights from shares of LSOAs
*
* Replace this section with population sums when an LSOA population file
* becomes available. The rest of the do-file can remain unchanged.
**************************************************************************

gen double one_lsoa = 1

collapse (sum) n_lsoa=one_lsoa, by(vintage oslaua ccg_code)

bysort vintage oslaua: egen double n_lsoa_lad = total(n_lsoa)
gen double lad_ccg_weight = n_lsoa / n_lsoa_lad

bysort vintage oslaua: egen double weight_check = total(lad_ccg_weight)
assert abs(weight_check - 1) < 1e-10
drop weight_check

label variable n_lsoa "Number of LSOA11s in LAD-CCG intersection"
label variable lad_ccg_weight "Approximate LAD-CCG weight: share of LAD LSOAs"

isid vintage oslaua ccg_code
save `weights'
save "$outdir/CCG_LAD_LSOA_weights_2015_2021.dta", replace

**************************************************************************
* D. Join the LAD-CCG weights to monthly IAPT measures
**************************************************************************

use `weights', clear

joinby vintage ccg_code using ///
    "$datadir/IAPT_CCG_month_clean.dta", ///
    unmatched(both) _merge(geog_merge)

* Save every unmatched record instead of silently discarding it
preserve
    keep if geog_merge != 3
    sort vintage ccg_code mdate oslaua
    save "$outdir/IAPT_CCG_geography_unmatched_audit.dta", replace
restore

keep if geog_merge == 3
drop geog_merge

**************************************************************************
* E. Construct oslaua-month weighted access and delay measures
**************************************************************************

foreach v in access_6w access_18w delay_6w delay_18w over18_rate {
    gen double part_`v' = lad_ccg_weight * `v' if !missing(`v')
    gen double validw_`v' = lad_ccg_weight if !missing(`v')
}

collapse (sum) part_access_6w part_access_18w ///
               part_delay_6w part_delay_18w part_over18_rate ///
               validw_access_6w validw_access_18w ///
               validw_delay_6w validw_delay_18w ///
               validw_over18_rate, ///
         by(oslaua report_month mdate calendar_year calendar_month vintage)

gen double lad_access6 = part_access_6w / validw_access_6w ///
    if validw_access_6w > 0

gen double lad_access18 = part_access_18w / validw_access_18w ///
    if validw_access_18w > 0

gen double lad_delay6 = part_delay_6w / validw_delay_6w ///
    if validw_delay_6w > 0

gen double lad_delay18 = part_delay_18w / validw_delay_18w ///
    if validw_delay_18w > 0

gen double lad_over18 = part_over18_rate / validw_over18_rate ///
    if validw_over18_rate > 0

* Coverage is the share of the LAD's LSOAs represented by non-missing CCG data
gen double coverage6  = validw_delay_6w
gen double coverage18 = validw_delay_18w

gen byte adequate_coverage6  = coverage6  >= 0.95 if coverage6  > 0
gen byte adequate_coverage18 = coverage18 >= 0.95 if coverage18 > 0

label variable lad_access6  "LSOA-share-weighted treatment access within 6 weeks"
label variable lad_access18 "LSOA-share-weighted treatment access within 18 weeks"
label variable lad_delay6   "LSOA-share-weighted share not treated within 6 weeks"
label variable lad_delay18  "LSOA-share-weighted share not treated within 18 weeks"
label variable lad_over18   "LSOA-share-weighted share recorded over 18 weeks"
label variable coverage6    "Share of LAD LSOAs with non-missing six-week measure"
label variable coverage18   "Share of LAD LSOAs with non-missing eighteen-week measure"

assert inrange(lad_access6,0,1) if !missing(lad_access6)
assert inrange(lad_access18,0,1) if !missing(lad_access18)
assert inrange(lad_delay6,0,1) if !missing(lad_delay6)
assert inrange(lad_delay18,0,1) if !missing(lad_delay18)
assert inrange(lad_over18,0,1) if !missing(lad_over18)

drop part_* validw_*

format report_month mdate %tm
order oslaua report_month mdate calendar_year calendar_month vintage ///
      lad_access6 lad_delay6 lad_access18 lad_delay18 lad_over18 ///
      coverage6 coverage18 adequate_coverage6 adequate_coverage18

sort oslaua mdate
isid oslaua mdate
compress

save "$outdir/IAPT_wait_OSLAUA_month.dta", replace

**************************************************************************
* F. Output audit by month
**************************************************************************

preserve
    collapse (count) n_lad6=lad_delay6 n_lad18=lad_delay18 ///
             (mean) mean_delay6=lad_delay6 mean_delay18=lad_delay18 ///
             (min) min_coverage6=coverage6 min_coverage18=coverage18, ///
             by(mdate)
    format mdate %tm
    sort mdate
    save "$outdir/IAPT_OSLAUA_month_audit.dta", replace
restore

**************************************************************************
* G. Optional: create lagged three- and twelve-month measures
**************************************************************************

capture which rangestat
if _rc == 0 {
    sort oslaua mdate

    rangestat (mean) delay6_lag3=lad_delay6 ///
                     delay18_lag3=lad_delay18, ///
              interval(mdate -3 -1) by(oslaua)

    rangestat (mean) delay6_lag12=lad_delay6 ///
                     delay18_lag12=lad_delay18, ///
              interval(mdate -12 -1) by(oslaua)

    label variable delay6_lag3  "Mean LAD six-week delay in previous 3 months"
    label variable delay18_lag3 "Mean LAD eighteen-week delay in previous 3 months"
    label variable delay6_lag12 "Mean LAD six-week delay in previous 12 months"
    label variable delay18_lag12 "Mean LAD eighteen-week delay in previous 12 months"

    save "$outdir/IAPT_wait_OSLAUA_month_lags.dta", replace
}
else {
    display as text "rangestat is not installed; lagged file was not created."
    display as text "Run: ssc install rangestat"
}

**************************************************************************
* H. Results-window checks
**************************************************************************

describe
summarize lad_access6 lad_delay6 lad_access18 lad_delay18 ///
          lad_over18 coverage6 coverage18

display as result "Created: $outdir/IAPT_wait_OSLAUA_month.dta"
display as result "Check: $outdir/IAPT_CCG_geography_unmatched_audit.dta"
display as result "Check: $outdir/IAPT_OSLAUA_month_audit.dta"

**************************************************************************
* Example UKHLS merge (edit variable names before running)
**************************************************************************

/*
use "C:/Users/hm21806/Desktop/chapter3/UKHLS_analysis.dta", clear

* If interview_date is a Stata daily date:
gen int mdate = mofd(interview_date)
format mdate %tm

* IAPT/NHS Talking Therapies data cover England only
keep if substr(oslaua,1,1) == "E"

merge m:1 oslaua mdate using ///
    "$outdir/IAPT_wait_OSLAUA_month_lags.dta", ///
    keepusing(lad_delay6 lad_delay18 delay6_lag3 delay18_lag3 ///
              delay6_lag12 delay18_lag12 coverage6 coverage18)

tabulate _merge
*/

