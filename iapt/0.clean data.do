
clear all
set more off

global rawdir "C:\Users\hm21806\Desktop\chapter3\IAPT\IPAT_monthly"
global outdir "C:\Users\hm21806\Desktop\chapter3\code_iapt"
if lower("$rawdir") == lower("$outdir") {
    display as error "Use separate input and output directories."
    exit 198
}
capture mkdir "$outdir"
capture log close _all
log using "$outdir/extract_waiting_times.log", text replace

capture program drop extract_wait_table
program define extract_wait_table
    version 16.0
    syntax, FILEMonth(real)
    /* Input: all columns as strings; header still a data row. */
    quietly ds
    local original `r(varlist)'
    local header 0
    local layout ""
    if _N == 0 exit 2000
    local top = min(100,_N)
    forvalues j = 1/`top' {
        local has_measure 0
        local has_ccg 0
        local has_provider 0
        local has_group 0
        local has_month 0
        foreach v of local original {
            local h = ustrregexra(ustrlower(ustrtrim(`v'[`j'])),"[^a-z0-9]","")
            if "`h'" == "measurename" local has_measure 1
            if "`h'" == "ccg" local has_ccg 1
            if "`h'" == "provider" local has_provider 1
            if "`h'" == "grouptype" local has_group 1
            if "`h'" == "month" local has_month 1
        }
        if `has_measure' {
            local header `j'
            local layout "long"
        }
        else if `has_ccg' & `has_provider' & `has_group' & `has_month' {
            local header `j'
            local layout "wide"
        }
        if `header' > 0 continue, break
    }
    if `header' == 0 {
        display as error "No supported header in the first 100 rows."
        list in 1/`=min(3,_N)', noobs abbreviate(24)
        exit 498
    }
    display as text "Detected `layout' header in row `header'."
    /* Prefer the published suppressed value if BOTH value columns exist. */
    local value_column ""
    local value_priority 0
    foreach v of local original {
        local h = ustrregexra(ustrlower(ustrtrim(`v'[`header'])),"[^a-z0-9]","")
        local priority 0
        if "`h'" == "measurevalue" local priority 1
        if "`h'" == "measurevaluesuppressed" local priority 2
        if `priority' > `value_priority' {
            local value_column "`v'"
            local value_priority `priority'
        }
    }
    if "`layout'" == "long" & "`value_column'" == "" {
        display as error "Missing MEASURE_VALUE or MEASURE_VALUE_SUPPRESSED. Headers:"
        foreach v of local original {
            display as text `v'[`header']
        }
        exit 111
    }
    local wanted ""
    local k 0
    foreach v of local original {
        local rawname = strtrim(`v'[`header'])
        local h = ustrregexra(ustrlower(ustrtrim("`rawname'")),"[^a-z0-9]","")
        local target ""
        if inlist("`h'","reportingperiodstart","month") local target report_start_raw
        if "`h'" == "reportingperiodend" local target report_end_raw
        if "`h'" == "grouptype" local target group_type
        if inlist("`h'","orgcode1","ccg") local target org_code1
        if inlist("`h'","orgname1","ccgname") local target org_name1
        if inlist("`h'","orgcode2","provider") local target org_code2
        if inlist("`h'","orgname2","providername") local target org_name2
        if "`layout'" == "long" {
            if "`h'" == "measureid" local target measure_id
            if "`h'" == "measurename" local target measure_name
            if "`v'" == "`value_column'" local target value_raw
        }
        if "`layout'" == "wide" & strpos("`h'","wait") > 0 {
            local ++k
            local mn`k' "`rawname'"
            local target w`k'
        }
        if "`target'" != "" {
            rename `v' `target'
            local wanted `wanted' `target'
        }
    }
    keep `wanted'
    drop in 1/`header'
    foreach v in report_start_raw group_type org_code1 org_code2 {
        confirm string variable `v'
    }
    /* Jan/Feb 2015 genuinely have no organisation-name columns.
       Keep their codes; do not invent names or borrow names across boundaries. */
    foreach v in org_name1 org_name2 {
        capture confirm variable `v'
        if _rc generate str1 `v' = ""
    }
    capture confirm variable report_end_raw
    if _rc generate str40 report_end_raw = ""
    generate long source_row = _n + `header'
    if "`layout'" == "wide" {
        if `k' == 0 exit 498
        tempfile measuremap
        preserve
        clear
        set obs `k'
        generate int slot = _n
        generate str160 measure_name = ""
        forvalues j = 1/`k' {
            replace measure_name = "`mn`j''" in `j'
        }
        save `measuremap', replace
        restore
        reshape long w, i(source_row) j(slot)
        rename w value_raw
        merge m:1 slot using `measuremap', assert(match) nogen
        drop slot
        generate str20 measure_id = ""
    }
    else {
        confirm string variable measure_name value_raw
        capture confirm variable measure_id
        if _rc generate str20 measure_id = ""
        keep if strpos(lower(measure_name),"wait") > 0
    }
    if _N == 0 exit 2000
    generate str8 source_layout = "`layout'"
    generate str40 value_source_header = "wide_indicator_columns"
    if "`layout'" == "long" {
        replace value_source_header = "MEASURE_VALUE" if `value_priority' == 1
        replace value_source_header = "MEASURE_VALUE_SUPPRESSED" if `value_priority' == 2
    }
    foreach v in report_start_raw report_end_raw group_type org_code1 org_name1 org_code2 org_name2 measure_name measure_id value_raw {
        replace `v' = strtrim(`v')
    }
    /* Counts, means and medians remain distinct. Keep original names as well. */
    generate str160 measure_key = lower(subinstr(measure_name,"_","",.))
    replace measure_key = substr(measure_key,6,.) if substr(measure_key,1,5)=="count"
    generate double value = real(subinstr(value_raw,",","",.))
    generate byte value_non_numeric = missing(value) & value_raw != ""
    generate byte value_blank = value_raw == ""
    /* No suppression token is recoded to zero or a guessed count.
       Parse BOTH DMY and MDY. For ambiguous numeric dates, accept a candidate
       only if its month uniquely agrees with the filename month. ISO dates and
       Excel serial dates are parsed separately. A true disagreement is flagged. */
    generate int report_month_before_fix = mofd(daily(report_start_raw,"YMD"))
    replace report_month_before_fix = mofd(daily(report_start_raw,"DMY")) ///
        if missing(report_month_before_fix)
    foreach part in start end {
        tempvar dmy mdy yearfirst
        generate byte `yearfirst' = regexm(report_`part'_raw, ///
            "^[0-9][0-9][0-9][0-9][-/.]")
        generate double report_`part' = daily(report_`part'_raw,"YMD") if `yearfirst'
        generate double `dmy' = daily(report_`part'_raw,"DMY") if !`yearfirst'
        generate double `mdy' = daily(report_`part'_raw,"MDY") if !`yearfirst'
        generate byte date_ambiguous_`part' = !missing(`dmy',`mdy') & `dmy' != `mdy'
        generate byte date_by_filename_`part' = 0
        replace report_`part' = `dmy' if !`yearfirst' & !date_ambiguous_`part' & !missing(`dmy')
        replace report_`part' = `mdy' if !`yearfirst' & !date_ambiguous_`part' & missing(`dmy')
        replace date_by_filename_`part' = 1 if date_ambiguous_`part' & ///
            !missing(`filemonth') & ///
            ((mofd(`dmy') == `filemonth') != (mofd(`mdy') == `filemonth'))
        replace report_`part' = `dmy' if date_by_filename_`part' & mofd(`dmy') == `filemonth'
        replace report_`part' = `mdy' if date_by_filename_`part' & mofd(`mdy') == `filemonth'
        replace report_`part' = real(report_`part'_raw) + td(30dec1899) ///
            if missing(report_`part') & inrange(real(report_`part'_raw),20000,80000)
        generate byte date_unresolved_`part' = date_ambiguous_`part' & missing(report_`part')
        drop `dmy' `mdy' `yearfirst'
    }
    generate int report_month = mofd(report_start)
    replace report_month = monthly(itrim(subinstr(report_start_raw,"-"," ",.)),"MY",2099) ///
        if missing(report_month) & !date_unresolved_start & ///
        regexm(strtrim(report_start_raw),"^[A-Za-z]+[ -]+[0-9]+$")
    generate byte date_corrected = !missing(report_month,report_month_before_fix) & ///
        report_month != report_month_before_fix
    generate byte period_inconsistent = !missing(report_start,report_end) & ///
        (report_end < report_start | mofd(report_start) != mofd(report_end))
    format report_start report_end %tdCCYY-NN-DD
    format report_month report_month_before_fix %tm

end

tempfile combined
tempname manifest
postfile `manifest' str244 source_file str100 source_sheet str40 status ///
    long rc long waiting_rows using "$outdir/import_audit.dta", replace
local accepted 0
local months jan feb mar apr may jun jul aug sep oct nov dec
local files : dir "$rawdir" files "*"
foreach f of local files {
    local lf = lower("`f'")
    if substr("`f'",1,2)=="~$" continue
    if !regexm("`lf'","[.](csv|xls|xlsx)$") continue
    local file_month .
    local m 0
    foreach mo of local months {
        local ++m
        if regexm("`lf'","(^|[-_ ])`mo'[a-z]*[-_ ]([12][0-9][0-9][0-9])") {
            local yr = real(regexs(2))
            local file_month = ym(`yr',`m')
        }
    }
    local iscsv = regexm("`lf'","[.]csv$")
    local nsheets 1
    if !`iscsv' {
        capture noisily import excel using "$rawdir/`f'", describe
        local err = _rc
        if `err' {
            post `manifest' ("`f'") ("") ("EXCEL_DESCRIBE_FAILED") (`err') (0)
            continue
        }
        local nsheets = r(N_worksheet)
        forvalues s = 1/`nsheets' {
            local sheet`s' `"`r(worksheet_`s')'"'
        }
    }
    forvalues s = 1/`nsheets' {
        local sh ""
        display as text "Reading file: `f' (sheet number `s')"
        if `iscsv' {
            capture noisily import delimited using "$rawdir/`f'", clear ///
                varnames(nonames) delimiters(",") stringcols(_all) encoding("utf-8") bindquote(strict)
        }
        else {
            local sh `"`sheet`s''"'
            capture noisily import excel using "$rawdir/`f'", sheet(`"`sh'"') allstring clear
        }
        local err = _rc
        if `err' {
            post `manifest' ("`f'") (`"`sh'"') ("IMPORT_FAILED") (`err') (0)
            continue
        }
        capture noisily extract_wait_table, filemonth(`file_month')
        local err = _rc
        if `err' {
            post `manifest' ("`f'") (`"`sh'"') ("UNSUPPORTED_OR_EMPTY_CHECK_LOG") (`err') (0)
            continue
        }
        generate str244 source_file = "`f'"
        generate str100 source_sheet = `"`sh'"'
        generate int filename_month = `file_month'
        format filename_month %tm
        generate byte month_from_filename = missing(report_month) & !missing(filename_month) & !date_unresolved_start
        replace report_month = filename_month if month_from_filename
        generate byte month_conflict = !missing(report_month,filename_month) & report_month != filename_month
        generate byte end_month_conflict = !missing(report_end,filename_month) & mofd(report_end) != filename_month
        local n = _N
        post `manifest' ("`f'") (`"`sh'"') ("EXTRACTED") (0) (`n')
        compress
        if `accepted' > 0 append using `combined'
        save `combined', replace
        local ++accepted
    }
}
postclose `manifest'
if `accepted' == 0 {
    display as error "No supported tables extracted. Read import_audit.dta and the log."
    log close
    exit 2000
}
use `combined', clear
generate byte org_code_missing = org_code1 == "" | org_code2 == ""
generate byte org_name_missing = org_name1 == "" | org_name2 == ""
/* Names are deliberately excluded from the duplicate key. Do not silently
   choose between revisions, duplicated CSV/Excel exports or conflicting rows. */
