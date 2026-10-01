
clear all
set more off

cd "C:\Users\hm21806\Desktop\chapter3\code_iapt"
use waiting_commissioners_wide, clear

*keep variables 
keep report_month group_type org* wait* 
save IAPT_wait, replace 



*map only CCG (2015-2021)
use "IAPT_wait.dta", clear

*------------------------------------------------------------*
* 1. 只保留有效的 commissioner-level observations
*------------------------------------------------------------*

keep if group_type == "CCG"
drop if org_code_missing == 1
drop if trim(org_code1) == ""

rename org_code1 ccg_code
rename org_name1 ccg_name

* 检查唯一性
isid ccg_code report_month

*------------------------------------------------------------*
* 2. 创建月份
* report_month 如果已经是 Stata daily date
*------------------------------------------------------------*

gen mdate = mofd(report_month)
format mdate %tm

gen calendar_year  = year(report_month)
gen calendar_month = month(report_month)

* April geography vintage:
* Jan–Mar使用上一年4月开始的CCG geography
gen vintage = calendar_year
replace vintage = calendar_year - 1 if calendar_month <= 3

*------------------------------------------------------------*
* 3. 构造等待指标
*------------------------------------------------------------*

gen access_6w  = wait_0_6w  / wait_total ///
    if wait_total > 0 & !missing(wait_0_6w)

gen access_18w = wait_0_18w / wait_total ///
    if wait_total > 0 & !missing(wait_0_18w)

* 数值越高表示等待问题越严重
gen delay_6w  = 1 - access_6w
gen delay_18w = 1 - access_18w

* 超过18周比例
gen over18_rate = wait_over18w / wait_total ///
    if wait_total > 0 & !missing(wait_over18w)

label variable access_6w ///
    "Share starting treatment within 6 weeks"

label variable access_18w ///
    "Share starting treatment within 18 weeks"

label variable delay_6w ///
    "Share not starting treatment within 6 weeks"

label variable delay_18w ///
    "Share not starting treatment within 18 weeks"

label variable over18_rate ///
    "Share waiting over 18 weeks"

* 检查比例
summarize access_6w access_18w delay_6w delay_18w ///
    over18_rate, detail

assert inrange(access_6w,0,1) if !missing(access_6w)
assert inrange(access_18w,0,1) if !missing(access_18w)

keep report_month mdate vintage ccg_code ccg_name ///
     wait_total access_6w access_18w ///
     delay_6w delay_18w over18_rate

save "IAPT_CCG_month_clean.dta", replace









