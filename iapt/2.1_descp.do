clear all
set more off

**************************************************************************
* IAPT CCG monthly data cleaning
**************************************************************************

global datadir "C:/Users/hm21806/Desktop/chapter3/code_iapt"

cd "$datadir"


**************************************************************************
* 1. Open combined IAPT data
**************************************************************************

use "waiting_commissioners_wide.dta", clear

keep report_month group_type org* wait*

save "IAPT_wait.dta", replace


**************************************************************************
* 2. Keep valid CCG observations
**************************************************************************

keep if group_type == "CCG"

drop if org_code_missing == 1
drop if trim(org_code1) == ""

rename org_code1 ccg_code
rename org_name1 ccg_name

replace ccg_code = upper(trim(ccg_code))
replace ccg_name = trim(ccg_name)


**************************************************************************
* 3. Correct the date
*
* report_month is already a Stata monthly date.
* Therefore, do not use mofd(report_month).
**************************************************************************

format report_month %tm

gen int mdate = report_month
format mdate %tm

gen int calendar_year = year(dofm(mdate))
gen byte calendar_month = month(dofm(mdate))

* April geography vintage
gen int vintage = calendar_year

replace vintage = calendar_year - 1 ///
    if calendar_month <= 3


**************************************************************************
* 4. Check the date
**************************************************************************

assert mdate == report_month

assert mdate == ///
    ym(calendar_year, calendar_month)

assert inrange(calendar_year, 2015, 2022)

assert inrange(calendar_month, 1, 12)


**************************************************************************
* 5. Check uniqueness
**************************************************************************

isid ccg_code mdate


**************************************************************************
* 6. Construct access measures
**************************************************************************

gen double access_6w = ///
    wait_0_6w / wait_total ///
    if wait_total > 0 ///
    & !missing(wait_0_6w)

gen double access_18w = ///
    wait_0_18w / wait_total ///
    if wait_total > 0 ///
    & !missing(wait_0_18w)


**************************************************************************
* 7. Construct delay measures
*
* Higher value = worse access / longer delay
**************************************************************************

gen double delay_6w = 1 - access_6w

gen double delay_18w = 1 - access_18w

gen double over18_rate = ///
    wait_over18w / wait_total ///
    if wait_total > 0 ///
    & !missing(wait_over18w)


**************************************************************************
* 8. Labels
**************************************************************************

label variable access_6w ///
    "Share starting treatment within 6 weeks"

label variable access_18w ///
    "Share starting treatment within 18 weeks"

label variable delay_6w ///
    "Share not starting treatment within 6 weeks"

label variable delay_18w ///
    "Share not starting treatment within 18 weeks"

label variable over18_rate ///
    "Share recorded as waiting over 18 weeks"


**************************************************************************
* 9. Check that proportions are between zero and one
**************************************************************************

assert inrange(access_6w,0,1) ///
    if !missing(access_6w)

assert inrange(access_18w,0,1) ///
    if !missing(access_18w)

assert inrange(delay_6w,0,1) ///
    if !missing(delay_6w)

assert inrange(delay_18w,0,1) ///
    if !missing(delay_18w)

assert inrange(over18_rate,0,1) ///
    if !missing(over18_rate)


**************************************************************************
* 10. Keep final variables
**************************************************************************

keep ///
    report_month ///
    mdate ///
    calendar_year ///
    calendar_month ///
    vintage ///
    ccg_code ///
    ccg_name ///
    wait_total ///
    wait_0_6w ///
    wait_0_18w ///
    wait_over18w ///
    access_6w ///
    access_18w ///
    delay_6w ///
    delay_18w ///
    over18_rate


**************************************************************************
* 11. Arrange and sort
**************************************************************************

order ///
    report_month ///
    mdate ///
    calendar_year ///
    calendar_month ///
    vintage ///
    ccg_code ///
    ccg_name ///
    wait_total ///
    wait_0_6w ///
    access_6w ///
    delay_6w ///
    wait_0_18w ///
    access_18w ///
    delay_18w ///
    wait_over18w ///
    over18_rate

sort mdate ccg_code

compress


**************************************************************************
* 12. Final checks
**************************************************************************

isid ccg_code mdate

assert report_month == mdate

assert calendar_year == year(dofm(mdate))

assert calendar_month == month(dofm(mdate))


**************************************************************************
* 13. Display date check
**************************************************************************

list ///
    report_month ///
    mdate ///
    calendar_year ///
    calendar_month ///
    vintage ///
    ccg_code ///
    in 1/10, ///
    noobs separator(0)

tab calendar_year

tab vintage

summarize ///
    access_6w ///
    delay_6w ///
    access_18w ///
    delay_18w ///
    over18_rate


**************************************************************************
* 14. Save final data
**************************************************************************

save "IAPT_CCG_month_clean.dta", replace

display as result ///
    "Successfully created IAPT_CCG_month_clean.dta"