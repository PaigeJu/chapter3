clear all
set more off


use ghqevent,clear 
// scghqa scghqb scghqc scghqd scghqe scghqf scghqg scghqh scghqi scghqj scghqk scghql

reg newjob ghq lnw male dvage age2 i.year, vce(cluster pidp)

reg newjob scghqa scghqb scghqc scghqd scghqe scghqf scghqg scghqh scghqi scghqj scghqk scghql lnw male dvage age2 i.year, vce(cluster pidp)


*** ********IV 


* deathfam 
use ghqevent,clear 

tab deathfam  //6.5%

ivregress 2sls newjob lnw dvage age2 male i.year (ghq = deathfam), vce(cluster pidp)
estat firststage

outreg2 using "newjob_ghq.doc", replace ctitle("LPM: newjob on GHQ") dec(3)




* selected subset
use ghqevent,clear 

*
local negset deathfam  friendend familyprob
// local posset vacation leisure engage birthday anniversary godparent relatives friends

ivregress 2sls newjob lnw dvage age2 male (ghq = `negset' ), vce(cluster pidp)







//best 

local negset deathfam familyprob neighbour friendend
local posset vacation leisure engage birthday anniversary godparent relatives friends

ivregress 2sls newjob lnw dvage age2 male (ghq = `negset' `posset'), vce(cluster pidp) first
outreg2 using "newjob_ghq_setevent.doc", replace ctitle("LPM: newjob on GHQ") dec(3)
quietly summarize ghq if e(sample)
local sdghq = r(sd)
di "SD(GHQ) = " %9.4f `sdghq'




////0304
local negset deathfam   friendend
local posset vacation leisure   anniversary  relatives 

sum `negset' `posset'

ivregress 2sls newjob lnw dvage age2 male (ghq = `negset' `posset'), vce(cluster pidp) first
ivregress 2sls newjob lnw dvage age2 male (ghq = `posset'), vce(cluster pidp) first
ivregress 2sls newjob lnw dvage age2 male (ghq = `negset'), vce(cluster pidp) first




/////////////over id 
use ghqevent,clear 

*
local negset deathfam familyprob neighbour friendend
local posset vacation leisure engage birthday anniversary godparent relatives friends

ivregress 2sls newjob lnw dvage age2 male (ghq = `negset' `posset'), vce(cluster pidp) first
outreg2 using "newjob_ghq_setevent.doc", replace ctitle("LPM: newjob on GHQ") dec(3)

estat overid






//best 

local negset deathfam familyprob neighbour friendend
local posset vacation leisure engage birthday anniversary godparent relatives friends

ivregress 2sls newjob lnw dvage age2 male (ghq = `negset' `posset'), vce(cluster pidp) first
outreg2 using "newjob_ghq_setevent.doc", replace ctitle("LPM: newjob on GHQ") dec(3)








exit


egen z_neg = rowtotal(`negset')
egen z_pos = rowtotal(`posset')

* 2SLS
ivregress 2sls newjob lnw dvage age2 male (ghq = z_neg z_pos), vce(cluster pidp)
estat firststage
estat overid



* pca？
use ghqevent,clear 

local negset deathfam familyprob neighbour friendend
local posset vacation leisure engage birthday anniversary godparent relatives friends

* 
foreach v of local negset {
    egen z_`v' = std(`v')
}
foreach v of local posset {
    egen z_`v' = std(`v')
}

* group pca
pca z_deathfam z_familyprob z_neighbour z_friendend
predict pc_neg1, score

pca z_vacation z_leisure z_engage z_birthday z_anniversary z_godparent z_relatives z_friends
predict pc_pos1, score

* 2SLS
ivregress 2sls newjob lnw dvage age2 male  (ghq = pc_neg1 pc_pos1), vce(cluster pidp)

estat firststage

* reduced form
reg newjob pc_neg1 pc_pos1 lnw dvage age2 male, vce(cluster pidp)


* drop positive set
ivregress 2sls newjob lnw dvage age2 male (ghq = pc_neg1), vce(cluster pidp)
estat firststage
reg newjob pc_neg1 lnw dvage age2 male, vce(cluster pidp)