duplicates tag report_month group_type org_code1 org_code2 measure_key, generate(duplicate_key)
sort report_month group_type org_code1 org_code2 measure_key source_file source_row
order report_month report_start_raw report_end_raw group_type org_code1 org_name1 ///
    org_code2 org_name2 measure_key measure_name measure_id value value_raw
save "$outdir/waiting_all_long.dta", replace
export delimited using "$outdir/waiting_all_long.csv", replace

preserve
keep if duplicate_key > 0 | month_conflict | missing(report_month) | org_code_missing ///
    | org_name_missing | date_unresolved_start | date_unresolved_end ///
    | period_inconsistent | end_month_conflict
save "$outdir/records_to_review.dta", replace
restore

/* One row per source period for checking date interpretation, including fixes. */
preserve
keep source_file source_sheet report_start_raw report_end_raw filename_month ///
    report_month report_month_before_fix report_start report_end ///
    date_ambiguous_* date_by_filename_* date_unresolved_* date_corrected ///
    month_from_filename month_conflict end_month_conflict period_inconsistent
duplicates drop
sort report_month source_file
save "$outdir/date_audit.dta", replace
export delimited using "$outdir/date_audit.csv", replace
restore

/* Organisation-month grid from ALL waiting measures, so May 2015 is retained
   even though its six week-threshold measures are absent. */
