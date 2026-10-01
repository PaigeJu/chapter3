clear all
set more off


use ghqevent,clear 

/*
*check for underidentification, weak iv, 12 iv are all valid?
log using "underid.log", replace

ivregress 2sls newjob lnw dvage age2 male ///
    (ghq = deathfam familyprob neighbour friendend ///
           vacation leisure engage birthday anniversary godparent relatives friends), ///
    vce(cluster pidp) first	
	
estat firststage



ivreg2 newjob lnw dvage age2 male ///
    (ghq = deathfam familyprob neighbour friendend ///
           vacation leisure engage birthday anniversary godparent relatives friends), ///
    cluster(pidp) first

//The candidate life-event instruments are not underidentified: the cluster-robust Kleibergen–Paap rk LM statistic strongly rejects the null of underidentification. The first stage is not especially weak, although the partial R^2 remains small and the cluster-robust KP rk Wald F should be interpreted cautiously. However, the Hansen J test strongly rejects the joint validity of the full instrument set, implying that at least some of the candidate life events violate the exclusion restriction. Therefore, the key empirical task is no longer to establish basic identification, but to recover a valid subset of instruments from the larger candidate set.	
	

log close




*-----------------------------------------------------*
* Step 1: Build an individual first-stage screening table
*-----------------------------------------------------*
//Given that the full candidate set is not underidentified but the Hansen test rejects the joint validity of all life-event instruments, the empirical strategy proceeds in two steps. First, a light first-stage screening is applied to remove instruments with negligible predictive content for GHQ, thereby stabilising the instrument-specific ratio estimates used in valid-IV selection. Second, the CI method is implemented on the retained candidate set, selecting the largest group of instruments with overlapping confidence intervals, with model choice refined by a downward testing procedure based on the Hansen J test.

local y newjob
local d ghq
local x lnw dvage age2 male
local z deathfam familyprob neighbour friendend ///
        vacation leisure engage birthday anniversary godparent relatives friends

tempname memhold
tempfile firststage_table

postfile `memhold' str20 ivname double b se t p using `firststage_table', replace

foreach v of local z {
    quietly regress `d' `x' `v', vce(cluster pidp)
    local b  = _b[`v']
    local se = _se[`v']
    local t  = _b[`v'] / _se[`v']
    local p  = 2*ttail(e(df_r), abs(`t'))

    post `memhold' ("`v'") (`b') (`se') (`t') (`p')
}

postclose `memhold'

use `firststage_table', clear
gsort p
list, clean noobs


*Baseline screen
gen byte keep_base = (abs(t) >= 1 | p <= 0.30)
list ivname t p keep_base, clean noobs

*Stricter screen
gen byte keep_strict = (abs(t) >= 1.64)
list ivname t p keep_strict, clean noobs

*/



*******************************************************
* CI method with weak-IV pre-screen and valid-subset selection
* Main use: choose one of z_full, z_base, z_core as z_use
* Outcome: newjob
* Endogenous regressor: ghq
* Exogenous controls: lnw dvage age2 male
* Cluster level: pidp
*******************************************************
clear all 

use ghqevent,clear 

log using "ci.log", replace

*******************************************************
* CI method with weak-IV pre-screen and valid-subset selection
* Corrected version
*
* Main use:
*   local z_use `z_base'
*   or
*   local z_use `z_core'
*   or
*   local z_use `z_full'
*******************************************************

set more off

*-----------------------------------------------------*
* 0. Optional package installation
*-----------------------------------------------------*
* ssc install ivreg2, replace
* ssc install ranktest, replace

*-----------------------------------------------------*
* 1. Define variable lists
*-----------------------------------------------------*
local y newjob
local d ghq
local x lnw dvage age2 male

local z_full deathfam familyprob neighbour friendend ///
             vacation leisure engage birthday anniversary godparent relatives friends

local z_base familyprob vacation deathfam friendend ///
             leisure anniversary engage neighbour relatives birthday

local z_core familyprob vacation deathfam friendend ///
             leisure anniversary engage neighbour relatives

*-----------------------------------------------------*
* 2. Choose the candidate set for CI selection
*-----------------------------------------------------*
local z_use `z_base'

