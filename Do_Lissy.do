//
// 
//

//Get country names and years
import excel "~/Dropbox/Under_the_carpet/Data/lisctryyears.xlsx" ///
	, sheet("Hoja1") firstrow clear
quietly gen ctry=substr(code,1,2)
quietly gen yr=substr(code,3,2)
quietly replace ctry=strlower(ctry)
quietly levelsof ctry, local(countries) clean

foreach c in `countries'{
	levelsof yr if ctry=="`c'", local(`c'years) clean
}

// copy-paste-able (log)
local iter=1
foreach c in `countries'{
	if `iter'==1 {
		di `"local countries "`countries'" "'
	}
	di `"local `c'years "``c'years'" "'
	local iter=0
}	
exit 1

//Get currencies


//----------------------------------------------------------------------------//
// BEGINNING OF LISSY CODE
//----------------------------------------------------------------------------//

local define_region "PANEL" // PANEL or LATAM

//Locals
local weight "hpopwgt"
local ctry_year "dname"
local i_L "hil"
local i_S "hils"
local i_K "hic"
local i_IR "hchousi"
local toti "factor" 
local inc_concepts "factor hil hils hic hchousi"

if ("`define_region'"=="LATAM"){
	local countries "mx cl br co pe"
	local countries "at be ca ch cz de dk ee fi fr gb gr hu it nl no pl pt se sk" 
	local mxyears "89 92 94 96 98 00 02 04 08 10 12"
	local clyears "90 92 94 96 98 00 03 06 09 11 13 15"
	local bryears "06 09 11 13"
	local coyears "04 07 10 13"
	local peyears "04 07 10 13"
}

if ("`define_region'"=="PANEL"){
	local countries "at ca ch cz de dk ee es fi fr gr hu it mx cl nl pl se sk uk us" 
	local atyears "00 04 07 10 13 87 94 95 97" 
	local cayears "00 04 07 10 13 71 75 81 87 91 94 97 98" 
	local chyears "00 02 04 07 10 13 82 92" 
	local clyears "90 92 94 96 98 00 03 06 09 11 13 15"
	local czyears "02 04 07 10 13 92 96" 
	local deyears "00 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 73 78 81 83 84 87 89 91 94 95 98" 
	local dkyears "00 04 07 10 13 87 92 95" 
	local eeyears "00 04 07 10 13" 
	local esyears "00 04 07 10 13 80 85 90 95" 
	local fiyears "00 04 07 10 13 87 91 95" 
	local fryears "00 05 10 78 84 89 94" 
	local gryears "00 04 07 10 13 95" 
	local huyears "05 07 09 12 15 91 94 99" 
	local ityears "00 04 08 10 14 86 87 89 91 93 95 98" 
	local mxyears "00 02 04 08 10 12 84 89 92 94 96 98" 
	local nlyears "04 07 10 13 83 87 90 93 99" 
	local plyears "04 07 10 13 16 86 92 95 99" 
	local seyears "00 05 67 75 81 87 92 95" 
	local skyears "04 07 10 13 92 96" 
	local ukyears "04 07 10 13 69 74 79 86 91 94 95 99" 
	local usyears "00 04 07 10 13 16 74 79 86 91 94 97"
}

//Build Panel
local iter=1 
foreach c in `countries' { 
	foreach y in ``c'years' {
		local ccyy "`c'`y'"
		if (`iter'==1) {
			use `ctry_year' `weight' `inc_concepts' deflator npers nhhmem currency grossnet wave using $`ccyy'h, clear
		}
		quietly append using $`ccyy'h , ///
			keep(`ctry_year' `weight' `inc_concepts' deflator npers nhhmem currency grossnet wave)
		local iter=0
	}
}

//use "~/Downloads/us04ih.dta", clear
//append using "~/Downloads/it04ih.dta"

//Total Population (households)
quietly levelsof `ctry_year', local(c_years)
quietly gen totweight=.
foreach c in `c_years'{
	quietly sum `weight' if `ctry_year'=="`c'"
	quietly replace totweight=r(sum) if `ctry_year'=="`c'"
}

//Sort
foreach i in `inc_concepts'{
	quietly replace `i'=`i'*deflator
}	
quietly gen inc_tot=`i_L'+`i_K'
quietly replace inc_tot=0 if missing(inc_tot)
sort `ctry_year' inc_tot	
	
//Cumulated Population
quietly gen freq= `weight'/totweight
quietly gen F=.
foreach c in `c_years' {
	quietly replace F=sum(freq) if `ctry_year'=="`c'"
}
quietly egen ftile = cut(F), at(0(0.01)0.99 0.991(0.001)1) 	 

