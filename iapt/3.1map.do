/**************************************************************************
* PROJECT:
* Spatial distribution of IAPT therapy availability across 2019 CCGs
*
* OUTPUT:
* 1. IAPT_CCG_2019_mapdata.dta
* 2. CCG2019_map.dta
* 3. CCG2019_map_shp.dta
* 4. CCG2019_therapy_map_ready.dta
* 5. Five CCG-level PNG maps
*
* IMPORTANT:
* Run the entire do-file from the first line.
**************************************************************************/

clear all
set more off
set linesize 255


/**************************************************************************
* 1. FILE PATHS
**************************************************************************/

* Folder containing the cleaned IAPT data and the 2019 LSOA-CCG lookup
global datadir ///
    "C:/Users/hm21806/Desktop/chapter3/code_iapt"

* The lookup is currently assumed to be in the same folder
global lookupdir ///
    "C:/Users/hm21806/Desktop/chapter3/code_iapt"

* Folder containing the extracted 2019 CCG shapefile
global mapdir ///
    "C:/Users/hm21806/Desktop/chapter3/IAPT/geo/Clinical_Commissioning_Groups_April_2019_Boundaries_EN_BGC_2022_7677579595874402498"

* Folder for all map outputs
global outdir ///
    "C:/Users/hm21806/Desktop/chapter3/IAPT/geo/map_output"

capture mkdir "$outdir"


/**************************************************************************
* 2. DEFINE INPUT FILENAMES
**************************************************************************/

global iaptfile ///
    "$datadir/IAPT_CCG_month_clean.dta"

global lookupfile ///
    "$lookupdir/LSOA11_CCG19_LAD19_EN_LU_b15d0240099643b6a303f24ccc04da06_6577294720128586166.csv"

* Do not add .shp here
global shapefile ///
    "$mapdir/CCG_APR_2019_EN_BGC"


/**************************************************************************
* 3. CHECK THAT ALL INPUT FILES EXIST
**************************************************************************/

confirm file "$iaptfile"
confirm file "$lookupfile"
confirm file "$shapefile.shp"
confirm file "$shapefile.dbf"
confirm file "$shapefile.shx"

display as result "All required input files were found."


/**************************************************************************
* 4. PREPARE 2019/20 CCG-LEVEL IAPT DATA
*
* The April 2019 CCG geography is used.
* Therefore, the principal mapping period is:
* April 2019 to March 2020.
**************************************************************************/

use "$iaptfile", clear

describe

* Confirm the essential variables
confirm variable ccg_code
confirm variable mdate
confirm variable wait_total
confirm variable wait_0_6w
confirm variable wait_0_18w
confirm variable wait_over18w

* Standardise the IAPT three-character CCG code
replace ccg_code = upper(trim(ccg_code))

* Check monthly date
format mdate %tm

* Keep April 2019 to March 2020
keep if inrange(mdate, tm(2019m4), tm(2020m3))

* Remove observations without a usable CCG code
drop if missing(ccg_code)

* Check period retained
summarize mdate
tabulate mdate

* Create an indicator for the number of contributing months
generate byte month_observation = 1

* Aggregate counts across the 12-month financial year
collapse ///
    (sum)  wait_total     ///
           wait_0_6w      ///
           wait_0_18w     ///
           wait_over18w   ///
    (count) n_months=month_observation, ///
    by(ccg_code)

* Construct annual CCG-level measures
generate double access6 = wait_0_6w / wait_total ///
    if wait_total > 0

generate double delay6 = 1 - access6 ///
    if !missing(access6)

generate double access18 = wait_0_18w / wait_total ///
    if wait_total > 0

generate double delay18 = 1 - access18 ///
    if !missing(access18)

generate double over18 = wait_over18w / wait_total ///
    if wait_total > 0

* Convert proportions into percentages for presentation
generate double access6_pct  = 100 * access6
generate double delay6_pct   = 100 * delay6
generate double access18_pct = 100 * access18
generate double delay18_pct  = 100 * delay18
generate double over18_pct   = 100 * over18

label variable access6_pct ///
    "Percentage accessing treatment within 6 weeks"

label variable delay6_pct ///
    "Percentage waiting longer than 6 weeks"

label variable access18_pct ///
    "Percentage accessing treatment within 18 weeks"

label variable delay18_pct ///
    "Percentage waiting longer than 18 weeks"

label variable over18_pct ///
    "Percentage recorded as waiting over 18 weeks"

* Validate percentage variables
assert inrange(access6_pct, 0, 100) ///
    if !missing(access6_pct)

assert inrange(delay6_pct, 0, 100) ///
    if !missing(delay6_pct)

assert inrange(access18_pct, 0, 100) ///
    if !missing(access18_pct)

assert inrange(delay18_pct, 0, 100) ///
    if !missing(delay18_pct)

assert inrange(over18_pct, 0, 100) ///
    if !missing(over18_pct)

