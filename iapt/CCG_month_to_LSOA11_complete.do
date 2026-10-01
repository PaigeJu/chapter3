/*****************************************************************************
 PURPOSE
 -------
 Convert monthly England IAPT data from CCG level to LSOA11 level by
 expanding each CCG-month observation to all LSOA11s belonging to that CCG.

 IMPORTANT INTERPRETATION
 ------------------------
 1. This does NOT estimate an LSOA-specific waiting time.
 2. Every LSOA within the same CCG-month inherits the same CCG-level rate.
 3. CCG patient counts are retained only as contextual CCG totals. They must
    not be summed across the expanded LSOA file because that would duplicate
    the same CCG total once for every constituent LSOA.
 4. The available crosswalks cover England only.
 5. CCG observations end in June 2022. From July 2022 the source uses Sub-ICB.

 REQUIRED FILES IN $lookupdir
 ----------------------------
 - IAPT_wait.dta (in $datadir)
 - Seven LSOA11-to-CCG lookup CSV files for 2015--2021

 MAIN OUTPUT
 -----------
 - IAPT_CCG_month_LSOA11.dta
 - IAPT_CCG_month_LSOA11_exposure_only.dta
 - IAPT_CCG_codes_unmatched_to_LSOA.dta
 - LSOA11_CCG_2015_2021_combined.dta
*****************************************************************************/

clear all
set more off
set linesize 255

/****************************************************************************
 1. USER PATHS
****************************************************************************/

global datadir   "C:/Users/hm21806/Desktop/chapter3/code_iapt"
global lookupdir "C:/Users/hm21806/Desktop/chapter3/code_iapt"
global outdir    "C:/Users/hm21806/Desktop/chapter3/code_iapt/lsoa_output"

capture mkdir "$outdir"

global iaptfile "$datadir/IAPT_wait.dta"

global lookup2015 "$lookupdir/Lower_Layer_Super_Output_Area_(2011)_to_Clinical_Commissioning_Group_to_Local_Authority_District_(July_2015)_Lookup_in_England.csv"

global lookup2016 "$lookupdir/Lower_Layer_Super_Output_Area_(2011)_to_Clinical_Commissioning_Group_to_Local_Authority_District_(April_2016)_Lookup_in_England (1).csv"

global lookup2017 "$lookupdir/Lower_Layer_Super_Output_Area_(2011)_to_Clinical_Commissioning_Group_to_Local_Authority_District_(April_2017)_Lookup_in_England_(Version_4).csv"

global lookup2018 "$lookupdir/Lower_Layer_Super_Output_Area_(2011)_to_Clinical_Commissioning_Group_to_Local_Authority_District_(April_2018)_Lookup_in_England.csv"

global lookup2019 "$lookupdir/LSOA11_CCG19_LAD19_EN_LU_b15d0240099643b6a303f24ccc04da06_6577294720128586166.csv"

global lookup2020 "$lookupdir/LSOA11_CCG20_LAD20_EN_LU_70eab767c27c42bfb95aab5f67d05cdc_4133347202906010943.csv"

global lookup2021 "$lookupdir/LSOA11_CCG21_LAD21_EN_LU_b6ad2e7a1bd74f88992e94126570be36_4922878688532686284.csv"


/****************************************************************************
 2. CHECK THAT EVERY INPUT FILE EXISTS
****************************************************************************/

confirm file "$iaptfile"
confirm file "$lookup2015"
confirm file "$lookup2016"
confirm file "$lookup2017"
confirm file "$lookup2018"
confirm file "$lookup2019"
confirm file "$lookup2020"
confirm file "$lookup2021"

display as result "All eight required input files were found."


/****************************************************************************
 3. IMPORT AND STANDARDISE THE 2015 LOOKUP
****************************************************************************/

tempfile lookup15 lookup16 lookup17 lookup18 lookup19 lookup20 lookup21

import delimited using "$lookup2015", clear varnames(1) case(lower) stringcols(_all)

keep lsoa11cd lsoa11nm ccg15cd ccg15cdh ccg15nm lad15cd lad15nm

rename ccg15cd  ccg_ons_code
rename ccg15cdh ccg_code
rename ccg15nm  ccg_name
rename lad15cd  oslaua
rename lad15nm  lad_name

generate int lookup_year = 2015

foreach var of varlist lsoa11cd lsoa11nm ccg_ons_code ccg_code ccg_name oslaua lad_name {
    replace `var' = trim(`var')
}

replace ccg_code     = upper(ccg_code)
replace ccg_ons_code = upper(ccg_ons_code)
replace lsoa11cd     = upper(lsoa11cd)
replace oslaua       = upper(oslaua)