*-----------------------------------------------------*
* 3. Clean old variables
*-----------------------------------------------------*
capture drop touse y_r d_r
foreach v of local z_full {
    capture drop `v'_r
}

*-----------------------------------------------------*
* 4. Define a common estimation sample using z_full
*-----------------------------------------------------*
quietly ivregress 2sls `y' `x' (`d' = `z_full')
gen byte touse = e(sample)

count if touse
display as text "Common estimation sample size = " as result r(N)

if r(N) == 0 {
    display as error "No observations in the common estimation sample."
    exit 2000
}

scalar pthr = 0.1 / log(r(N))
display as text "Downward-testing p-value threshold = " ///
    as result %10.6f scalar(pthr)

preserve
keep if touse

*-----------------------------------------------------*
* 5. Partial out exogenous controls from y, d, and z_use
*-----------------------------------------------------*
quietly regress `y' `x'
predict double y_r, resid

quietly regress `d' `x'
predict double d_r, resid

local z_r
foreach v of local z_use {
    quietly regress `v' `x'
    predict double `v'_r, resid
    local z_r `z_r' `v'_r
}

*-----------------------------------------------------*
* 6. Save the working sample before switching datasets
*-----------------------------------------------------*
tempfile worksample
save `worksample', replace

*-----------------------------------------------------*
* 7. Compute instrument-specific just-identified IV estimates
*    IMPORTANT: keep the original z_use order, do not sort
*-----------------------------------------------------*
tempname memhold1
tempfile ci_input

postfile `memhold1' str20 ivname double bhat sehat using `ci_input', replace

foreach zj of local z_r {
    local others : list z_r - zj
    quietly ivreg2 y_r `others' (d_r = `zj'), cluster(pidp)
    post `memhold1' ("`zj'") (_b[d_r]) (_se[d_r])
}

postclose `memhold1'

use `ci_input', clear
gen ivname_clean = subinstr(ivname, "_r", "", .)

display as text "Instrument-specific estimates in original z_use order:"
list ivname_clean bhat sehat, clean noobs

mkmat bhat sehat, matrix(ci_est)
matrix rownames ci_est = `z_use'
matrix colnames ci_est = bhat sehat

*-----------------------------------------------------*
* 8. Mata helper functions
*-----------------------------------------------------*
mata:

real colvector mask_to_idx(real scalar mask, real scalar k)
{
    real colvector idx
    real scalar j

    idx = J(0,1,.)
    for (j=1; j<=k; j++) {
        if (mod(floor(mask / (2^(j-1))), 2) == 1) {
            idx = idx \ j
        }
    }
    return(idx)
}

real colvector unique_sorted(real colvector x)
{
    real colvector xs, out
    real scalar i

    if (rows(x)==0) return(x)

    xs  = sort(x,1)
    out = xs[1]

    for (i=2; i<=rows(xs); i++) {
        if (abs(xs[i] - out[rows(out)]) > 1e-10) {
            out = out \ xs[i]
        }
    }
    return(out)
}

real matrix unique_by_mask(real matrix A)
{
    real matrix S, out
    real colvector ord
    real scalar i

    if (rows(A)==0) return(A)

    ord = order(A[,2], 1)
    S   = A[ord,.]
    out = S[1,.]

    for (i=2; i<=rows(S); i++) {
        if (S[i,2] != out[rows(out),2]) {
            out = out \ S[i,.]
        }
    }

    return(out)
}

real matrix collect_candidate_groups(real colvector b, real colvector se, real colvector psi_vals)
{
    real scalar k, mask, nmask, i, s, bestsize
    real colvector idx, lo, hi
    real matrix allcand, tmp

    k = rows(b)
    nmask = 2^k - 1
    allcand = J(0,3,.)

    for (i=1; i<=rows(psi_vals); i++) {
        bestsize = 0
        tmp = J(0,3,.)

        for (mask=1; mask<=nmask; mask++) {
            idx = mask_to_idx(mask, k)
            s   = rows(idx)

            lo = b[idx] :- psi_vals[i] :* se[idx]
            hi = b[idx] :+ psi_vals[i] :* se[idx]

            if (max(lo) < min(hi)) {
                if (s > bestsize) {
                    bestsize = s
                    tmp = J(0,3,.)
                }
                if (s == bestsize) {
                    tmp = tmp \ (psi_vals[i], mask, s)
                }
            }
        }

        if (rows(tmp) > 0) {
            allcand = allcand \ tmp
        }
    }

    return(unique_by_mask(allcand))
}

end

*-----------------------------------------------------*
* 9. Build CI candidate groups using breakpoints
*-----------------------------------------------------*
mata:

E  = st_matrix("ci_est")
b  = E[,1]
se = E[,2]
k  = rows(b)

bp = J(0,1,.)
for (j=1; j<=k-1; j++) {
    for (r=j+1; r<=k; r++) {
        bp = bp \ (abs(b[j] - b[r]) / (se[j] + se[r]))
    }
}
bp = unique_sorted(bp)

if (rows(bp) > 0) {
    psi_vals = J(rows(bp)+1,1,.)
    psi_vals[1] = max(bp) + 1
    for (i=1; i<=rows(bp); i++) {
        psi_vals[i+1] = bp[rows(bp)-i+1]
    }
}
else {
    psi_vals = 1
}

cand = collect_candidate_groups(b, se, psi_vals)
st_matrix("ci_candidates", cand)

end

matrix colnames ci_candidates = psi mask nvalid

display as text "Candidate CI groups:"
matrix list ci_candidates

*-----------------------------------------------------*
* 10. Restore the working sample before evaluating candidates
*-----------------------------------------------------*
use `worksample', clear

*-----------------------------------------------------*
* 11. Evaluate each candidate group using clustered post-selection 2SLS
*-----------------------------------------------------*
tempname memhold2
tempfile candidate_eval

postfile `memhold2' double psi mask nvalid J Jp beta using `candidate_eval', replace

scalar ncand = rowsof(ci_candidates)

forvalues r = 1/`=scalar(ncand)' {

    local valid
    local invalid

    scalar mask_now = el(ci_candidates, `r', 2)
    scalar psi_now  = el(ci_candidates, `r', 1)
    scalar nval_now = el(ci_candidates, `r', 3)

    local j = 1
    foreach v of local z_use {
        scalar bit = mod(floor(mask_now / (2^(`j'-1))), 2)

        if scalar(bit) == 1 {
            local valid `valid' `v'
        }
        else {
            local invalid `invalid' `v'
        }

        local ++j
    }

    local nvalid : word count `valid'

    if "`invalid'" == "" {
        quietly ivreg2 `y' `x' (`d' = `valid'), cluster(pidp)
    }
    else {
        quietly ivreg2 `y' `x' `invalid' (`d' = `valid'), cluster(pidp)
    }

    local beta = _b[`d']
    local J  = .
    local Jp = .

    if `nvalid' > 1 {
        capture local J  = e(j)
        capture local Jp = e(jp)
    }

    post `memhold2' (scalar(psi_now)) (scalar(mask_now)) (`nvalid') ///
        (`J') (`Jp') (`beta')
}

postclose `memhold2'

use `candidate_eval', clear
gsort -nvalid -Jp
display as text "Candidate evaluation table:"
list, clean noobs

*-----------------------------------------------------*
* 12. Downward testing:
*     choose the largest valid set with Hansen J p-value > pthr
*-----------------------------------------------------*
gen byte pass = (nvalid >= 2 & Jp > scalar(pthr))

count if pass == 1

if r(N) > 0 {
    gsort -pass -nvalid -Jp
    keep if pass == 1
    keep in 1
}
else {
    display as error "No overidentified candidate passes the Hansen threshold."
    display as error "Fallback: choosing the candidate with the largest nvalid and highest Hansen p-value."
    gsort -nvalid -Jp
    keep in 1
}

scalar final_mask = mask[1]
scalar final_psi  = psi[1]
scalar final_nval = nvalid[1]
scalar final_J    = J[1]
scalar final_Jp   = Jp[1]
scalar final_beta = beta[1]

display as text "Final selected psi        = " as result %10.6f scalar(final_psi)
display as text "Final selected mask       = " as result %10.0f scalar(final_mask)
display as text "Final number of valid IVs = " as result %10.0f scalar(final_nval)
display as text "Final Hansen J statistic  = " as result %10.6f scalar(final_J)
display as text "Final Hansen J p-value    = " as result %10.6f scalar(final_Jp)
display as text "Final beta on ghq         = " as result %10.6f scalar(final_beta)

*-----------------------------------------------------*
* 13. Decode the final valid and invalid sets
*-----------------------------------------------------*
local valid_final
local invalid_final

local j = 1
foreach v of local z_use {
    scalar bit = mod(floor(scalar(final_mask) / (2^(`j'-1))), 2)

    if scalar(bit) == 1 {
        local valid_final `valid_final' `v'
    }
    else {
        local invalid_final `invalid_final' `v'
    }

    local ++j
}

display as text "Selected valid instruments:   `valid_final'"
display as text "Selected invalid instruments: `invalid_final'"

*-----------------------------------------------------*
* 14. Restore the working sample and run final post-selection 2SLS
*-----------------------------------------------------*
use `worksample', clear

local nvalid_final : word count `valid_final'

if `nvalid_final' == 0 {
    display as error "No valid instruments selected."
}
else {
    if "`invalid_final'" == "" {
        ivreg2 `y' `x' (`d' = `valid_final'), cluster(pidp) first
    }
    else {
        ivreg2 `y' `x' `invalid_final' (`d' = `valid_final'), cluster(pidp) first
    }
}

restore

*******************************************************
* End of corrected CI method routine
*******************************************************

log close














ex

// //original
// local negset deathfam familyprob neighbour friendend
// local posset vacation leisure engage birthday anniversary godparent relatives friends
//
// ivregress 2sls newjob lnw dvage age2 male (ghq = `negset' `posset'), vce(cluster pidp) first


*CI method

*******************************************************
* Confidence Interval (CI) method for selecting valid IVs
* Single endogenous regressor: ghq
* Outcome: newjob
* Candidate instruments: life events
*
* Paper-faithful selection stage:
* 1. Partial out exogenous controls
* 2. Compute instrument-specific just-identified IV estimates
* 3. Build CI groups
* 4. Use Sargan-based downward testing
*
* Practical reporting stage:
* Final post-selection 2SLS is reported with clustered SEs
*******************************************************

version 18
set more off
mata clear

*-----------------------------------------------------*
* 1. Define variable lists
*-----------------------------------------------------*
local y newjob
local d ghq
local x lnw dvage age2 male

local negset deathfam familyprob neighbour friendend
local posset vacation leisure engage birthday anniversary godparent relatives friends
local z `negset' `posset'

*-----------------------------------------------------*
* 2. Clean previously created variables if they exist
*-----------------------------------------------------*
capture drop touse y_r d_r
foreach v of local z {
    capture drop `v'_r
}

*-----------------------------------------------------*
* 3. Define the estimation sample using the baseline IV model
*-----------------------------------------------------*
quietly ivregress 2sls `y' `x' (`d' = `z')
gen byte touse = e(sample)

count if touse
display as text "Estimation sample size = " as result r(N)

if r(N) == 0 {
    display as error "No observations in e(sample). Check variable names and missing values."
    exit 2000
}

preserve
keep if touse

*-----------------------------------------------------*
* 4. Partial out exogenous controls from y, d, and z
*-----------------------------------------------------*
quietly regress `y' `x'
predict double y_r, resid

quietly regress `d' `x'
predict double d_r, resid

local z_r
foreach v of local z {
    quietly regress `v' `x'
    predict double `v'_r, resid
    local z_r `z_r' `v'_r
}

*-----------------------------------------------------*
* 5. Compute instrument-specific just-identified IV estimates
*    Each instrument is used as the single excluded IV,
*    while all other candidate instruments are treated as invalid
*    and therefore included as regressors
*-----------------------------------------------------*
local kz : word count `z'

tempname B SE
matrix `B'  = J(`kz',1,.)
matrix `SE' = J(`kz',1,.)

local j = 1
foreach zj of local z_r {
    local others : list z_r - zj

    quietly ivregress 2sls y_r `others' (d_r = `zj')
    matrix `B'[`j',1]  = _b[d_r]
    matrix `SE'[`j',1] = _se[d_r]

    local ++j
}

matrix inst_est = `B', `SE'
matrix rownames inst_est = `z'
matrix colnames inst_est = bhat se

display as text "Instrument-specific just-identified IV estimates:"
matrix list inst_est

*-----------------------------------------------------*
* 6. Mata helper functions
*-----------------------------------------------------*
mata:

real colvector mask_to_idx(real scalar mask, real scalar k)
{
    real colvector idx
    real scalar j

    idx = J(0,1,.)
    for (j=1; j<=k; j++) {
        if (mod(floor(mask / (2^(j-1))), 2) == 1) {
            idx = idx \ j
        }
    }
    return(idx)
}

real colvector complement_idx(real colvector idx, real scalar k)
{
    real colvector all, keep
    all  = (1::k)
    keep = J(k,1,1)
    if (rows(idx) > 0) keep[idx] = J(rows(idx),1,0)
    return(select(all, keep))
}

real colvector unique_sorted(real colvector x)
{
    real colvector xs, out
    real scalar i

    if (rows(x)==0) return(x)

    xs  = sort(x,1)
    out = xs[1]

    for (i=2; i<=rows(xs); i++) {
        if (abs(xs[i] - out[rows(out)]) > 1e-10) {
            out = out \ xs[i]
        }
    }
    return(out)
}

real rowvector post2sls_sargan(real colvector y, real colvector d, real matrix Z, real colvector valid)
{
    real scalar n, k, df, p, S
    real colvector invalid, u
    real matrix PZ, X, XPZX, theta

    n = rows(Z)
    k = cols(Z)

    invalid = complement_idx(valid, k)

    X = d
    if (rows(invalid) > 0) {
        X = X, Z[, invalid]
    }

    PZ   = Z * invsym(quadcross(Z,Z)) * Z'
    XPZX = quadcross(X, PZ*X)
    theta = invsym(XPZX) * quadcross(X, PZ*y)

    u = y - X*theta

    S  = quadcross(u, PZ*u) / (quadcross(u,u) / n)
    df = rows(valid) - 1

    if (df > 0) p = chi2tail(df, S)
    else        p = .

    return((S, p, theta[1,1]))
}

real matrix largest_overlap_groups(real colvector b, real colvector se, real scalar psi,
                                   real colvector y, real colvector d, real matrix Z)
{
    real scalar k, mask, nmask, bestsize, s
    real colvector idx, lo, hi
    real rowvector info
    real matrix out

    k      = rows(b)
    nmask  = 2^k - 1
    bestsize = 0
    out = J(0,5,.)

    for (mask=1; mask<=nmask; mask++) {
        idx = mask_to_idx(mask, k)
        s   = rows(idx)

        lo = b[idx] :- psi * se[idx]
        hi = b[idx] :+ psi * se[idx]

        * Strict overlap rule, matching the breakpoint logic in the paper
        if (max(lo) < min(hi)) {
            if (s > bestsize) {
                bestsize = s
                out = J(0,5,.)
            }

            if (s == bestsize) {
                info = post2sls_sargan(y, d, Z, idx)
                out  = out \ (mask, s, info[1], info[2], info[3])
            }
        }
    }

    return(out)
}

end

*-----------------------------------------------------*
* 7. Run the CI method and Sargan-based downward testing
*-----------------------------------------------------*
mata:

E  = st_matrix("inst_est")
b  = E[,1]
se = E[,2]

y  = st_data(., "y_r")
d  = st_data(., "d_r")
Z  = st_data(., tokens(st_local("z_r")))

n  = rows(Z)
k  = cols(Z)

* Sargan p-value threshold suggested in the paper
pthr = 0.1 / log(n)

* Breakpoints psi*_jr = |b_j - b_r| / (se_j + se_r)
bp = J(0,1,.)
for (j=1; j<=k-1; j++) {
    for (r=j+1; r<=k; r++) {
        bp = bp \ (abs(b[j] - b[r]) / (se[j] + se[r]))
    }
}
bp = unique_sorted(bp)

* Build descending psi values:
* first a value above the largest breakpoint for the all-valid model,
* then all breakpoints in descending order
if (rows(bp) > 0) {
    psi_vals = J(rows(bp)+1,1,.)
    psi_vals[1] = max(bp) + 1
    for (i=1; i<=rows(bp); i++) {
        psi_vals[i+1] = bp[rows(bp)-i+1]
    }
}
else {
    psi_vals = 1
}

* Store all candidate groups:
* columns = psi, mask, nvalid, Sargan, pvalue, beta_post
All = J(0,6,.)
for (i=1; i<=rows(psi_vals); i++) {
    G = largest_overlap_groups(b, se, psi_vals[i], y, d, Z)
    if (rows(G) > 0) {
        All = All \ (J(rows(G),1,psi_vals[i]), G)
    }
}

* For each valid-set size, keep the candidate with the minimum Sargan statistic
Best = J(0,6,.)
for (s=k; s>=1; s--) {
    idx = selectindex(All[,3] :== s)
    if (rows(idx) > 0) {
        sub = All[idx,]
        pos = order(sub[,4], 1)[1]
        Best = Best \ sub[pos,]
    }
}

* Choose the largest valid set that passes the Sargan threshold
finalrow = .
passflag = 0

for (i=1; i<=rows(Best); i++) {
    if (Best[i,3] >= 2 & Best[i,5] > pthr) {
        finalrow = i
        passflag = 1
        break
    }
}

* Fallback if no overidentified model passes the threshold
if (missing(finalrow)) {
    idx = selectindex(Best[,3] :>= 2)
    if (rows(idx) > 0) {
        sub = Best[idx,]
        pos = order(sub[,4], 1)[1]
        finalrow = idx[pos]
    }
    else {
        finalrow = 1
    }
}

st_numscalar("pthr", pthr)
st_numscalar("passflag", passflag)

st_numscalar("final_psi",   Best[finalrow,1])
st_numscalar("final_mask",  Best[finalrow,2])
st_numscalar("final_nval",  Best[finalrow,3])
st_numscalar("final_S",     Best[finalrow,4])
st_numscalar("final_p",     Best[finalrow,5])
st_numscalar("final_beta",  Best[finalrow,6])

st_matrix("ci_size_results", Best)

end

matrix colnames ci_size_results = psi mask nvalid sargan pvalue beta_post

display as text "Sargan p-value threshold = " as result %9.6f scalar(pthr)
display as text "Candidate models by valid-set size (best Sargan within each size):"
matrix list ci_size_results

display as text "Final selected psi      = " as result %10.6f scalar(final_psi)
display as text "Final selected mask     = " as result %10.0f scalar(final_mask)
display as text "Final number of valid IVs = " as result %10.0f scalar(final_nval)
display as text "Final Sargan statistic  = " as result %10.6f scalar(final_S)
display as text "Final Sargan p-value    = " as result %10.6f scalar(final_p)
display as text "Final post-selection beta on residualized data = " as result %10.6f scalar(final_beta)

if scalar(passflag)==1 {
    display as text "A model passed the Sargan threshold."
}
else {
    display as error "No overidentified model passed the Sargan threshold."
    display as error "Fallback: the code selected the model with the smallest Sargan statistic."
}

*-----------------------------------------------------*
* 8. Decode the final valid and invalid instrument sets
*-----------------------------------------------------*
local valid
local invalid
local j = 1

foreach v of local z {
    scalar bit = mod(floor(scalar(final_mask) / (2^(`j'-1))), 2)

    if scalar(bit) == 1 {
        local valid `valid' `v'
    }
    else {
        local invalid `invalid' `v'
    }

    local ++j
}

display as text "Selected valid instruments:   `valid'"
display as text "Selected invalid instruments: `invalid'"

*-----------------------------------------------------*
* 9. Run the final post-selection 2SLS on original variables
*    Invalid instruments are included as controls
*    Valid instruments remain excluded IVs
*-----------------------------------------------------*
local nvalid : word count `valid'

if `nvalid' == 0 {
    display as error "No valid instruments selected."
}
else {
    if "`invalid'" == "" {
        ivregress 2sls `y' `x' (`d' = `valid'), vce(cluster pidp) first
    }
    else {
        ivregress 2sls `y' `x' `invalid' (`d' = `valid'), vce(cluster pidp) first
    }

    if `nvalid' > 1 {
        capture noisily estat overid
    }
}

restore

*******************************************************
* End of CI method routine
*******************************************************














