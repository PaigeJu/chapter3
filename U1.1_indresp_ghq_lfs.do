clear all
set more off

cd "C:\Users\hm21806\Desktop\understandingsociety\wave1_14\6614stata_F046A86812BD4CB19421770A796538481A92B83F3C2E9DE588205F27C722FED0_V1\UKDA-6614-stata\stata\stata13_se\ukhls"

global keeplist pidp dvage country ethn_dv hiqual_dv indinu*_* jbsoc*_cc jbisco88 urban_dv j*hrs jbstat intdaty_dv fimnlabgrs_dv pjbptft lnprnt lnadopt marstat_dv birthy fenow sex jbsat sclfsat2 sclfsat7 jbbgd jbbgm jbbgy istrtdatm istrtdatd istrtdaty intdatd_dv intdatm_dv jbendd jbendm jbendy4 nunmpsp_dv qfhigh_dv jbisco88_cc nunmpsp_dv ff_ivlolw jbsamr samejob jbsoc00chk nxtstend* julk4wk jlend* jlsoc00_cc notempchk empchk empstend* nmpsp_dv nxtst ff_jbstat nxtstelse cstat cjob nxtjbendd nxtjbendm nxtjbendy4 nextjob* currjob* statendd* statendm* statendy4* indpxui_lw indpx* memorig jbsic07_cc scghq* sppno sppid hidp impevent* event* inding2_xw aidhrs aidhua* aideft aidhh lkmove xpmove family indsc*

local impevent_vars impevent1 impevent1s impevent2 impevent2s impevent3 impevent3s impevent4 impevent4s
local event_vars event1 event1s event2 event2s event3 event3s event4 event4s

