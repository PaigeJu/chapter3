
clear all
set more off
global input "C:/Users/hm21806/Desktop/chapter3/code_iapt/IAPT_wait.dta"
global figures "C:/Users/hm21806/Desktop/chapter3/code_iapt/meeting_figures"
capture mkdir "$figures"


use "$input", clear
replace org_code1 = strtrim(org_code1)
gen byte excluded = inlist(lower(org_code1),"","0","invalidcode","all")
/* Hub codes identified from names in the supplied data, including their
   early observations with missing names. This is not a full ODS validation. */
foreach code in 13Q 13R 14A 14E 14M 14Q 14R 14T 32T 76A 97T {
    replace excluded = 1 if org_code1 == "`code'"
}
preserve
keep if excluded
keep org_code1 org_name1
duplicates drop
export delimited using "$figures/excluded_organisations.csv", replace
restore
keep if !excluded
assert inlist(group_type,"CCG","SubICB")
isid org_code1 report_month
format report_month %tm

gen double p6 = 100*(1-wait_0_6w/wait_total) ///
    if wait_total>0 & !missing(wait_total,wait_0_6w)
assert inrange(p6,0,100) if !missing(p6)
gen byte one=1
gen byte miss6=missing(p6)
gen byte miss18=missing(wait_over18w)
collapse (sum) observed_total=wait_total n_units=one ///
    (count) n_total=wait_total n_p6=p6 ///
    (p25) q25=p6 (p50) median=p6 (p75) q75=p6 ///
    (mean) missing6=miss6 missing18=miss18, by(report_month)
replace observed_total=. if n_total==0
gen double total_thousands=observed_total/1000
replace missing6=100*missing6
replace missing18=100*missing18
sort report_month
save "$figures/monthly_plot_data.dta", replace
export delimited using "$figures/monthly_plot_data.csv", replace


ex
***descriptive raw figures about waiting time


* 1. Observed waiting-list total
local switch=ym(2022,7)
local common "graphregion(color(white)) xtitle(Reporting month) xline(`switch', lpattern(dot) lcolor(gs10))"
twoway line total_thousands report_month, `common' ///
    title("A  Observed waiting-list total", size(medsmall)) ///
    ytitle("Reported counts (thousands)") lcolor(purple) ///
    note("Available values only; not the published England total.",size(vsmall)) ///
    name(g_total, replace)
graph export "$figures/01_waiting_total.png", width(2000) replace


*2.Share waiting longer than 6 weeks
twoway (rarea q25 q75 report_month, color(purple%18) lwidth(none)) ///
    (line median report_month, lcolor(purple)), `common' ///
    title("B  Share waiting longer than 6 weeks",size(medsmall)) ///
    ytitle("Percent of waiting list") ///
    legend(order(1 "25th-75th percentile" 2 "Median") size(small)) ///
    note("Unweighted across reporting units; changing geography.",size(vsmall)) ///
    name(g_share,replace)
graph export "$figures/02_waiting_share.png", width(2000) replace



**choice indicators...
*3.Availability of the waiting indicators
twoway (line missing6 report_month, lcolor(teal)) ///
    (line missing18 report_month, lcolor(orange)), `common' ///
    title("C  Indicator availability",size(medsmall)) ///
    ytitle("Reporting units missing (%)") ylabel(0(20)100) ///
    legend(order(1 "6-week share unavailable" 2 "Over-18-week count unavailable") size(small)) ///
    note("Missing includes absent indicators and suppressed values.",size(vsmall)) ///
    name(g_missing,replace)
graph export "$figures/03_missing_values.png", width(2000) replace


*4.Number of included reporting units
twoway line n_units report_month, `common' lcolor(teal) ///
    title("D  Included reporting units",size(medsmall)) ///
    ytitle("CCG / SubICB codes") ///
    note("Not a fixed-geography panel.",size(vsmall)) name(g_units,replace)
	
	
*
graph export "$figures/04_reporting_units.png", width(2000) replace
graph combine g_total g_share g_missing g_units, cols(2) ///
    graphregion(color(white)) xsize(14) ysize(10) ///
    title("IAPT / NHS Talking Therapies: descriptive evidence")
graph export "$figures/IAPT_meeting_figures.png", width(2800) replace