egen long unit = group(source_file source_sheet report_month group_type ///
    org_code1 org_name1 org_code2 org_name2), missing
tempfile grid
preserve
keep unit source_file source_sheet report_month group_type org_code1 org_name1 org_code2 org_name2 ///
    report_start_raw report_end_raw report_start report_end filename_month ///
    report_month_before_fix date_ambiguous_* date_by_filename_* date_unresolved_* ///
    date_corrected month_from_filename month_conflict end_month_conflict ///
    period_inconsistent org_code_missing org_name_missing
duplicates drop
isid unit
save `grid', replace
restore
generate str24 metric = ""
replace metric = "wait_total" if measure_key == "waitingfortreatment"
foreach w in 2 4 6 12 18 {
    replace metric = "wait_0_`w'w" if measure_key == "waitingfortreatment0to`w'weeks"
}
replace metric = "wait_over18w" if measure_key == "waitingfortreatmentover18weeks"
keep if metric != ""
capture isid unit metric
if _rc {
    display as error "Duplicate core measures WITHIN a source table: wide output not created."
    save "$outdir/core_duplicates_input.dta", replace
    log close
    exit 459
}
keep unit metric value value_raw
generate byte available = 1
reshape wide value value_raw available, i(unit) j(metric) string
merge 1:1 unit using `grid', assert(match using) nogen
foreach v in wait_total wait_0_2w wait_0_4w wait_0_6w wait_0_12w wait_0_18w wait_over18w {
    capture confirm variable value`v'
    if _rc {
        generate double value`v' = .
        generate str1 value_raw`v' = ""
        generate byte available`v' = 0
    }
    rename value`v' `v'
    rename value_raw`v' raw_`v'
    rename available`v' has_`v'
    replace has_`v' = 0 if missing(has_`v')
}
drop unit
duplicates tag report_month group_type org_code1 org_code2, generate(duplicate_org_month)
sort report_month group_type org_code1 org_code2 source_file
order report_month group_type org_code1 org_name1 org_code2 org_name2 wait_total wait_0_* wait_over18w
save "$outdir/waiting_core_wide.dta", replace
export delimited using "$outdir/waiting_core_wide.csv", replace
/* Preserve changing boundaries: this is NOT a harmonised geographical panel. */
keep if inlist(lower(group_type),"ccg","subicb")
save "$outdir/waiting_commissioners_wide.dta", replace
export delimited using "$outdir/waiting_commissioners_wide.csv", replace
use "$outdir/import_audit.dta", clear
export delimited using "$outdir/import_audit.csv", replace
list source_file source_sheet status waiting_rows, noobs abbreviate(30)
quietly count if status != "EXTRACTED"
local failed = r(N)
display as result "Done. Tables/sheets not extracted: `failed'."
display as text "Review import_audit, date_audit and records_to_review before analysis."
display as text "Missing names in Jan/Feb 2015 are source omissions, not import failures."
log close