//Income Totals
local inc_concepts "`inc_concepts' inc_tot"
foreach i in `inc_concepts'{
	quietly gen tot_`i'=.
	quietly gen b50_`i'=.
	quietly gen m40_`i'=.
	quietly gen t10_`i'=.
	quietly gen t1_`i'=.
	foreach c in `c_years'{
		quietly sum `i' [w=`weight'] if `ctry_year'=="`c'"  
		quietly replace tot_`i'=r(sum) if `ctry_year'=="`c'"
		quietly sum `i' [w=`weight'] if `ctry_year'=="`c'"  & ftile<=0.5
		quietly replace b50_`i'=r(sum) if `ctry_year'=="`c'" & ftile<=0.5
		quietly sum `i' [w=`weight'] if `ctry_year'=="`c'"  & ftile>0.5 & ftile<0.9 
		quietly replace m40_`i'=r(sum) if `ctry_year'=="`c'" & ftile>0.5 & ftile<0.9 
		quietly sum `i' [w=`weight'] if `ctry_year'=="`c'"  & ftile>0.9
		quietly replace t10_`i'=r(sum) if `ctry_year'=="`c'" & ftile>0.9
		quietly sum `i' [w=`weight'] if `ctry_year'=="`c'"  & ftile>0.99
		quietly replace t1_`i'=r(sum) if `ctry_year'=="`c'" & ftile>0.99
	} 
}

quietly gen np_hh=npers*`weight'
quietly gen nhm_hh=nhhmem*`weight'

foreach cy in `c_years'{
	quietly sum np_hh if `ctry_year'=="`cy'"
	scal scl_tot_np_`cy'=r(sum)
	quietly sum nhm_hh if `ctry_year'=="`cy'"
	scal scl_tot_hm_`cy'=r(sum) 
}

//Collapse
quietly collapse (median) tot_inc=tot_inc_tot t10_tot=t10_inc_tot t1_tot=t10_inc_tot ///
	tot_L=tot_`i_L' tot_K=tot_`i_K' tot_S=tot_`i_S' tot_IR=tot_`i_IR' ///
	t10_L=t10_`i_L' t10_K=t10_`i_K' t10_S=t10_`i_S' t10_IR=t10_`i_IR' ///
	b50_L=b50_`i_L' b50_K=b50_`i_K' b50_S=b50_`i_S' b50_IR=b50_`i_IR' ///
	m40_L=m40_`i_L' m40_K=m40_`i_K' m40_S=m40_`i_S' m40_IR=m40_`i_IR' ///
	t1_L=t1_`i_L' t1_K=t1_`i_K' t1_S=t1_`i_S' t1_IR=t1_`i_IR' /// 
	totw=totweight waven=wave ///
	(mean) mean_toti=`toti' nprs=npers (min) defl=deflator ///
	[w=`weight'] ///
	, by(`ctry_year')
	
//Convert to csv
local vbls "tot_inc tot_L tot_K tot_S tot_IR b50_L b50_K b50_S b50_IR m40_L m40_K m40_S  m40_IR t10_L t10_K t10_S t10_IR t1_L t1_K t1_S t1_IR defl totw mean_toti nprs waven"
foreach cy in `c_years' {
	foreach v in `vbls' {
		quietly sum `v' if `ctry_year'=="`cy'"
		scal scl_`cy'_`v'=r(max)
	}
}

//Display
local iter=1
foreach c in `c_years' {
	if `iter'==1 {
		di "Main variables"
		di "ccyy,tot_inc,tot_L,tot_K,tot_S,tot_IR,b50_L,b50_K,b50_S,b50_IR,m40_L,m40_K,m40_S,m40_IR,t10_L,t10_K,t10_S,t10_IR,t1_L,t1_K,t1_S,t1_IR,defl,totw,mean_toti,nprs,waven"
	}
	di "`c'" "," scl_`c'_tot_inc "," ///
	scl_`c'_tot_L "," scl_`c'_tot_K "," scl_`c'_tot_S "," scl_`c'_tot_IR "," ///
	scl_`c'_b50_L "," scl_`c'_b50_K "," scl_`c'_b50_S "," scl_`c'_b50_IR "," ///
	scl_`c'_m40_L "," scl_`c'_m40_K "," scl_`c'_m40_S "," scl_`c'_m40_IR "," ///
	scl_`c'_t10_L "," scl_`c'_t10_K "," scl_`c'_t10_S "," scl_`c'_t10_IR "," ///
	scl_`c'_t1_L "," scl_`c'_t1_K "," scl_`c'_t1_S "," scl_`c'_t1_IR "," ///
	scl_`c'_defl "," scl_`c'_totw "," ///
	scl_`c'_mean_toti "," scl_`c'_nprs "," scl_`c'_waven
	local iter=0
}
	
