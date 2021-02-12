// OECD National Accounts (https://stats.oecd.org/)
//ssc install genstack

//import household accounts from oecd
cap qui import delimited "Data/OECD/OECD_SNA_TABLE14A_en.csv", clear 
qui keep if strpos(sector, "S14")
qui rename (ïlocation) (iso3)	

//save labels
qui levelsof transact, local(trans) 
foreach t in `trans' {
	qui levelsof transaction if transact == "`t'", local(`t'_name) clean
}

//drop combined sectors when useless
qui levelsof iso3, local(isos)
foreach c in `isos' {
	qui levelsof sector if iso3 == "`c'", local(`c'_seclist) clean
	if r(r) >=2 qui drop if iso3 == "`c'" & sector == "S14_S15" 
	qui levelsof country if iso3 == "`c'", local(`c'_name) clean
	qui levelsof unitcode if iso3 == "`c'", local(`c'_unit) clean
	qui levelsof powercode if iso3 == "`c'", local(`c'_pow) clean
}

//reshape
qui drop flag* transaction ref*
qui reshape wide value, i(iso3 year) j(transact) string
qui rename value* *
qui sort iso3 year

//labels
foreach t in `trans' {
	capture qui label var `t' "``t'_name'"
}

//create variables
qui gen depr = NFK1MP
qui gen os_g   = NFB2GR
qui gen mixinc = NFB3GR
qui gen npi = NFD4R - NFD4P
qui gen notcap = NFD44R + NFD43R
qui gen othprop = npi - notcap
qui gen capi = othprop + os_g
qui gen wages = NFD11R
qui gen empssc = NFD12R 
qui gen hh_g = os_g + npi + mixinc + wages + empssc  
qui gen test = wages + empssc + mixinc + capi+ notcap

levelsof iso3 if missing(test)
keep if !missing(test)
kountry iso3, from(iso3c) to(iso2c)
rename _ISO2C_ iso2
qui egen ctry_year=concat(iso2 year)

//bring LIS data ---------------------------------------------------------------

//Wage and Capital income decomoposition in LIS (2019 data)

preserve
	qui import delimited "Data/testccyy.csv", clear
	
	//Transform to merge 
	qui gen iso2=substr(ccyy,1,2)
	qui gen year=substr(ccyy,3,2)
	qui destring year mean_toti, replace
	qui drop if missing(mean_toti)
	qui replace year=year+1900 if year>=50
	qui replace year=year+2000 if year<50
	qui replace iso2=strupper(iso2)
	qui replace iso2="GB" if iso2=="UK"
	qui egen ctry_year=concat(iso2 year)
	//save
	tempfile tf1 
	qui save `tf1', replace
restore

//The rest of the data from LIS (pre 2019 data)
preserve 
	cap qui import excel "Data/ccyy2.xlsx", sheet("Hoja1") firstrow clear
	qui gen iso2=substr(ccyy,1,2)
	qui gen year=substr(ccyy,3,2)
	qui destring year mean_toti, replace
	qui drop if missing(mean_toti)
	qui replace year=year+1900 if year>=50
	qui replace year=year+2000 if year<50
	qui replace iso2=strupper(iso2)
	qui replace iso2="GB" if iso2=="UK"
	qui egen ctry_year=concat(iso2 year)
	
	//save
	tempfile tf2 
	qui save `tf2', replace
restore 

//merge 
//preserve

	qui merge 1:1 ctry_year using `tf1', generate(_merge1)
	qui merge 1:1 ctry_year using `tf2', generate(_merge2)	

	// create main variables
	qui gen share_intdiv_svy = tot_intdiv / tot_K	
	qui gen share_rent_svy = tot_rent / tot_K 
	qui gen share_ipen_svy = (tot_K - tot_k) / tot_K
	qui gen share_wage_svy = (tot_l - tot_s) / tot_l
	
	//Keep matching observations 
	qui keep if _merge2 == 3 & _merge1 == 3
	
	//Test for consistency
	qui levelsof defl, local(defl_v)
	foreach v in `defl_v' {
		if `v' != 1 {
			display as text "LIS databases cannot be merged, defl = `v'"
			exit 1
		}
		else {
			display as text "LIS databases can be merged"
		}
	}

	qui label var share_intdiv_svy ///
		"Interests and Dividends as share of Capital Income (Survey)"	
	qui label var share_rent_svy ///
		"Rents as share of Capital Income (Survey)"
	qui label var share_wage_svy ///
		"Wages as share of Labour Inc. in Survey (which normally incl. SE)"	
	
	qui gen epsi_L_oecd = tot_L * share_wage_svy / wages * 100 
	qui gen epsi_K_oecd = tot_K * share_intdiv_svy / (NFD41R + NFD42R) * 100 
	qui gen ratio_oecd = epsi_K_oecd / epsi_L_oecd * 100
	
	//oecd data is in millions
	foreach var in "epsi_K_oecd" "epsi_L_oecd" {
		qui replace `var' = `var' / 1000000
	}
	
	graph twoway (connected epsi_K_oecd year, lcolor(edkblue) ///
		msize(small) mcolor(edkblue) mfcolor(edkblue)) ///
		(connected epsi_L_oecd year, lcolor(maroon) ///
		mcolor(maroon) msize(small) mfcolor(maroon)) ///
		(connected ratio_oecd year, lcolor(gs10) ///
		mcolor(gs10) msize(vsmall) mfcolor(gs10)) ///
		if !missing(epsi_K_oecd) & iso2!="EE" & iso2!="MX"  ///
		, by(iso2, note("")) ///
		ytitle("Share of Income Captured (% of Nat. Acc.)") xtitle("") ///
		yline(100, lcolor(black) lpattern(dot)) ///
		xlabel(2008(2)2016, labsize(small) angle(horizontal) grid labels) ///
		ylabel(0(20)120, labsize(small) angle(horizontal) grid labels)  ///
		graphregion(color(white)) plotregion(lcolor(bluishgray)) scale(1.2) ///
		legend(label(1 "Dividends and Interest") label(2 "Wages") ///
		label(3 "Ratio (Divs. and Int. over Wages)")) ///
		scheme(s1color) subtitle(,fcolor(white) lcolor(bluishgray))
	capture graph export ///
		"~/figures_apdx/Epsialt_ByCtry.pdf", replace	
				
	//What about rents? 
	qui gen epsi_rents = (tot_IR + tot_rent) / os_g * 100 / 1000000
	qui gen epsitest = tot_IR / tot_rent * 100
	
	graph twoway (connected epsi_rents year, lcolor(edkblue) ///
		msize(small) mcolor(edkblue) mfcolor(edkblue)) ///
		if !missing(epsi_K_oecd) & iso2!="EE" & iso2!="MX" & iso2!="HU" ///
		, by(iso2, note("")) ///
		ytitle("Share of Income Captured (% of Nat. Acc.)") xtitle("") ///
		yline(100, lcolor(cranberry)) ///
		xlabel(2008(2)2016, labsize(small) angle(horizontal) grid labels) ///
		ylabel(0(40)200, labsize(small) angle(horizontal) grid labels)  ///
		graphregion(color(white)) plotregion(lcolor(bluishgray)) scale(1.2) ///
		legend(label(1 "Rents (Imputed and Realized)")) ///
		scheme(s1color) subtitle(,fcolor(white) lcolor(bluishgray))
	capture graph export "figures_apdx/Epsirent_ByCtry.pdf", replace						
//restore
//------------------------------------------------------------------------------

//prepare for graph
local vars "capi notcap mixinc wages empssc npi depr test hh_g" 
foreach v in `vars' { 
	qui replace `v' = `v' / hh_g * 100
} 
local stackvars "wages empssc mixinc capi notcap"
genstack `stackvars', gen(forp_)
qui levelsof iso3 if !missing(hh_g), local(graph_ctries)
foreach  c in `graph_ctries' {
	graph twoway ///
		(area forp_notcap year, color(maroon*0.7)) ///
		(area forp_capi year, color(maroon)) ///	
		(area forp_mixinc year, color(sand)) ///
		(area forp_empssc year, color(edkblue*0.7)) ///
		(area forp_wages year, color(edkblue)) ///
		 if iso3 == "`c'", ///
		 ylabel(0(10)100, angle(horizontal)) ///
		 graphregion(color(white)) plotregion(lcolor(bluishgray)) ///
		 legend(label(1 "Conflictive Cap. Inc.") label(2 "Capital Income") ///
		 label(3 "Mixed Income") label(4 "Conflictive Lab. Inc.") ///
		 label(5 "Wages")) ///
		 scale(1.2)
	capture graph export "figures_apdx/`c'_oecdsna.pdf", replace		
}