* Check number of months contributing to each CCG
tabulate n_months
summarize access6_pct delay6_pct access18_pct delay18_pct over18_pct

save "$outdir/IAPT_CCG_2019_three_character.dta", replace


/**************************************************************************
* 5. CREATE BRIDGE BETWEEN:
*
* ccg_code = three-character NHS CCG code used in IAPT
* ccg19cd  = nine-character ONS CCG geography code used by the map
**************************************************************************/

import delimited using "$lookupfile", ///
    clear ///
    varnames(1) ///
    case(lower) ///
    stringcols(_all)

describe

* Confirm that the lookup contains both required codes
confirm variable ccg19cdh
confirm variable ccg19cd

* Retain only the CCG-code correspondence
keep ccg19cdh ccg19cd

rename ccg19cdh ccg_code

* Standardise codes
replace ccg_code = upper(trim(ccg_code))
replace ccg19cd   = upper(trim(ccg19cd))

* Remove unusable observations
drop if missing(ccg_code)
drop if missing(ccg19cd)

* Many LSOAs belong to the same CCG, so remove repeated pairs
duplicates drop ccg_code ccg19cd, force

* Check whether any NHS CCG code points to more than one ONS CCG code
bysort ccg_code: generate long number_of_map_codes = _N
tabulate number_of_map_codes

* Retain unique code relationships
keep if number_of_map_codes == 1
drop number_of_map_codes

isid ccg_code

save "$outdir/CCG19_code_bridge.dta", replace


/**************************************************************************
* 6. ATTACH THE NINE-CHARACTER MAP CODE TO THE IAPT DATA
**************************************************************************/

use "$outdir/IAPT_CCG_2019_three_character.dta", clear

merge 1:1 ccg_code using "$outdir/CCG19_code_bridge.dta"

* Examine the matching result carefully
tabulate _merge

* List IAPT CCG codes that did not match the 2019 lookup
list ccg_code wait_total n_months ///
    if _merge == 1, noobs abbreviate(20)

* Keep CCGs successfully matched to the 2019 map geography
keep if _merge == 3
drop _merge

isid ccg19cd

order ccg19cd ccg_code n_months ///
    wait_total wait_0_6w wait_0_18w wait_over18w ///
    access6_pct delay6_pct access18_pct delay18_pct over18_pct

sort ccg19cd

save "$outdir/IAPT_CCG_2019_mapdata.dta", replace


/**************************************************************************
* 7. CONVERT THE 2019 CCG SHAPEFILE INTO STATA DATASETS
*
* IMPORTANT CORRECTION:
* Do not write "using" after spshape2dta.
* The translated datasets must be saved in the current directory.
**************************************************************************/

cd "$outdir"

spshape2dta "$shapefile", ///
    saving("CCG2019_map") ///
    replace

* Confirm that conversion succeeded
confirm file "$outdir/CCG2019_map.dta"
confirm file "$outdir/CCG2019_map_shp.dta"

display as result "The shapefile was successfully converted."


/**************************************************************************
* 8. PREPARE THE MAP DATABASE
**************************************************************************/

use "$outdir/CCG2019_map.dta", clear

describe

* Standardise the ONS map code variable name
capture confirm variable CCG19CD

if _rc == 0 {
    rename CCG19CD ccg19cd
}

capture confirm variable ccg19cd

if _rc != 0 {
    display as error ///
        "The map database does not contain CCG19CD or ccg19cd."
    exit 111
}

replace ccg19cd = upper(trim(ccg19cd))

* Standardise CCG name where available
capture confirm variable CCG19NM

if _rc == 0 {
    rename CCG19NM ccg19nm
}

isid ccg19cd

save "$outdir/CCG2019_map_database_clean.dta", replace


/**************************************************************************
* 9. MERGE THE IAPT MEASURES INTO THE MAP DATABASE
**************************************************************************/

use "$outdir/CCG2019_map_database_clean.dta", clear

merge 1:1 ccg19cd ///
    using "$outdir/IAPT_CCG_2019_mapdata.dta"

tabulate _merge

* Display map areas without matched IAPT data
capture confirm variable ccg19nm

if _rc == 0 {
    list ccg19cd ccg19nm ///
        if _merge == 1, noobs abbreviate(30)
}
else {
    list ccg19cd ///
        if _merge == 1, noobs
}

* Retain all map polygons.
* CCGs without matched IAPT information will appear as missing on the map.
drop if _merge == 2
drop _merge

save "$outdir/CCG2019_therapy_map_ready.dta", replace


/**************************************************************************
* 10. INSTALL SPMAP IF NECESSARY
**************************************************************************/

capture which spmap

if _rc != 0 {
    ssc install spmap, replace
}


/**************************************************************************
* 11. MAP 1:
* ACCESSING TREATMENT WITHIN SIX WEEKS
**************************************************************************/

use "$outdir/CCG2019_therapy_map_ready.dta", clear