drop if missing(lsoa11cd) | missing(ccg_code)
duplicates drop lookup_year lsoa11cd, force
isid lookup_year lsoa11cd

save `lookup15', replace


/****************************************************************************
 4. IMPORT AND STANDARDISE THE 2016 LOOKUP
****************************************************************************/

import delimited using "$lookup2016", clear varnames(1) case(lower) stringcols(_all)

keep lsoa11cd lsoa11nm ccg16cd ccg16cdh ccg16nm lad16cd lad16nm

rename ccg16cd  ccg_ons_code
rename ccg16cdh ccg_code
rename ccg16nm  ccg_name
rename lad16cd  oslaua
rename lad16nm  lad_name

generate int lookup_year = 2016

foreach var of varlist lsoa11cd lsoa11nm ccg_ons_code ccg_code ccg_name oslaua lad_name {
    replace `var' = trim(`var')
}

replace ccg_code     = upper(ccg_code)
replace ccg_ons_code = upper(ccg_ons_code)
replace lsoa11cd     = upper(lsoa11cd)
replace oslaua       = upper(oslaua)

drop if missing(lsoa11cd) | missing(ccg_code)
duplicates drop lookup_year lsoa11cd, force
isid lookup_year lsoa11cd

save `lookup16', replace


/****************************************************************************
 5. IMPORT AND STANDARDISE THE 2017 LOOKUP
****************************************************************************/

import delimited using "$lookup2017", clear varnames(1) case(lower) stringcols(_all)

keep lsoa11cd lsoa11nm ccg17cd ccg17cdh ccg17nm lad17cd lad17nm

rename ccg17cd  ccg_ons_code
rename ccg17cdh ccg_code
rename ccg17nm  ccg_name
rename lad17cd  oslaua
rename lad17nm  lad_name

generate int lookup_year = 2017

foreach var of varlist lsoa11cd lsoa11nm ccg_ons_code ccg_code ccg_name oslaua lad_name {
    replace `var' = trim(`var')
}

replace ccg_code     = upper(ccg_code)
replace ccg_ons_code = upper(ccg_ons_code)
replace lsoa11cd     = upper(lsoa11cd)
replace oslaua       = upper(oslaua)

drop if missing(lsoa11cd) | missing(ccg_code)
duplicates drop lookup_year lsoa11cd, force
isid lookup_year lsoa11cd

save `lookup17', replace


/****************************************************************************
 6. IMPORT AND STANDARDISE THE 2018 LOOKUP
****************************************************************************/

import delimited using "$lookup2018", clear varnames(1) case(lower) stringcols(_all)

keep lsoa11cd lsoa11nm ccg18cd ccg18cdh ccg18nm lad18cd lad18nm

rename ccg18cd  ccg_ons_code
rename ccg18cdh ccg_code
rename ccg18nm  ccg_name
rename lad18cd  oslaua
rename lad18nm  lad_name

generate int lookup_year = 2018

foreach var of varlist lsoa11cd lsoa11nm ccg_ons_code ccg_code ccg_name oslaua lad_name {
    replace `var' = trim(`var')
}

replace ccg_code     = upper(ccg_code)
replace ccg_ons_code = upper(ccg_ons_code)
replace lsoa11cd     = upper(lsoa11cd)
replace oslaua       = upper(oslaua)

drop if missing(lsoa11cd) | missing(ccg_code)
duplicates drop lookup_year lsoa11cd, force
isid lookup_year lsoa11cd

save `lookup18', replace


/****************************************************************************
 7. IMPORT AND STANDARDISE THE 2019 LOOKUP
****************************************************************************/

import delimited using "$lookup2019", clear varnames(1) case(lower) stringcols(_all)

keep lsoa11cd lsoa11nm ccg19cd ccg19cdh ccg19nm lad19cd lad19nm

rename ccg19cd  ccg_ons_code
rename ccg19cdh ccg_code
rename ccg19nm  ccg_name
rename lad19cd  oslaua
rename lad19nm  lad_name

generate int lookup_year = 2019

foreach var of varlist lsoa11cd lsoa11nm ccg_ons_code ccg_code ccg_name oslaua lad_name {
    replace `var' = trim(`var')
}

replace ccg_code     = upper(ccg_code)
replace ccg_ons_code = upper(ccg_ons_code)
replace lsoa11cd     = upper(lsoa11cd)
replace oslaua       = upper(oslaua)

drop if missing(lsoa11cd) | missing(ccg_code)
duplicates drop lookup_year lsoa11cd, force
isid lookup_year lsoa11cd