foreach wave in a b c d e f g h i j k l m n {
    use `wave'_indresp, clear
    rename `wave'_* *
    
    // keep event variables by waves
    if "`wave'" != "a" {
        foreach var in `impevent_vars' {
            capture confirm variable `var'
            if _rc {
                gen `var' = .
            }
        }
    }
    
    if !inlist("`wave'", "b", "e") {
        foreach var in `event_vars' {
            capture confirm variable `var'
            if _rc {
                gen `var' = .
            }
        }
    }
    
    keep ${keeplist}
    rename intdaty_dv year
    gen wave = index("abcdefghijklmnopqr","`wave'")
    sort pidp
    save ind_ukhls_`wave'_resp, replace
}

// append waves
use ind_ukhls_a_resp, clear
foreach wave in b c d e f g h i j k l m n {
    append using ind_ukhls_`wave'_resp
}


cd "C:\Users\hm21806\Desktop\chapter3\code202602_newjobf"


order wave year pidp sppid 

/////////////////////////////////////////////////

*interview times, gap,
bys pidp(wave): gen interview=[_n]
label variable interview "how many times this respondent has been interviewed so far"

gen fstinterview=interview==1
label variable fstinterview "=1 if it's the 1st interview for this respondent"

bys pidp(wave): gen lstinterview=interview==[_N]
label variable lstinterview "=1 if it's the last interview for this respondent"

xtset pidp wave
bys pidp: gen enter = l.wave ==.
bys pidp: gen quit = f.wave ==. 
label variable enter "=1, if the respondent is entering interview this wave, either first-time interviewed this wave, or come back from a gap"
label variable quit "=1, if the respondent is leaving interview next wave, either last-time interviewed this wave, or go into a gap next wave"

xtset pidp interview
bys pidp: gen intogap = (f.enter == 1 & enter == 0 & lstinterview != 1)
bys pidp: gen reenter = (f.enter == 0 & enter == 1 & fstinterview != 1)
label variable intogap "=1, if the respondent is going to gap in next wave"
label variable reenter "=1, if the respondent re-enter the interview from a gap in this wave"

*interview date(ddmmyyyy)
replace year=istrtdaty if year<0 //11 changes
label variable year "interview year"
gen month=int(istrtdatm)
replace month=1 if month ==. & year != . //0 changes
replace month=1 if month <0 & year != . //1040 changes
label variable month "interview month"
gen day=int(istrtdatd)
replace day=1 if day <0 & year != . //1040changes
label variable day "interview day"
replace day=28 if day==29 & month==2
gen idate=mdy(month,day,year) 
label variable idate "interviewed date"
format idate %td //interview date(ddmmyyyy)
xtset pidp idate  //unbalanced


*weight
*scale weight (ind in) 2010-2020
order pidp wave indinus_xw indinub_xw indinui_xw inding2_xw

gen b_indscub_xw = indscub_xw if wave == 2
gen c_indscub_xw = indscub_xw if wave == 3
gen d_indscub_xw = indscub_xw if wave == 4
gen e_indscub_xw = indscub_xw if wave == 5

gen f_indscui_xw = indscui_xw if wave == 6
gen g_indscui_xw = indscui_xw if wave == 7
gen h_indscui_xw = indscui_xw if wave == 8
gen i_indscui_xw = indscui_xw if wave == 9
gen j_indscui_xw = indscui_xw if wave == 10
gen k_indscui_xw = indscui_xw if wave == 11
gen l_indscui_xw = indscui_xw if wave == 12
gen m_indscui_xw = indscui_xw if wave == 13
gen n_indscui_xw = indscui_xw if wave == 14


ge weightscaled = 0
order pidp wave weightscaled indscus_xw indscub_xw indscui_xw

replace weightscaled = indscus_xw if wave == 1

ge ind=1

sum ind[aw=indscus_xw] if wave == 1
gen awtdtot=r(sum_w)

sum ind[aw=b_indscub_xw] if wave == 2
gen bwtdtot=r(sum_w)

sum ind[aw=c_indscub_xw] if wave == 3
gen cwtdtot=r(sum_w)

sum ind[aw=d_indscub_xw] if wave == 4
gen dwtdtot=r(sum_w)

sum ind[aw=e_indscub_xw] if wave == 5
gen ewtdtot=r(sum_w)

sum ind[aw=f_indscui_xw] if wave == 6
gen fwtdtot=r(sum_w)

sum ind[aw=g_indscui_xw] if wave == 7
gen gwtdtot=r(sum_w)

sum ind[aw=h_indscui_xw] if wave == 8
gen hwtdtot=r(sum_w)

sum ind[aw=i_indscui_xw] if wave == 9
gen iwtdtot=r(sum_w)

sum ind[aw=j_indscui_xw] if wave == 10
gen jwtdtot=r(sum_w)

sum ind[aw=k_indscui_xw] if wave == 11
gen kwtdtot=r(sum_w)

sum ind[aw=l_indscui_xw] if wave == 12
gen lwtdtot=r(sum_w)

sum ind[aw=m_indscui_xw] if wave == 13
gen mwtdtot=r(sum_w)

sum ind[aw=indscg2_xw] if wave == 14
gen nwtdtot=r(sum_w)


replace weightscaled= b_indscub_xw * (awtdtot/bwtdtot) if wave == 2
replace weightscaled= c_indscub_xw * (awtdtot/cwtdtot) if wave == 3
replace weightscaled= d_indscub_xw * (awtdtot/dwtdtot) if wave == 4
replace weightscaled= e_indscub_xw * (awtdtot/ewtdtot) if wave == 5

replace weightscaled= f_indscui_xw * (awtdtot/fwtdtot) if wave == 6
replace weightscaled= g_indscui_xw * (awtdtot/gwtdtot) if wave == 7
replace weightscaled= h_indscui_xw * (awtdtot/hwtdtot) if wave == 8
replace weightscaled= i_indscui_xw * (awtdtot/iwtdtot) if wave == 9
replace weightscaled= j_indscui_xw * (awtdtot/jwtdtot) if wave == 10
replace weightscaled= k_indscui_xw * (awtdtot/kwtdtot) if wave == 11
replace weightscaled= l_indscui_xw * (awtdtot/lwtdtot) if wave == 12
replace weightscaled= m_indscui_xw * (awtdtot/mwtdtot) if wave == 13
replace weightscaled= indscg2_xw * (awtdtot/nwtdtot) if wave == 14

sum ind[aw=weightscaled] if wave == 2
sum ind[aw=weightscaled] if wave == 4
sum ind[aw=weightscaled] if wave == 6
sum ind[aw=weightscaled] if wave == 8


order pidp wave interview fstinterview lstinterview intogap enter reenter quit


*labour force status
label list n_jbstat

gen lfs=.
label variable lfs "labour force status, 1 employed/self-employed,2 unemployed, 3 incative"

//wave 1 - 12
//(1)Employed (E): self-employed 1, paid employment 2, on maternity leave 5, in a government training program 9;
//(2)unemployed (U): individuals who reported have search for job in the last 4 weeks; 
//(3)Inactive (I): all other status: individuals who reported long-term sick, or full-time student, or doing family care, or retired, or unpaid family business(10), or on apprenticeship(11), or temporarily laid off/short term working(12), or doing something else(97). or report unemployed but didn't search for jobs in last 4 weeks.

replace lfs=1 if (jbstat==2 | jbstat==5 | jbstat==9 |jbstat==12 |jbstat==11 |jbstat==1 |jbstat==14 ) & inrange(wave,1,12) 

replace lfs=3 if (jbstat==8 | jbstat==7 | jbstat==6 | jbstat==4 | jbstat==10 | jbstat==13 | jbstat==97 | (jbstat == 3 & julk4wk != 1) ) & inrange(wave,1,12)

replace lfs=2 if julk4wk == 1 & inrange(wave,1,12)

//wave 13,14
//(1)Employed (E): self-employed 1, paid employment 2, on maternity leave 5, in a government training program 9;
//(2)unemployed (U): individuals who reported have search for job in the last 4 weeks; 
//(3)Inactive (I): all other status: individuals who reported long-term sick, or full-time student, or doing family care, or retired, or unpaid family business(10), or on apprenticeship(11), or temporarily laid off/short term working(12), or doing something else(97). or report unemployed but didn't search for jobs in last 4 weeks.

replace lfs=1 if (jbstat==2 | jbstat==5 | jbstat==9 |jbstat==12 |jbstat==11 |jbstat==1 |jbstat==14 |jbstat==15) & inrange(wave,13,14) 

replace lfs=3 if (jbstat==8 | jbstat==7 | jbstat==6 | jbstat==4 | jbstat==10 | jbstat==13 | jbstat==97 | (jbstat == 3 & julk4wk != 1) ) & inrange(wave,13,14)

replace lfs=2 if julk4wk == 1 & (jbstat!=2 & jbstat!=5 & jbstat!=9 &jbstat!=12 &jbstat!=11 &jbstat!=1 &jbstat!=14 &jbstat!=15 ) & inrange(wave,13,14)

tab lfs, missing //387 missing

*last period lfs
sort pidp wave 
gen lfs_f=.
replace lfs_f=1 if ff_jbstat==2 | ff_jbstat==5 | ff_jbstat==9 |ff_jbstat==12 |ff_jbstat==11  |ff_jbstat==1 | (julk4wk[_n-1] !=1 & julk4wk[_n-1] !=2)

by pidp : replace lfs_f=3 if ff_jbstat==8 | ff_jbstat==7 | ff_jbstat==6 | ff_jbstat==4 | ff_jbstat==10 | ff_jbstat==13 | ff_jbstat==97  | (julk4wk[_n-1] != 1 & jbstat[_n-1]== 3)  

by pidp : replace lfs_f=2 if  julk4wk[_n-1] == 1 

label variable lfs_f "respondent employment status at previous interview, 1 employed/self-employed,2 unemployed, 3 incative"

foreach i of numlist 1/14{
	replace lfs_f = lfs[_n-`i'] if lfs_f==. & lfs[_n-`i'] !=. & interview !=1
}


*spouse's labour force status
preserve
keep wave pidp lfs lfs_f
rename pidp sppid 
rename lfs sp_lfs 
rename lfs_f sp_lfs_f
sort wave sppid
tempfile spouse_lfs
save `spouse_lfs'
restore
merge m:1 wave sppid using `spouse_lfs', keep(master match) nogen

*spouse's GHQ
preserve
keep wave pidp scghq1_dv scghq*
rename pidp sppid 
rename scghq* sp_scghq*
sort wave sppid
tempfile spouse_scores
save `spouse_scores'
restore
merge m:1 wave sppid using `spouse_scores', keep(master match) nogen



gen ghq = scghq1_dv
gen sp_ghq = sp_scghq1_dv
order pidp wave lfs ghq sppid sp_lfs sp_ghq 
sort pidp wave 

sort pidp wave
by pidp (wave): gen ghq_l = ghq[_n-1]
replace ghq_l = . if ghq_l <0

label variable ghq "sum of 12 ghq, 0-36, the higher the worse. == scghq1_dv"
label variable sp_ghq "spouse's sum of 12 ghq, 0-36, the higher the worse. ==scghq1_dv"
label variable ghq_l "ghq at t-1"
 

***individual characteristic

*whether have children
gen d_children = 0
replace d_children = 1 if lnprnt >0 | lnadopt >0
label variable d_children "=1, if have children"

*age
cap ren age_dv dvage
drop if dvage <0 
gen age2 = dvage^2
*age over 55
gen senior=0
replace senior=1 if (dvage>=45 & dvage<.)
label variable senior "=1, if age>=45"
*age under 25
gen young=0
replace young=1 if (dvage<=25 & dvage<.)
label variable young "=1, if age<=25"

*sex: male = 1
gen male  = 0
replace male = 1 if sex == 1
label variable male "=1, if is male"


*construct hourly wage
gen h = .
replace h = jbhrs if jbhrs > 0
replace h = jshrs if jshrs > 0
replace h = 40 if h ==. & pjbptft == 2
replace h = 20 if h ==. & pjbptft == 1

replace h = h * (52/12)
label variable h "working hours per week"
gen w = fimnlabgrs_dv / h

bys pidp(idate):gen w_diff = w[_n+1] - w
label variable w_diff  "w in next year - w in this year"

gen lnw_diff = ln(w_diff)
label variable lnw_diff  "ln(w in next year - w in this year)"



//real wage
merge n:n year using cpi 
///base year is 1991
drop if _merge!=3
replace w=(w/(cpi2010100))*100
drop _merge cpi2010100
gen lnw = ln(w)
label variable w "hourly wage, deflated, base year 1991"
label variable lnw "log( hourly wage), deflated, base year 1991"


*education
label list l_qfhigh_dv
// 1 Higher degree, 2 1st degree or equivalent,3 Diploma in he,4 Teaching qual not pgce,5 Nursing/other med qual,6 Other higher degree,7 A level,8 Welsh baccalaureate,9 I'nationl baccalaureate,10 AS level,11 Highers (scot),12 Cert 6th year studies,13 GCSE/O level,14 CSE,15 Standard/o/lower,16 Other school cert,96 None of the above

//similar to BHPS, I group them as: 1(1), 2(2,3), 3(4,5,6), 4(7,8,9,10,11),5(12,13,14,15), 6(16,96)
gen edu=.
replace edu=. if qfhigh_dv<0
replace edu=1 if qfhigh_dv ==1
replace edu=2 if qfhigh_dv ==2 |qfhigh_dv ==3
replace edu=3 if qfhigh_dv ==4 |qfhigh_dv ==5| qfhigh_dv ==6
replace edu=4 if qfhigh_dv ==7 |qfhigh_dv ==8 |qfhigh_dv ==9 |qfhigh_dv ==10 |qfhigh_dv ==11
replace edu=5 if qfhigh_dv ==12 |qfhigh_dv ==13 |qfhigh_dv ==14 |qfhigh_dv ==15
replace edu=6 if qfhigh_dv ==16 |qfhigh_dv ==96
tab edu [aweight=weightscaled]
label variable edu "education level, 1-6, high to low"

gen edu_g1 = 1 if inrange(edu,1,3)
gen edu_g2 = 1 if inrange(edu,4,5)
gen edu_g3 = 1 if edu==6
label variable edu_g1 "education group, high level"
label variable edu_g2 "education group, middle level"
label variable edu_g3 "education group, low level"


*household characteristic
merge m:1 wave hidp using hh_pidp, keep(master match) nogen

merge n:n year using cpi 
///base year is 1991
drop if _merge!=3
gen hhincome=(fihhmnlabgrs_dv/(cpi2010100))*100
drop _merge cpi2010100
gen lnhhincome = ln(hhincome)
label variable hhincome "total gross household labour income, month before interview, deflated, base year 1991"
label variable lnhhincome "log(total gross household labour income), deflated, base year 1991"

gen wage_share = fimnlabgrs_dv / hhincome  

*job start date(ddmmyyy)
gen jyear=jbbgy 
replace jyear=. if jyear <0  //457,165 missing out of 505,457
label variable jyear "current job start year"

bys pidp(idate): replace jyear = jyear[_n-1] if (samejob ==1 & jyear ==. & jyear[_n-1] <.)   //64,942 changes
bys pidp(idate): replace jyear = jyear[_n-1] if (nunmpsp_dv ==0 & jyear ==. & jyear[_n-1] <.)  //69,499 changes
tab jyear,missing  //322,724 missing out of 505,457

gen jmonth=int(jbbgm)
replace jmonth=1 if jmonth<0 & jyear !=.  //4105 changes
label variable jmonth "current job start month"
gen jday=int(jbbgd)
replace jday=1 if jday<0 & jyear !=. //9513 changes
label variable jday "current job start day"
gen jdate=mdy(jmonth,jday,jyear) 
label variable jdate "current job start date"
format jdate %td 


*fill in the missing jdate
sort pidp wave
tab jdate if (lfs==1|lfs==2),missing  //143,509 missing out of 334,603 obs
//jdate question only ask respondent who has a job and the date start current job doesn't know
by pidp(wave): replace jdate = jdate[_n-1] if jdate==. & jdate[_n-1] !=. & (lfs==1|lfs==2) 
by pidp(wave): replace jdate  = jdate[_n-1] if jdate==. & jdate[_n-1] !=. & jbsoc00chk == 1  
by pidp(wave): replace jdate = jdate[_n-2] if jdate==. &jdate[_n-1] ==. & jdate[_n-2] !=. & (lfs==1|lfs==2)
by pidp(wave): replace jdate = jdate[_n-3] if jdate==. &jdate[_n-1] ==. &jdate[_n-2] ==. & jdate[_n-3] !=. & (lfs==1|lfs==2)
by pidp(wave): replace jdate = jdate[_n-4] if jdate==. &jdate[_n-1] ==. &jdate[_n-2] ==. &jdate[_n-3] ==. & jdate[_n-4] !=. & (lfs==1|lfs==2) 
by pidp(wave): replace jdate = jdate[_n-5] if jdate==. &jdate[_n-1] ==. &jdate[_n-2] ==. &jdate[_n-3] ==. &jdate[_n-4] ==. & jdate[_n-5] !=. & (lfs==1|lfs==2) 
by pidp(wave): replace jdate = jdate[_n-6] if jdate==. &jdate[_n-1] ==. &jdate[_n-2] ==. &jdate[_n-3] ==. &jdate[_n-4] ==. &jdate[_n-5] ==. & jdate[_n-6] !=. & (lfs==1|lfs==2) 
by pidp(wave): replace jdate = jdate[_n-7] if jdate==. &jdate[_n-1] ==. &jdate[_n-2] ==. &jdate[_n-3] ==. &jdate[_n-4] ==. &jdate[_n-5] ==. &jdate[_n-6] ==. & jdate[_n-7] !=. & (lfs==1|lfs==2) 
by pidp(wave): replace jdate = jdate[_n-8] if jdate==. &jdate[_n-1] ==. &jdate[_n-2] ==. &jdate[_n-3] ==. &jdate[_n-4] ==. &jdate[_n-5] ==. &jdate[_n-6] ==. &jdate[_n-7] ==. & jdate[_n-8] !=. & (lfs==1|lfs==2) 
by pidp(wave): replace jdate = jdate[_n-9] if jdate==. &jdate[_n-1] ==. &jdate[_n-2] ==. &jdate[_n-3] ==. &jdate[_n-4] ==. &jdate[_n-5] ==. &jdate[_n-6] ==. &jdate[_n-7] ==. &jdate[_n-8] ==. & jdate[_n-9] !=. & (lfs==1|lfs==2) 
by pidp(wave): replace jdate = jdate[_n-10] if jdate==. &jdate[_n-1] ==. &jdate[_n-2] ==. &jdate[_n-3] ==. &jdate[_n-4] ==. &jdate[_n-5] ==. &jdate[_n-6] ==. &jdate[_n-7] ==. &jdate[_n-8] ==. &jdate[_n-9] ==. & jdate[_n-10] !=. & (lfs==1|lfs==2) 
by pidp(wave): replace jdate = jdate[_n-11] if jdate==. &jdate[_n-1] ==. &jdate[_n-2] ==. &jdate[_n-3] ==. &jdate[_n-4] ==. &jdate[_n-5] ==. &jdate[_n-6] ==. &jdate[_n-7] ==. &jdate[_n-8] ==. &jdate[_n-9] ==. &jdate[_n-10] ==. & jdate[_n-11] !=. & (lfs==1|lfs==2) 

tab jdate if (lfs==1|lfs==2),missing  //116,542 missing out of 334,603 employed/self-employed


*labour force status change
xtset pidp idate

gen empl = (lfs==1 | lfs ==2) if idate !=.  
label variable empl "employed/self-emplied, and idate is not missing"
bys pidp(idate):  gen contempl = empl==1 & empl[_n-1]==1 
label variable contempl "continuously employed/self-emplied in last wave and this wave"

//Generate indicators for unemployment-work
bys pidp(idate): gen u_in=empl[_n-1]==0 & empl==1 & enter != 1
label variable u_in "unemployed at t-1, work at t"
//Generate indicators for work-unemployment
bys pidp(idate): gen out_u=empl[_n+1]==0 & empl==1 & quit != 1
label variable out_u "work at t, unemployed at t+1"


*job transitions, code as comparison of time t with t-1
//Generate indicators for new job
bys pidp(idate): gen newjob= jdate>=idate[_n+1] if (jdate<.) & (idate[_n-1] <.) & contempl==1 & enter != 1 

label variable newjob "job a at time t, move to a new job b at time t+1 (might have unemployment spell in between)"

label variable jbsoc00chk "whether the previous description of occupation still apply to the current job"

bys pidp(idate):replace newjob = 0 if jbsoc00chk[_n+1] == 1 & enter[_n+1] != 1  

bys pidp(idate):replace newjob = 1 if jbsoc00chk[_n+1] == 2 & contempl[_n+1]==1 & enter[_n+1] != 1  

replace newjob=0 if newjob[_n+1]==. & contempl[_n+1] ==1  //if the respondent is continuously working in two waves and didn't report the job start date, then assume she is still working in the same job otherwise she would remember the new job start date. 
tab newjob, missing  

bys pidp: gen obs_count = _n
bys pidp(idate): replace newjob = 1 if (jbendy4[_n+1] >0 & jbendy4[_n+1] <.) & enter[_n+1]!=1  
bys pidp(idate): replace newjob = 0 if (jbendy4[_n+1] == -8 ) & (obs_count[_n+1] !=1 | ff_ivlolw[_n+1] !=1) & (nunmpsp_dv[_n+1]==0)  
bys pidp(idate): replace newjob = 1 if (jbsamr[_n+1] == 2 | samejob[_n+1] ==2) & enter[_n+1]!=1   

tab newjob if empl == 1,missing  //64,715 missing out of 334,603

***define occupations
gen soc00 = jbsoc00_cc 
gen soc10 = jbsoc10_cc 
rename jbisco88_cc isoc88

replace soc00 = . if soc00 < 0
replace soc10 = . if soc10 < 0
replace isoc88 = . if isoc88 < 0

//fill in missing soc00
tab soc00 if (lfs==1), missing  

//assume same job means same occupation
bysort pidp(idate): replace soc00=soc00[_n-1] if (jbsoc00chk==1 | (jbsamr==1 & samejob==1)) & soc00[_n-1] !=. //21,528 changes
tab soc00 if (lfs==1), missing   //11,122 missing out of 314,915 employment --> 9,562 missing, 3.5%

//occupations for last period
bys pidp(idate):gen lsoc00=soc00[_n-1] 
replace lsoc00=soc00 if (jbsoc00chk==1 | samejob==1) & soc00<. 
label variable lsoc00 "occupation in time t-1"

//occupations for next period
bys pidp(idate):gen fsoc00=soc00[_n+1] 
replace fsoc00=soc00 if (jbsoc00chk[_n+1]==1 | samejob[_n+1]==1) & soc00<. 
label variable fsoc00 "occupation in time t+1"




bysort pidp(idate): replace soc10=soc10[_n-1] if ((soc10 <0 | missing(soc10)) & soc10[_n-1] <.)
bysort pidp(idate): replace soc10=soc10[_n-1] if (jbsoc00chk==1 | (jbsamr==1 & samejob==1)) & soc10[_n-1]<. 
bysort pidp(idate): replace soc10=soc10[_n-1] if soc00==soc00[_n-1] & soc10[_n-1]<. 
tab soc10, missing  


*Generate indicators for new occ
bys pidp(idate): gen newocc = soc00 != soc00[_n+1]  if (soc00 < . & soc00[_n+1]< .)  & contempl[_n+1]==1 & enter[_n+1] != 1  //860,529 missing (soc00 already ajust according to same job check and missing means same with last wave if employed/self-emplied)

replace newocc=0 if newjob==0  // if no job change, then consider as no occ change

replace newjob=1 if newocc==1  //0 changes,if occ change, then consider there is job change

label variable newocc "occ a at time t, move to a new occ b at time t+1 (might have unemployment spell in between)"

tab newjob if empl == 1,missing
tab newocc if empl == 1,missing
*check total job/occ transition rate
// preserve
// keep if lfs ==1 | lfs ==2
// keep if inrange(dvage,16,65)
// collapse (mean) newocc newjob, by (wave)
// twoway (line newocc wave) (line newjob wave) 
// restore

*spouse's soc00
preserve
keep wave pidp newjob newocc soc00
rename pidp sppid 
rename soc00 sp_soc00 
rename newocc sp_newocc
rename newjob sp_newjob
sort wave sppid
tempfile spouse_newjob
save `spouse_newjob'
restore
merge m:1 wave sppid using `spouse_newjob', keep(master match) nogen



*lag spouse GHQ
xtset pidp wave
generate sp_ghq_lag = L.sp_ghq

*aidhrs aidhua* aideft aidhh lkmove xpmove family
unab vars : aidhrs aidhua* aideft aidhh lkmove xpmove family nkids_dv marstat_dv

sort pidp wave

foreach v of local vars {
    by pidp (wave): gen `v'_f = `v'[_n+1] if _n < _N
}


gen nkids_change = nkids_dv_f - nkids_dv

replace marstat_dv = 6 if dvage <18  //94 individuals aged over 16 but recorded as 0 "under 16 years"
replace marstat_dv = -9 if dvage >=18 & marstat_dv==0 //2 individuals aged 19, 33 but recorded as 0 "under 16 years", change them to -9 missing 

gen rls_change = (marstat_dv != marstat_dv_f) if lstinterview != 1 & marstat_dv != . &marstat_dv_f != .


*sample selection
*working age
keep if inrange(dvage, 16,65)


save ind_ghq_lfs,replace


* life event coding 
use ind_ghq_lfs, clear
xtset pidp wave


order pidp wave interview impevent* event* 
keep if wave == 1 |wave == 2 |wave == 5
//only 3 waves record event variable 


*** gen event answer variables
/********************************************************************
0) Initialise all dummies to 0
   (so values are well-defined for all waves)
********************************************************************/
foreach v in proxy refusal dontknow inapplicable ///
    ill hospitalisation accident tests mobilityloss recovery healthnec ///
    caring babysit ///
    schoolstart schoolleave furtherstart furtherleave quals studytravel educnec ///
    jobchange jobplan jobget worktrain redundant retire worktravel workprob jobsnec ///
    vacation leisure drive political worldevent ///
    friendbeg friendend friends neighbour nonfamrel pregnancy cohabit engage divorce leavehome death ///
    anniversary birthday godparent relatives familyday familyprob domestic pets ///
    familyoth moneyprob forcedmove finimprove receivemoney finoth vehicle housebuy repairs prize present purchases ///
    moved moveintend reshome movein ///
    crime troublewithpolice religionchg religionoth ///
    plannot court otherlow nothing {
    capture confirm variable `v'
    if _rc {
        gen byte `v' = 0
    }
    else {
        replace `v' = 0
    }
}

*********************************************************************
* 1) Define a local macro that points to the correct event vars by wave
*    wave==1 uses impevent1-4
*    wave==2 or 5 uses event1-4
*********************************************************************

/********************************************************************
Non-response / admin codes
********************************************************************/
replace proxy = (impevent1==-7 | impevent2==-7 | impevent3==-7 | impevent4==-7) if wave==1
replace proxy = (event1==-7    | event2==-7    | event3==-7    | event4==-7)    if inlist(wave,2,5)
label variable proxy "proxy"

replace refusal = (impevent1==-2 | impevent2==-2 | impevent3==-2 | impevent4==-2) if wave==1
replace refusal = (event1==-2    | event2==-2    | event3==-2    | event4==-2)    if inlist(wave,2,5)
label variable refusal "refusal"

replace dontknow = (impevent1==-1 | impevent2==-1 | impevent3==-1 | impevent4==-1) if wave==1
replace dontknow = (event1==-1    | event2==-1    | event3==-1    | event4==-1)    if inlist(wave,2,5)
label variable dontknow "don't know"

replace inapplicable = (impevent1==-8 | impevent2==-8 | impevent3==-8 | impevent4==-8) if wave==1
label variable inapplicable "inapplicable"


/********************************************************************
Health
********************************************************************/
replace ill = (impevent1==1 | impevent2==1 | impevent3==1 | impevent4==1) if wave==1
replace ill = (event1==1    | event2==1    | event3==1    | event4==1)    if inlist(wave,2,5)
label variable ill "ill health/concern about health"

replace hospitalisation = (impevent1==2 | impevent2==2 | impevent3==2 | impevent4==2) if wave==1
replace hospitalisation = (event1==2    | event2==2    | event3==2    | event4==2)    if inlist(wave,2,5)
label variable hospitalisation "hospitalisation/operation"

replace accident = (impevent1==3 | impevent2==3 | impevent3==3 | impevent4==3) if wave==1
replace accident = (event1==3    | event2==3    | event3==3    | event4==3)    if inlist(wave,2,5)
label variable accident "involving injury"

replace tests = (impevent1==4 | impevent2==4 | impevent3==4 | impevent4==4) if wave==1
replace tests = (event1==4    | event2==4    | event3==4    | event4==4)    if inlist(wave,2,5)
label variable tests "health tests (positive & negative)"

replace mobilityloss = (impevent1==5 | impevent2==5 | impevent3==5 | impevent4==5) if wave==1
replace mobilityloss = (event1==5    | event2==5    | event3==5    | event4==5)    if inlist(wave,2,5)
label variable mobilityloss "loss of mobility/house-bound"

replace recovery = (impevent1==6 | impevent2==6 | impevent3==6 | impevent4==6) if wave==1
replace recovery = (event1==6    | event2==6    | event3==6    | event4==6)    if inlist(wave,2,5)
label variable recovery "recovery/continuing good health"

replace healthnec = (impevent1==9 | impevent2==9 | impevent3==9 | impevent4==9) if wave==1
replace healthnec = (event1==9    | event2==9    | event3==9    | event4==9)    if inlist(wave,2,5)
label variable healthnec "health (not elsewhere classified)"


/********************************************************************
Caring / family responsibilities
********************************************************************/
replace caring = (impevent1==10 | impevent2==10 | impevent3==10 | impevent4==10) if wave==1
replace caring = (event1==10    | event2==10    | event3==10    | event4==10)    if inlist(wave,2,5)
label variable caring "caring responsibilities - not childcare (i.e. who is cared for?)"

replace babysit = (impevent1==11 | impevent2==11 | impevent3==11 | impevent4==11) if wave==1
replace babysit = (event1==11    | event2==11    | event3==11    | event4==11)    if inlist(wave,2,5)
label variable babysit "babysitting (ie who is the sitter?)"


/********************************************************************
Education
********************************************************************/
replace schoolstart = (impevent1==12 | impevent2==12 | impevent3==12 | impevent4==12) if wave==1
replace schoolstart = (event1==12    | event2==12    | event3==12    | event4==12)    if inlist(wave,2,5)
label variable schoolstart "starting/in school"

replace schoolleave = (impevent1==13 | impevent2==13 | impevent3==13 | impevent4==13) if wave==1
replace schoolleave = (event1==13    | event2==13    | event3==13    | event4==13)    if inlist(wave,2,5)
label variable schoolleave "leaving school"

replace furtherstart = (impevent1==14 | impevent2==14 | impevent3==14 | impevent4==14) if wave==1
replace furtherstart = (event1==14    | event2==14    | event3==14    | event4==14)    if inlist(wave,2,5)
label variable furtherstart "starting/in further education (incl. sixth form)"

replace furtherleave = (impevent1==15 | impevent2==15 | impevent3==15 | impevent4==15) if wave==1
replace furtherleave = (event1==15    | event2==15    | event3==15    | event4==15)    if inlist(wave,2,5)
label variable furtherleave "leaving further education"

replace quals = (impevent1==16 | impevent2==16 | impevent3==16 | impevent4==16) if wave==1
replace quals = (event1==16    | event2==16    | event3==16    | event4==16)    if inlist(wave,2,5)
label variable quals "studying for/passing educational/vocational qualifications/acquiring skills training (not elsewhere classified)"

replace studytravel = (impevent1==17 | impevent2==17 | impevent3==17 | impevent4==17) if wave==1
replace studytravel = (event1==17    | event2==17    | event3==17    | event4==17)    if inlist(wave,2,5)
label variable studytravel "travel related to study"

replace educnec = (impevent1==19 | impevent2==19 | impevent3==19 | impevent4==19) if wave==1
replace educnec = (event1==19    | event2==19    | event3==19    | event4==19)    if inlist(wave,2,5)
label variable educnec "education (not elsewhere classified)"


/********************************************************************
Work / jobs
********************************************************************/
replace jobchange = (impevent1==20 | impevent2==20 | impevent3==20 | impevent4==20) if wave==1
replace jobchange = (event1==20    | event2==20    | event3==20    | event4==20)    if inlist(wave,2,5)
label variable jobchange "change of job (incl. hours, status)/starting own business"

replace jobplan = (impevent1==21 | impevent2==21 | impevent3==21 | impevent4==21) if wave==1
replace jobplan = (event1==21    | event2==21    | event3==21    | event4==21)    if inlist(wave,2,5)
label variable jobplan "planned/possible change of job"

replace jobget = (impevent1==22 | impevent2==22 | impevent3==22 | impevent4==22) if wave==1
replace jobget = (event1==22    | event2==22    | event3==22    | event4==22)    if inlist(wave,2,5)
label variable jobget "getting job (following economic inactivity)"

replace worktrain = (impevent1==23 | impevent2==23 | impevent3==23 | impevent4==23) if wave==1
replace worktrain = (event1==23    | event2==23    | event3==23    | event4==23)    if inlist(wave,2,5)
label variable worktrain "work-related training (incl. apprenticeship/hgv licence/work experience)"

replace redundant = (impevent1==24 | impevent2==24 | impevent3==24 | impevent4==24) if wave==1
replace redundant = (event1==24    | event2==24    | event3==24    | event4==24)    if inlist(wave,2,5)
label variable redundant "redundancy/unemployment (threat of or actual)"

replace retire = (impevent1==25 | impevent2==25 | impevent3==25 | impevent4==25) if wave==1
replace retire = (event1==25    | event2==25    | event3==25    | event4==25)    if inlist(wave,2,5)
label variable retire "retirement"

replace worktravel = (impevent1==26 | impevent2==26 | impevent3==26 | impevent4==26) if wave==1
replace worktravel = (event1==26    | event2==26    | event3==26    | event4==26)    if inlist(wave,2,5)
label variable worktravel "travel related to work (who travels?)"

replace workprob = (impevent1==27 | impevent2==27 | impevent3==27 | impevent4==27) if wave==1
replace workprob = (event1==27    | event2==27    | event3==27    | event4==27)    if inlist(wave,2,5)
label variable workprob "work-related problems (recession and/or personal - whose job?)"

replace jobsnec = (impevent1==29 | impevent2==29 | impevent3==29 | impevent4==29) if wave==1
replace jobsnec = (event1==29    | event2==29    | event3==29    | event4==29)    if inlist(wave,2,5)
label variable jobsnec "jobs/careers (not elsewhere classified)"


/********************************************************************
Travel / leisure / driving / civic
********************************************************************/
replace vacation = (impevent1==30 | impevent2==30 | impevent3==30 | impevent4==30) if wave==1
replace vacation = (event1==30    | event2==30    | event3==30    | event4==30)    if inlist(wave,2,5)
label variable vacation "vacation/travel (not elsewhere classified)"

replace leisure = (impevent1==31 | impevent2==31 | impevent3==31 | impevent4==31) if wave==1
replace leisure = (event1==31    | event2==31    | event3==31    | event4==31)    if inlist(wave,2,5)
label variable leisure "leisure activities"

replace drive = (impevent1==32 | impevent2==32 | impevent3==32 | impevent4==32) if wave==1
replace drive = (event1==32    | event2==32    | event3==32    | event4==32)    if inlist(wave,2,5)
label variable drive "learning to drive/passing test (not hgv)"

replace political = (impevent1==33 | impevent2==33 | impevent3==33 | impevent4==33) if wave==1
replace political = (event1==33    | event2==33    | event3==33    | event4==33)    if inlist(wave,2,5)
label variable political "political participation/voluntary work (inc committee work)"

replace worldevent = (impevent1==34 | impevent2==34 | impevent3==34 | impevent4==34) if wave==1
replace worldevent = (event1==34    | event2==34    | event3==34    | event4==34)    if inlist(wave,2,5)
label variable worldevent "reference to national/world events (who is concerned by event?)"


/********************************************************************
Friends / relationships
********************************************************************/
replace friendbeg = (impevent1==35 | impevent2==35 | impevent3==35 | impevent4==35) if wave==1
replace friendbeg = (event1==35    | event2==35    | event3==35    | event4==35)    if inlist(wave,2,5)
label variable friendbeg "began friendship (incl. girl/boy friend)"

replace friendend = (impevent1==36 | impevent2==36 | impevent3==36 | impevent4==36) if wave==1
replace friendend = (event1==36    | event2==36    | event3==36    | event4==36)    if inlist(wave,2,5)
label variable friendend "end friendship (incl. girl/boy friend)"

replace friends = (impevent1==37 | impevent2==37 | impevent3==37 | impevent4==37) if wave==1
replace friends = (event1==37    | event2==37    | event3==37    | event4==37)    if inlist(wave,2,5)
label variable friends "spending time with/visiting friends (coded as holiday as appropriate)"

replace neighbour = (impevent1==38 | impevent2==38 | impevent3==38 | impevent4==38) if wave==1
replace neighbour = (event1==38    | event2==38    | event3==38    | event4==38)    if inlist(wave,2,5)
label variable neighbour "problems with neighbours (who has the problem?)"

replace nonfamrel = (impevent1==39 | impevent2==39 | impevent3==39 | impevent4==39) if wave==1
replace nonfamrel = (event1==39    | event2==39    | event3==39    | event4==39)    if inlist(wave,2,5)
label variable nonfamrel "non-family relationship (not elsewhere classified)"

replace pregnancy = (impevent1==40 | impevent2==40 | impevent3==40 | impevent4==40) if wave==1
replace pregnancy = (event1==40    | event2==40    | event3==40    | event4==40)    if inlist(wave,2,5)
label variable pregnancy "pregnancy/birth (identity of parent?)"

replace cohabit = (impevent1==41 | impevent2==41 | impevent3==41 | impevent4==41) if wave==1
replace cohabit = (event1==41    | event2==41    | event3==41    | event4==41)    if inlist(wave,2,5)
label variable cohabit "cohabitation"

replace engage = (impevent1==42 | impevent2==42 | impevent3==42 | impevent4==42) if wave==1
replace engage = (event1==42    | event2==42    | event3==42    | event4==42)    if inlist(wave,2,5)
label variable engage "engagements/weddings"

replace divorce = (impevent1==43 | impevent2==43 | impevent3==43 | impevent4==43) if wave==1
replace divorce = (event1==43    | event2==43    | event3==43    | event4==43)    if inlist(wave,2,5)
label variable divorce "separation/divorce/end of cohabitation"

replace leavehome = (impevent1==44 | impevent2==44 | impevent3==44 | impevent4==44) if wave==1
replace leavehome = (event1==44    | event2==44    | event3==44    | event4==44)    if inlist(wave,2,5)
label variable leavehome "leaving parental home"

replace death = (impevent1==45 | impevent2==45 | impevent3==45 | impevent4==45) if wave==1
replace death = (event1==45    | event2==45    | event3==45    | event4==45)    if inlist(wave,2,5)
label variable death "death (who died?)"

replace anniversary = (impevent1==46 | impevent2==46 | impevent3==46 | impevent4==46) if wave==1
replace anniversary = (event1==46    | event2==46    | event3==46    | event4==46)    if inlist(wave,2,5)
label variable anniversary "wedding anniversaries"

replace birthday = (impevent1==47 | impevent2==47 | impevent3==47 | impevent4==47) if wave==1
replace birthday = (event1==47    | event2==47    | event3==47    | event4==47)    if inlist(wave,2,5)
label variable birthday "birthday celebrations"

replace godparent = (impevent1==48 | impevent2==48 | impevent3==48 | impevent4==48) if wave==1
replace godparent = (event1==48    | event2==48    | event3==48    | event4==48)    if inlist(wave,2,5)
label variable godparent "becoming godparent"

replace relatives = (impevent1==50 | impevent2==50 | impevent3==50 | impevent4==50) if wave==1
replace relatives = (event1==50    | event2==50    | event3==50    | event4==50)    if inlist(wave,2,5)
label variable relatives "spending time/visits with relatives (not within household)"

replace familyday = (impevent1==51 | impevent2==51 | impevent3==51 | impevent4==51) if wave==1
replace familyday = (event1==51    | event2==51    | event3==51    | event4==51)    if inlist(wave,2,5)
label variable familyday "day-to-day family life"

replace familyprob = (impevent1==52 | impevent2==52 | impevent3==52 | impevent4==52) if wave==1
replace familyprob = (event1==52    | event2==52    | event3==52    | event4==52)    if inlist(wave,2,5)
label variable familyprob "family problems (person causing problems?)"

replace domestic = (impevent1==53 | impevent2==53 | impevent3==53 | impevent4==53) if wave==1
replace domestic = (event1==53    | event2==53    | event3==53    | event4==53)    if inlist(wave,2,5)
label variable domestic "domestic incident (eg fire/burst pipes, etc)"

replace pets = (impevent1==54 | impevent2==54 | impevent3==54 | impevent4==54) if wave==1
replace pets = (event1==54    | event2==54    | event3==54    | event4==54)    if inlist(wave,2,5)
label variable pets "pets/animals (pet coded)"


/********************************************************************
Finance / housing / possessions
********************************************************************/
replace familyoth = (impevent1==59 | impevent2==59 | impevent3==59 | impevent4==59) if wave==1
replace familyoth = (event1==59    | event2==59    | event3==59    | event4==59)    if inlist(wave,2,5)
label variable familyoth "family event/family reference (not elsewhere classified)"

replace moneyprob = (impevent1==60 | impevent2==60 | impevent3==60 | impevent4==60) if wave==1
replace moneyprob = (event1==60    | event2==60    | event3==60    | event4==60)    if inlist(wave,2,5)
label variable moneyprob "money problems/drop in income/debt"

replace forcedmove = (impevent1==61 | impevent2==61 | impevent3==61 | impevent4==61) if wave==1
replace forcedmove = (event1==61    | event2==61    | event3==61    | event4==61)    if inlist(wave,2,5)
label variable forcedmove "forced move (repossession/eviction (residential move not included))"

replace finimprove = (impevent1==62 | impevent2==62 | impevent3==62 | impevent4==62) if wave==1
replace finimprove = (event1==62    | event2==62    | event3==62    | event4==62)    if inlist(wave,2,5)
label variable finimprove "improved financial situation"

replace receivemoney = (impevent1==63 | impevent2==63 | impevent3==63 | impevent4==63) if wave==1
replace receivemoney = (event1==63    | event2==63    | event3==63    | event4==63)    if inlist(wave,2,5)
label variable receivemoney "received money (inheritance/compensation/pools)"

replace finoth = (impevent1==69 | impevent2==69 | impevent3==69 | impevent4==69) if wave==1
replace finoth = (event1==69    | event2==69    | event3==69    | event4==69)    if inlist(wave,2,5)
label variable finoth "financial other (not elsewhere classified)"

replace vehicle = (impevent1==70 | impevent2==70 | impevent3==70 | impevent4==70) if wave==1
replace vehicle = (event1==70    | event2==70    | event3==70    | event4==70)    if inlist(wave,2,5)
label variable vehicle "bought/buying vehicle (car, caravan, etc)"

replace housebuy = (impevent1==71 | impevent2==71 | impevent3==71 | impevent4==71) if wave==1
replace housebuy = (event1==71    | event2==71    | event3==71    | event4==71)    if inlist(wave,2,5)
label variable housebuy "bought/buying / building house"

replace repairs = (impevent1==72 | impevent2==72 | impevent3==72 | impevent4==72) if wave==1
replace repairs = (event1==72    | event2==72    | event3==72    | event4==72)    if inlist(wave,2,5)
label variable repairs "household repairs/improvements/appliances"

replace prize = (impevent1==73 | impevent2==73 | impevent3==73 | impevent4==73) if wave==1
replace prize = (event1==73    | event2==73    | event3==73    | event4==73)    if inlist(wave,2,5)
label variable prize "won prize (not cash)/award"

replace present = (impevent1==74 | impevent2==74 | impevent3==74 | impevent4==74) if wave==1
replace present = (event1==74    | event2==74    | event3==74    | event4==74)    if inlist(wave,2,5)
label variable present "received present (from whom ?)"

replace purchases = (impevent1==79 | impevent2==79 | impevent3==79 | impevent4==79) if wave==1
replace purchases = (event1==79    | event2==79    | event3==79    | event4==79)    if inlist(wave,2,5)
label variable purchases "other purchases (not elsewhere classified)"

replace moved = (impevent1==80 | impevent2==80 | impevent3==80 | impevent4==80) if wave==1
replace moved = (event1==80    | event2==80    | event3==80    | event4==80)    if inlist(wave,2,5)
label variable moved "moved in past year"

replace moveintend = (impevent1==81 | impevent2==81 | impevent3==81 | impevent4==81) if wave==1
replace moveintend = (event1==81    | event2==81    | event3==81    | event4==81)    if inlist(wave,2,5)
label variable moveintend "future intention to move"

replace reshome = (impevent1==82 | impevent2==82 | impevent3==82 | impevent4==82) if wave==1
replace reshome = (event1==82    | event2==82    | event3==82    | event4==82)    if inlist(wave,2,5)
label variable reshome "move into residential home (nursing/retirement, etc)"

replace movein = (impevent1==83 | impevent2==83 | impevent3==83 | impevent4==83) if wave==1
replace movein = (event1==83    | event2==83    | event3==83    | event4==83)    if inlist(wave,2,5)
label variable movein "move into respondent's household (who is moving in?)"


/********************************************************************
Crime
********************************************************************/
replace crime = (impevent1==90 | impevent2==90 | impevent3==90 | impevent4==90) if wave==1
replace crime = (event1==90    | event2==90    | event3==90    | event4==90)    if inlist(wave,2,5)
label variable crime "victim of crime (burglary ,etc)"

replace troublewithpolice = (impevent1==91 | impevent2==91 | impevent3==91 | impevent4==91) if wave==1
replace troublewithpolice = (event1==91    | event2==91    | event3==91    | event4==91)    if inlist(wave,2,5)
label variable troublewithpolice "troublewithpolice"

/********************************************************************
Religion
********************************************************************/
replace religionchg = (impevent1==92 | impevent2==92 | impevent3==92 | impevent4==92) if wave==1
replace religionchg = (event1==92    | event2==92    | event3==92    | event4==92)    if inlist(wave,2,5)
label variable religionchg "joined/changed religion"

replace religionoth = (impevent1==93 | impevent2==93 | impevent3==93 | impevent4==93) if wave==1
replace religionoth = (event1==93    | event2==93    | event3==93    | event4==93)    if inlist(wave,2,5)
label variable religionoth "other religious reference (not confirmation/baptism of children)"


/********************************************************************
Other / none
********************************************************************/
replace plannot = (impevent1==94 | impevent2==94 | impevent3==94 | impevent4==94) if wave==1
replace plannot = (event1==94    | event2==94    | event3==94    | event4==94)    if inlist(wave,2,5)
label variable plannot "plan not fulfilled/something that didn't happen (eg didn't have a holiday)"

replace court = (impevent1==95 | impevent2==95 | impevent3==95 | impevent4==95) if wave==1
replace court = (event1==95    | event2==95    | event3==95    | event4==95)    if inlist(wave,2,5)
label variable court "civil court action/battles with bureaucracy"

replace otherlow = (impevent1==96 | impevent2==96 | impevent3==96 | impevent4==96) if wave==1
replace otherlow = (event1==96    | event2==96    | event3==96    | event4==96)    if inlist(wave,2,5)
label variable otherlow "other occurrence (not elsewhere classified) given low priority"

replace nothing = (impevent1==97 | impevent2==97 | impevent3==97 | impevent4==97) if wave==1
replace nothing = (event1==97    | event2==97    | event3==97    | event4==97)    if inlist(wave,2,5)
label variable nothing "nothing happened"


*non-partner non-child death 
gen deathfam = ((impevent1 == 45 & impevent1s != 3) | (impevent2 == 45 & impevent2s != 3) | (impevent3 == 45 & impevent3s != 3) | (impevent4 == 45 & impevent4s != 3) | (event1 == 45 & event1s != 3) | (event2 == 45 & event2s != 3) | (event3 == 45 & event3s != 3) | (event4 == 45 & event4s != 3))
//event == 45 means some family died, event*s == 3 means the subject is partner. 

*rule out child death 
replace deathfam = 0 if (event1 == 45 & inlist(event1s, 4, 5, 6)) | (event2 == 45 & inlist(event2s, 4, 5, 6)) | (event3 == 45 & inlist(event3s, 4, 5, 6)) |(event4 == 45 & inlist(event4s, 4, 5, 6)) |(impevent1 == 45 & inlist(impevent1s, 4, 5, 6)) |(impevent2 == 45 & inlist(impevent2s, 4, 5, 6)) |(impevent3 == 45 & inlist(impevent3s, 4, 5, 6)) |(impevent4 == 45 & inlist(impevent4s, 4, 5, 6)) 


generate deathfam_lag = L.deathfam

label variable deathfam "someone in family died, not partner, not child"



*** label positive event (single-event association with GHQ is negative)
local evlist ///
    vacation  jobchange leisure jobsnec worktrain anniversary pregnancy engage religionoth vehicle jobget finimprove housebuy repairs recovery quals otherlow schoolstart relatives political leavehome retire prize receivemoney birthday drive babysit furtherleave studytravel domestic friends cohabit friendbeg  schoolleave pets  
	
	
egen pstvevent = rowmax(`evlist')   // at least one positive thing happened 
label var pstvevent "any positive event happened (any of four answers)"


***label negative event (single-event association with GHQ is positive)
local evlist ///
    ill workprob moneyprob redundant divorce familyprob hospitalisation death tests accident friendend healthnec crime court plannot caring mobilityloss worldevent forcedmove neighbour finoth worktravel  present jobplan movein moveintend godparent purchases moved nonfamrel  religionchg reshome familyday furtherstart educnec familyoth 
	
egen ngtvevent = rowmax(`evlist')   // at least one negative thing happened 
label var ngtvevent "any negative event happened (any of four answers)"


	


*** label anyevent	
local evlist ///
    ill hospitalisation accident tests mobilityloss recovery healthnec ///
    caring babysit ///
    schoolstart schoolleave furtherstart furtherleave quals studytravel educnec ///
    jobchange jobplan jobget worktrain redundant retire worktravel workprob jobsnec ///
    vacation leisure drive political worldevent ///
    friendbeg friendend friends neighbour nonfamrel pregnancy cohabit engage divorce leavehome death anniversary birthday godparent ///
    relatives familyday familyprob domestic pets ///
    familyoth moneyprob forcedmove finimprove receivemoney finoth vehicle housebuy repairs prize present purchases ///
    moved moveintend reshome movein ///
    crime troublewithpolice religionchg religionoth plannot court otherlow

egen anyevent = rowmax(`evlist')   // at least one thing happened 
label var anyevent "any listed event happened (any of four answers)"




save ghqevent_nodrop, replace

* prepare a file with only event reported 
local evlist ///
    ill hospitalisation accident tests mobilityloss recovery healthnec ///
    caring babysit ///
    schoolstart schoolleave furtherstart furtherleave quals studytravel educnec ///
    jobchange jobplan jobget worktrain redundant retire worktravel workprob jobsnec ///
    vacation leisure drive political worldevent ///
    friendbeg friendend friends neighbour nonfamrel pregnancy cohabit engage divorce leavehome death anniversary birthday godparent ///
    relatives familyday familyprob domestic pets ///
    familyoth moneyprob forcedmove finimprove receivemoney finoth vehicle housebuy repairs prize present purchases ///
    moved moveintend reshome movein ///
    crime troublewithpolice religionchg religionoth plannot court otherlow

keep pidp wave pstvevent ngtvevent anyevent `evlist'
order pidp wave anyevent pstvevent ngtvevent  `evlist'
save ind_event, replace

exit


















******************
use ind_ghq_lfs, clear
xtset pidp idate

//20260204
// poisson ghq age2 dvage male deathfam
//
//
// replace event1 =0 if event1 <0
// reg ghq age2 dvage male i.event1 
//
// reg ghq age2 deathfam_lag dvage male deathfam

//////////////////////////////////
************ OLS 

*job transition

keep if wave == 1 |wave == 2 |wave == 5


reg newjob dvage male w ghq i.year 

reg newjob dvage male w ghq i.year, cluster(pidp)
reg newjob dvage male lnw ghq i.year, cluster(pidp)
//change in lnw
reg newjob dvage male lnw ghq deathfam i.year, cluster(pidp)





reg newjob dvage male hhincome ghq i.year, cluster(pidp)


//best
reg newjob dvage male wage_share ghq i.year, cluster(pidp)


xtreg newjob age2 w ghq i.year, fe robust
// best 
xtreg newjob age2 wage_share ghq i.year, fe robust


/* 估计随机效应模型
xtreg newjob dvage male hhincome w ghq i.year, re
estimates store re

* 估计固定效应模型（注意：male会被省略）
xtreg newjob dvage hhincome w ghq i.year, fe
estimates store fe

* 进行Hausman检验
hausman fe re
//p<0.05, so chose fe 
*/



*occ transition
reg newocc dvage male w ghq i.year 

reg newocc dvage male w ghq i.year, cluster(pidp)

reg newocc dvage male hhincome ghq i.year, cluster(pidp)


//best
reg newocc dvage male wage_share ghq i.year, cluster(pidp)



xtreg newocc age2 w ghq i.year, fe robust
// best 
xtreg newocc age2 wage_share ghq i.year, fe robust




**********life event
use ind_ghq_lfs, clear
xtset pidp idate


order pidp wave interview impevent* event* 


*job transition

keep if wave == 1 |wave == 2 |wave == 5
xtivreg newjob dvage age2  lnw ib2.sp_lfs i.year (ghq = deathfam), fe first


//20260204
xtivreg newjob dvage age2 lnw  i.year (ghq = deathfam), fe first
ivregress 2sls newjob dvage age2 lnw i.year (ghq = deathfam)


////////
*occ transition
xtivreg newocc dvage hhincome lnw ib2.sp_lfs i.year (ghq = deathfam), fe first

























