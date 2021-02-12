//----------------------------------------------------------------------------//
// BEGINNING OF LISSY CODE
//----------------------------------------------------------------------------//

local get_currencies "YES"

//Locals
local weight "hpopwgt"
local ctry_year "dname"
local i_L "hmil"
local i_S "hmils"
local i_K "hmic"
local toti "hmi" 
local inc_concepts "hmi hmil hmils hmic"

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
	local countries "at ca ch cz de dk ee es fi fr gr hu it mx nl pl se sk uk us" 
	local atyears "00 04 07 10 13 87 94 95 97" 
	local cayears "00 04 07 10 13 71 75 81 87 91 94 97 98" 
	local chyears "00 02 04 07 10 13 82 92" 
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

tempfile dofi
if ("`get_currencies'"=="YES"){
local iter=1 
	foreach c in `countries'{
		foreach y in ``c'years' {
			local ccyy "`c'`y'"
			if (`iter'==1) {
				use dname currency grossnet using $`ccyy'h, clear
				quietly label save using `dofi', replace
				quietly collapse (firstnm) currency grossnet, by(dname)
			}
		quietly append using $`ccyy'h, keep(dname currency grossnet)
		quietly collapse (firstnm) currency grossnet, by(dname)
		quietly do `dofi'
		label values currency currency 
		label values grossnet grossnet
		local iter=0
		}
	}
}

quietly levelsof dname, local(c_years)

//Convert to csv
decode currency, generate(currency_dec)
decode grossnet, generate(grossnet_dec)
local vbls "dname currency_dec grossnet_dec"
foreach v in `vbls' {
	foreach cy in `c_years' {
		quietly levelsof `v' if `ctry_year'=="`cy'", local(`cy'_`v')
	}
}

//Display
local iter=1
foreach cy in `c_years' {
	if `iter'==1 {
		di "ccyy,currency,grossnet"
	}
	di "`cy'" "," ``cy'_currency_dec' "," ``cy'_grossnet_dec'
	local iter=0
}