save `lookup19', replace


/****************************************************************************
 8. IMPORT AND STANDARDISE THE 2020 LOOKUP
****************************************************************************/

import delimited using "$lookup2020", clear varnames(1) case(lower) stringcols(_all)

keep lsoa11cd lsoa11nm ccg20cd ccg20cdh ccg20nm lad20cd lad20nm

rename ccg20cd  ccg_ons_code
rename ccg20cdh ccg_code
rename ccg20nm  ccg_name
rename lad20cd  oslaua
rename lad20nm  lad_name

generate int lookup_year = 2020

foreach var of varlist lsoa11cd lsoa11nm ccg_ons_code ccg_code ccg_name oslaua lad_name {
    replace `var' = trim(`var')
}

replace ccg_code     = upper(ccg_code)
replace ccg_ons_code = upper(ccg_ons_code)
replace lsoa11cd     = upper(lsoa11cd)
replace oslaua       = upper(oslaua)

drop if missing(lsoa11cd) | missing(ccg_code)
duplicates drop lookup_year lsoa11cd, force
isid lookup_year lsoa11cd

save `lookup20', replace


/****************************************************************************
 9. IMPORT AND STANDARDISE THE 2021 LOOKUP
****************************************************************************/

import delimited using "$lookup2021", clear varnames(1) case(lower) stringcols(_all)

keep lsoa11cd lsoa11nm ccg21cd ccg21cdh ccg21nm lad21cd lad21nm

rename ccg21cd  ccg_ons_code
rename ccg21cdh ccg_code
rename ccg21nm  ccg_name
rename lad21cd  oslaua
rename lad21nm  lad_name

generate int lookup_year = 2021

foreach var of varlist lsoa11cd lsoa11nm ccg_ons_code ccg_code ccg_name oslaua lad_name {
    replace `var' = trim(`var')
}

replace ccg_code     = upper(ccg_code)
replace ccg_ons_code = upper(ccg_ons_code)
replace lsoa11cd     = upper(lsoa11cd)
replace oslaua       = upper(oslaua)

drop if missing(lsoa11cd) | missing(ccg_code)
duplicates drop lookup_year lsoa11cd, force
isid lookup_year lsoa11cd

save `lookup21', replace


/****************************************************************************
 10. APPEND THE SEVEN LOOKUPS
****************************************************************************/

use `lookup15', clear
append using `lookup16' `lookup17' `lookup18' `lookup19' `lookup20' `lookup21'

order lookup_year lsoa11cd lsoa11nm ccg_code ccg_ons_code ccg_name oslaua lad_name
sort lookup_year ccg_code lsoa11cd

isid lookup_year lsoa11cd

compress
save "$outdir/LSOA11_CCG_2015_2021_combined.dta", replace


/****************************************************************************
 11. PREPARE MONTHLY CCG-LEVEL IAPT DATA
****************************************************************************/

use "$iaptfile", clear

keep if group_type == "CCG"
drop if org_code_missing == 1
drop if missing(org_code1) | trim(org_code1) == ""

rename org_code1 ccg_code
rename org_name1 iapt_ccg_name

replace ccg_code     = upper(trim(ccg_code))
replace iapt_ccg_name = trim(iapt_ccg_name)

* report_month in the supplied IAPT_wait.dta is a Stata daily date.
* This block also works if a later version stores it as a monthly date.
local report_format : format report_month

if substr("`report_format'", 1, 3) == "%td" {
    generate int mdate = mofd(report_month)
}
else if substr("`report_format'", 1, 3) == "%tm" {
    generate int mdate = report_month
}
else {
    display as error "report_month is neither a Stata daily nor monthly date."
    exit 459
}

format mdate %tm

generate int calendar_year  = year(dofm(mdate))
generate byte calendar_month = month(dofm(mdate))

* Choose the lookup that was current in each NHS financial year.
* Jan--Mar use the lookup from the preceding April.
generate int lookup_year = calendar_year
replace lookup_year = calendar_year - 1 if calendar_month <= 3

* We only possess the July 2015 lookup for the earliest observations.
replace lookup_year = 2015 if lookup_year < 2015

* The 2021 CCG configuration continued until CCGs were abolished in June 2022.
replace lookup_year = 2021 if lookup_year > 2021 & mdate <= tm(2022m6)

* CCG mapping is only meaningful through June 2022.
keep if inrange(mdate, tm(2015m1), tm(2022m6))

* The supplied data have one row per CCG-month.
isid mdate ccg_code

* Rename counts so the expanded file clearly identifies them as CCG totals.
rename wait_total    ccg_wait_total
rename wait_0_2w     ccg_wait_0_2w
rename wait_0_4w     ccg_wait_0_4w
rename wait_0_6w     ccg_wait_0_6w
rename wait_0_12w    ccg_wait_0_12w
rename wait_0_18w    ccg_wait_0_18w
rename wait_over18w  ccg_wait_over18w