spmap access6_pct ///
    using "$outdir/CCG2019_map_shp.dta", ///
    id(_ID) ///
    clmethod(quantile) ///
    clnumber(5) ///
    fcolor(Blues) ///
    ocolor(gs10 ..) ///
    osize(vthin ..) ///
    ndocolor(gs14) ///
    title("IAPT therapy availability across CCGs") ///
    subtitle("Percentage accessing treatment within six weeks") ///
    note("April 2019–March 2020") ///
    legend(position(5) size(small)) ///
    name(map_access6, replace)

graph export "$outdir/CCG_access_within_6_weeks.png", ///
    width(2400) replace


/**************************************************************************
* 12. MAP 2:
* WAITING LONGER THAN SIX WEEKS
**************************************************************************/

spmap delay6_pct ///
    using "$outdir/CCG2019_map_shp.dta", ///
    id(_ID) ///
    clmethod(quantile) ///
    clnumber(5) ///
    fcolor(Reds) ///
    ocolor(gs10 ..) ///
    osize(vthin ..) ///
    ndocolor(gs14) ///
    title("IAPT waiting-time pressure across CCGs") ///
    subtitle("Percentage waiting longer than six weeks") ///
    note("April 2019–March 2020") ///
    legend(position(5) size(small)) ///
    name(map_delay6, replace)

graph export "$outdir/CCG_waiting_over_6_weeks.png", ///
    width(2400) replace


/**************************************************************************
* 13. MAP 3:
* ACCESSING TREATMENT WITHIN EIGHTEEN WEEKS
**************************************************************************/

spmap access18_pct ///
    using "$outdir/CCG2019_map_shp.dta", ///
    id(_ID) ///
    clmethod(quantile) ///
    clnumber(5) ///
    fcolor(Greens) ///
    ocolor(gs10 ..) ///
    osize(vthin ..) ///
    ndocolor(gs14) ///
    title("IAPT therapy availability across CCGs") ///
    subtitle("Percentage accessing treatment within eighteen weeks") ///
    note("April 2019–March 2020") ///
    legend(position(5) size(small)) ///
    name(map_access18, replace)

graph export "$outdir/CCG_access_within_18_weeks.png", ///
    width(2400) replace


/**************************************************************************
* 14. MAP 4:
* WAITING LONGER THAN EIGHTEEN WEEKS
**************************************************************************/

spmap delay18_pct ///
    using "$outdir/CCG2019_map_shp.dta", ///
    id(_ID) ///
    clmethod(quantile) ///
    clnumber(5) ///
    fcolor(Oranges) ///
    ocolor(gs10 ..) ///
    osize(vthin ..) ///
    ndocolor(gs14) ///
    title("IAPT waiting-time pressure across CCGs") ///
    subtitle("Percentage waiting longer than eighteen weeks") ///
    note("April 2019–March 2020") ///
    legend(position(5) size(small)) ///
    name(map_delay18, replace)

graph export "$outdir/CCG_waiting_over_18_weeks.png", ///
    width(2400) replace


/**************************************************************************
* 15. MAP 5:
* SHARE EXPLICITLY RECORDED IN THE OVER-18-WEEK CATEGORY
**************************************************************************/

spmap over18_pct ///
    using "$outdir/CCG2019_map_shp.dta", ///
    id(_ID) ///
    clmethod(quantile) ///
    clnumber(5) ///
    fcolor(Purples) ///
    ocolor(gs10 ..) ///
    osize(vthin ..) ///
    ndocolor(gs14) ///
    title("IAPT long waits across CCGs") ///
    subtitle("Percentage recorded as waiting over eighteen weeks") ///
    note("April 2019–March 2020") ///
    legend(position(5) size(small)) ///
    name(map_over18, replace)

graph export "$outdir/CCG_recorded_over_18_weeks.png", ///
    width(2400) replace


/**************************************************************************
* 16. COMBINE THE FOUR PRINCIPAL MAPS
**************************************************************************/

graph combine ///
    map_access6 ///
    map_delay6 ///
    map_access18 ///
    map_delay18, ///
    cols(2) ///
    xsize(12) ///
    ysize(10) ///
    title("Spatial distribution of IAPT therapy availability") ///
    note("CCG geography: April 2019; IAPT period: April 2019–March 2020") ///
    name(combined_therapy_maps, replace)

graph export "$outdir/CCG_therapy_availability_combined.png", ///
    width(3600) replace


/**************************************************************************
* 17. SAVE A SUMMARY TABLE
**************************************************************************/

use "$outdir/CCG2019_therapy_map_ready.dta", clear

summarize ///
    access6_pct ///
    delay6_pct ///
    access18_pct ///
    delay18_pct ///
    over18_pct, detail

save "$outdir/CCG2019_therapy_map_ready.dta", replace

display as result "-------------------------------------------------------"
display as result "All CCG maps were created successfully."
display as result "Output folder:"
display as result "$outdir"
display as result "-------------------------------------------------------"

clear