* Construct CCG-level waiting-time rates inherited by each matched LSOA.
generate double access_2w = ccg_wait_0_2w / ccg_wait_total if ccg_wait_total > 0
generate double access_4w = ccg_wait_0_4w / ccg_wait_total if ccg_wait_total > 0
generate double access_6w = ccg_wait_0_6w / ccg_wait_total if ccg_wait_total > 0
generate double access_12w = ccg_wait_0_12w / ccg_wait_total if ccg_wait_total > 0
generate double access_18w = ccg_wait_0_18w / ccg_wait_total if ccg_wait_total > 0
generate double over18_rate = ccg_wait_over18w / ccg_wait_total if ccg_wait_total > 0

generate double delay_6w  = 1 - access_6w  if !missing(access_6w)
generate double delay_18w = 1 - access_18w if !missing(access_18w)

label variable access_6w  "CCG share accessing treatment within 6 weeks"
label variable delay_6w   "CCG share waiting longer than 6 weeks"
label variable access_18w "CCG share accessing treatment within 18 weeks"
label variable delay_18w  "CCG share waiting longer than 18 weeks"
label variable over18_rate "CCG share recorded in over-18-week category"

foreach var of varlist access_2w access_4w access_6w access_12w access_18w over18_rate delay_6w delay_18w {
    assert inrange(`var', 0, 1) if !missing(`var')
}

save "$outdir/IAPT_CCG_month_prepared.dta", replace


/****************************************************************************
 12. EXPAND EACH CCG-MONTH TO ITS CONSTITUENT LSOA11s

 joinby is required because this is a one-to-many relationship:
 one CCG-month corresponds to many LSOA11-month observations.
****************************************************************************/

joinby lookup_year ccg_code using ///
    "$outdir/LSOA11_CCG_2015_2021_combined.dta", ///
    unmatched(master)

tabulate _merge

* Save all CCG-month observations that did not have a geographical match.
preserve
    keep if _merge == 1
    keep mdate report_month lookup_year ccg_code iapt_ccg_name ccg_wait_total
    duplicates drop
    sort mdate ccg_code
    save "$outdir/IAPT_CCG_codes_unmatched_to_LSOA.dta", replace
restore

* Keep only successful CCG-to-LSOA matches.
keep if _merge == 3
drop _merge

* One observation must now represent one LSOA11-month.
isid mdate lsoa11cd

order mdate report_month calendar_year calendar_month lookup_year ///
      lsoa11cd lsoa11nm oslaua lad_name ///
      ccg_code ccg_ons_code ccg_name iapt_ccg_name ///
      access_2w access_4w access_6w delay_6w ///
      access_12w access_18w delay_18w over18_rate ///
      ccg_wait_total ccg_wait_0_2w ccg_wait_0_4w ccg_wait_0_6w ///
      ccg_wait_0_12w ccg_wait_0_18w ccg_wait_over18w

sort lsoa11cd mdate
compress

label data "CCG-level IAPT waiting-time exposures expanded to LSOA11-month"

save "$outdir/IAPT_CCG_month_LSOA11.dta", replace


/****************************************************************************
 13. SAVE A COMPACT EXPOSURE FILE FOR MERGING TO INDIVIDUAL DATA

 This file excludes duplicated CCG patient counts. It is the safer file for
 merging waiting-time exposure variables to a dataset containing LSOA11 and
 month. A suitable merge would normally be:

 merge m:1 lsoa11cd mdate using IAPT_CCG_month_LSOA11_exposure_only.dta
****************************************************************************/

keep mdate lookup_year lsoa11cd lsoa11nm oslaua lad_name ///
     ccg_code ccg_ons_code ccg_name ///
     access_2w access_4w access_6w delay_6w ///
     access_12w access_18w delay_18w over18_rate

isid lsoa11cd mdate

save "$outdir/IAPT_CCG_month_LSOA11_exposure_only.dta", replace


/****************************************************************************
 14. FINAL DIAGNOSTICS
****************************************************************************/

count
display as result "Matched LSOA11-month observations: " r(N)

quietly summarize mdate
display as result "First matched month: " %tm r(min)
display as result "Last matched month:  " %tm r(max)

tabulate lookup_year

display as result "------------------------------------------------------------"
display as result "CCG-to-LSOA11 conversion completed."
display as result "Main exposure file:"
display as result "$outdir/IAPT_CCG_month_LSOA11_exposure_only.dta"
display as result "Check unmatched codes here:"
display as result "$outdir/IAPT_CCG_codes_unmatched_to_LSOA.dta"
display as result "------------------------------------------------------------"

clear

