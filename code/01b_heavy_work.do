//----------------------------------------------------------------------------//
// INSTITUTIONAL SECTOR ACCOUNTS (UN-DATA: http://data.un.org/)
//----------------------------------------------------------------------------//

// 0. LOCALS -----------------------------------------------------------------//

//Institutional sectors and K definition
local i_sector "HH HHnpish SFL G SF SnF SFSnF Total"
local variables "OS_g MI_g CE FKC PIr PIu FISIM"
local ordr "countryorarea series year"
local K "Kg"
local n = 5
local year1 = 1980
local grossnet "g n"

//Items
local item_OS_g "OPERATING SURPLUS, GROSS"
local item_MI_g "MIXED INCOME, GROSS"
local item_CE "Compensation of employees"
local item_FKC "Less: Consumption of fixed capital"
local item_PIr "Property income"
local item_PIu "Property income"
local item_FISIM "Less: Financial intermediation services indirectly measured (only to be deducted if FISIM is not distributed to uses)"

//I. RETRIEVE DATA OF DIFFERENT INSTITUTIONAL SECTORS ------------------------//
foreach i in `i_sector' {
	import delimited "Data/UN/UNdata_`i'.csv" , encoding(ISO-8859-1) clear
	local space " - "
	if ("`i'"=="SF" | "`i'"=="SnF" | "`i'"=="SFSnF"){
		local space "  -  "
	}
	//Locals
	local subgroup_OS_g "II.1.1 Generation of income account`space'Uses"
	local subgroup_MI_g "II.1.1 Generation of income account`space'Uses"
	local subgroup_CE "II.1.1 Generation of income account`space'Uses"
	local subgroup_FKC "I. Production account`space'Uses"
	local subgroup_PIu "II.1.2 Allocation of primary income account`space'Uses"
	local subgroup_PIr "II.1.2 Allocation of primary income account`space'Resources"
	local subgroup_FISIM "I. Production account`space'Resources"
	
	qui sort `ordr' subgroup, stable	
	foreach v in `variables' {
		qui gen `v'_`i' =.
		qui replace `v'_`i'=value ///
			if (item=="`item_`v''" & subgroup=="`subgroup_`v''")
	}

	//Collapse & save (temp)
	qui collapse (max) `variables' (firstnm) currency_sna=currency, by (`ordr')	
	qui gen NPI_`i'=PIr_`i'-PIu_`i'
	qui drop PIr_`i' PIu_`i'
	tempfile temp`i'
	qui save `temp`i''
}
//Merge in 1 file
qui use `tempTotal', clear
foreach i in `i_sector' {
	if ("`i'"!="Total"){
		qui merge 1:1 `ordr' using "`temp`i''" , nogenerate
	}	
}


// II. CREATE MAIN VARIABLES FROM NATIONAL ACCOUNTS --------------------------//  

//MI and NI
qui gen MI_g_k = MI_g_Total * 0.3
qui gen MI_g_l = MI_g_Total * (1 - 0.3)
qui gen NI_g = OS_g_Total + MI_g_Total + CE_Total + NPI_Total
qui gen NI_n = OS_g_Total + MI_g_Total + CE_Total + NPI_Total - FKC_Total

//Capital share
qui gen KI = OS_g_Total + MI_g_k + NPI_Total
qui gen LI = CE_Total + MI_g_l
qui gen KI_net = KI - FKC_Total
qui gen K = KI / NI_g
qui gen K_net = KI_net / NI_n

//Special cases
qui replace KI = OS_g_Total + NPI_Total if countryorarea=="China"
qui replace K = ///
	(OS_g_Total + NPI_Total) / (OS_g_Total+CE_Total+NPI_Total) ///
	if countryorarea=="China"
qui replace K_net=(OS_g_Total+NPI_Total-FKC_Total)/ ///
	(OS_g_Total+CE_Total+NPI_Total-FKC_Total) if countryorarea=="China"
qui drop if missing(K)	

//FISIM adjustment
qui replace OS_g_SF = ///
	OS_g_SF - FISIM_Total if !missing(FISIM_Total)
qui replace OS_g_SFSnF = ///
	OS_g_SFSnF - FISIM_Total if !missing(FISIM_Total) ///
	& missing(OS_g_SnF) & !missing(OS_g_SFSnF)
qui rename FISIM_Total fisim
qui drop FISIM*

//Alternative division of MIXED Income
qui gen Kshare_corp = (OS_g_SnF + OS_g_SF) / ///
	(OS_g_SnF + CE_SnF + OS_g_SF + CE_SnF) 
qui gen MI_g_k_alt = MI_g_Total * Kshare_corp
qui gen KI_alt = OS_g_Total + MI_g_k_alt + NPI_Total
qui gen KI_alt_net = KI_alt - FKC_Total
qui gen K_alt = KI_alt / NI_g
qui gen K_alt_net = KI_alt_net / NI_n

//Phi (all sectors)
foreach i in `i_sector'{
	qui gen KI_`i'=OS_g_`i'+NPI_`i'
	if ("`i'"=="HH" | "`i'"=="HHnpish") {
		qui replace KI_`i'=OS_g_`i'+MI_g_k+NPI_`i' ///
			if countryorarea!="China" 
	}
	qui gen phi_g_`i'=KI_`i'/KI
	qui gen phi_n_`i'=(KI_`i'-FKC_`i')/KI_net
}
// if HH is HH+NPISH
qui replace phi_g_HH=phi_g_HHnpish ///
	if missing(phi_g_HH) & !missing(OS_g_HHnpish)
qui replace phi_n_HH=phi_n_HHnpish ///
	if missing(phi_n_HH) & !missing(OS_g_HHnpish) 
	
// if SF and SnF reported toghether
qui gen SFSnF_marker=1 if missing(phi_g_SnF) & !missing(OS_g_SFSnF)
qui replace phi_g_SnF=phi_g_SFSnF ///
	if missing(phi_g_SnF) & !missing(OS_g_SFSnF)
qui replace phi_g_SF=. ///
	if phi_g_SnF==phi_g_SFSnF & !missing(OS_g_SFSnF)
qui replace phi_n_SnF=phi_n_SFSnF ///
	if missing(phi_n_SnF) & !missing(OS_g_SFSnF) 	
	
//Test of consistency
//qui replace phi_g_SF=0 if !missing(phi_g_SFSnF) & !missing(phi_g_SF)
qui egen test1=rowtotal(phi_g_SF phi_g_SFL phi_g_SnF phi_g_HH phi_g_G)
qui replace test1=test1+phi_g_HHnpish if missing(phi_g_HH)
qui replace test1=round(test1, 0.05) 
qui gen test2=1 if test1==1
qui replace test2=0 if test1!=1
tab country test2
qui order countryorarea year series test1 test2 phi_g_HH ///
	phi_g_HHnpish phi_g_SFL phi_g_SF phi_g_SnF phi_g_SFSnF phi_g_G ///
	phi_g_Total, first 
qui keep if test1==1

//Phi w/ and w/o G
foreach gn in `grossnet' {
	qui gen phi_`gn'_corp = phi_`gn'_SF + phi_`gn'_SnF
	qui egen phi_`gn'_corp_2 = rowtotal(phi_`gn'_SF phi_`gn'_SnF)
	qui replace phi_`gn'_corp = phi_`gn'_corp_2 if SFSnF_marker==1
	qui gen phi_`gn'_hh=phi_`gn'_HH/(phi_`gn'_corp+phi_`gn'_HH)
	qui gen phi_`gn'_cp=phi_`gn'_corp/(phi_`gn'_corp+phi_`gn'_HH)
}

//Std. Country names
qui replace countryorarea="Czech Republic" if countryorarea=="Czechia"
qui kountry countryorarea, from(other) stuck marker
qui rename _ISO3N_ countryn
qui kountry countryn, from(iso3n) to(iso2c) geo(undet)
qui rename _ISO2C_ iso2
qui drop if MARKER==0
qui drop MARKER 
qui order countryorarea iso2 countryn, first
qui tostring series, gen(series_st)
qui gen country_series=iso2 + series_st

//SAVE n.1
tempfile save1st
qui save `save1st', replace

//Compare with Piketty & Zucman 
qui import excel "Data/PZ_Kshares.xlsx", ///
	sheet("Hoja1") firstrow clear	

qui reshape long K_PZ_ Ki_PZ_ , i(year) j(country) string
qui sort country year, stable
qui drop if missing(K_PZ)
qui kountry country, from(other) stuck marker
qui rename _ISO3N_ countryn
qui kountry countryn, from(iso3n) to(iso2c)
qui rename _ISO2C_ iso2
tempfile temp_PZ
qui replace Ki_PZ = Ki_PZ * 100
qui replace K_PZ = K_PZ * 100
qui save `temp_PZ', replace	

qui use `save1st', clear
qui merge m:1 iso2 year using `temp_PZ', ///
	keepusing(K_PZ_ Ki_PZ_) generate(_merge2)
tempfile save1stKKnet
qui save `save1stKKnet', replace
qui sort iso2 year	
drop if _merge2==1
qui replace K_n = K_net * 100
qui replace K_alt_net = K_alt_net * 100
qui label var  Ki_PZ_ "PZ2015 incl. Govt. interest"
qui label var  K_PZ_ "PZ2015 excl. Govt. interest"
qui label var K_n "Net Capital Income"

graph twoway (line K_PZ_ K_n K_alt_net year) ///
	if series==1000 & iso2!="AU", by(iso2) ///
	graphregion(color(white)) plotregion(lcolor(bluishgray)) scale(1.2) ///	
	xlabel(1980(10)2010, labsize(medium) grid labels) ///
	ylabel(0(10)30, labsize(medium) angle(horizontal) ///
	format(%2.0f) grid labels) ///
	scheme(s1color) subtitle(,fcolor(white) lcolor(bluishgray)) ///
	legend(label(1 "Piketty and Zucman (2014)") label(2 "Own estimates"))
qui graph export "figures_apdx/KperCtry(PZ).pdf", replace 

// III. PHI: BALANCED PANEL ----------------------------------------------------// 

// III. a) DATA ----------------------------------------------------------------//

//Prepare data
qui use `save1st', clear
qui drop if missing(K)
qui encode country_series, gen(ctry_id)
qui xtset ctry_id year 
qui order ctry_id countryorarea, first
qui xtdescribe

//Get balanced sub-panel
qui  keep if year >= 1995 & year <= 2016 & iso2!="US" 
qui  bysort country_series: egen anios=count(year) 
qui  keep if anios>=22
 *tab iso2 year
  
qui levelsof iso2, local(paises)
qui levelsof countryorarea, local(paises2)
 foreach p in `paises' {
	qui sum series if iso2=="`p'" 
	drop if iso2=="`p'" & series!=r(max)
 }
qui gen KI_hh = phi_g_HH * KI
qui gen KI_hh_n = phi_n_HH * KI_net
qui gen KI_corp = phi_g_corp * KI
qui gen KI_corp_n = phi_n_corp * KI_net

//Generate Net vars
qui gen KI_G_n=KI_G-FKC_G
qui gen KI_SFL_n=KI_SFL-FKC_SFL
qui gen OS_n_G=OS_g_G-FKC_G

//Keep most recent series by year
qui egen country_year=concat(iso2 year)
qui levelsof country_year, local(cyears)
foreach y in `cyears' {
	qui sum series if country_year=="`y'"
	qui drop if country_year=="`y'" & series!=r(max)
}

qui levelsof iso2, local(aux_bp)
tempfile randomname
qui save "`randomname'", replace
di "Balanced Panel"
xtdescribe 

//Get Exchange rates
qui levelsof iso2, local(ctries)
qui levelsof year, local(yrs)
qui import delimited "Data/UN/UNdata_xrates.csv" ///
	, encoding(ISO-8859-1)clear
qui replace countryorarea = ///
	subinstr(countryorarea, ", People's Republic of", "",.) 
qui replace countryorarea = ///
	subinstr(countryorarea, "Former ", "",.) 
qui replace countryorarea = ///
	subinstr(countryorarea, " of Great Britain and Northern Ireland", "",.) 
qui replace countryorarea = ///
	subinstr(countryorarea, " (Bolivarian Republic of)", "",.) 	

//Harmonize country names
qui kountry countryorarea, from(other) stuck marker
qui rename _ISO3N_ iso3
qui kountry iso3, from(iso3n) to(iso2c)
qui rename _ISO2C_ iso2
qui drop if MARKER==0
qui keep iso2 xrateama year xrateamanote

tempfile xrates_yr
qui save `xrates_yr', replace
qui merge m:1 iso2 year using `randomname'
qui format %15s xrateamanote
qui keep if _merge==3 

//Transform to market USD (yearly)
local toreplace_gross "KI KI_hh KI_corp KI_G KI_SFL NPI_G OS_g_G" 
local toreplace_net "KI_net KI_hh_n KI_corp_n KI_G_n KI_SFL_n OS_n_G"
local toreplace "`toreplace_gross' `toreplace_net'"
foreach t in `toreplace' {
	qui replace `t'=`t'/xrateama
}

tempfile randomname2
qui save "`randomname2'", replace

// III. b) GRAPHS BY COUNTRY---------------------------------------------------//

//Capital Shares

// Graphs per country (gross)
local isectors "hh corp G SFL"
foreach i in `isectors' {
	qui gen phi_`i' = KI_`i' / KI * 100
}	
qui label var phi_hh "Households"
qui label var phi_corp "Private Corporations"
qui label var phi_G "General Government"
qui gen phi_hh2 = phi_hh / (phi_hh + phi_corp) * 100
qui gen phi_corp2 = phi_corp / (phi_hh + phi_corp) * 100 
qui egen test10 = rowtotal(phi_hh phi_corp phi_G)
qui egen test20 = rowtotal(phi_hh phi_corp phi_G phi_SFL)
qui label var phi_hh2 "Households"
qui label var phi_corp2 "Private Corporations"

// Graphs per country (net)
local isectors "hh corp G SFL"
foreach i in `isectors' {
	qui gen phi_`i'_n=KI_`i'_n/KI_n*100
}	
qui label var phi_hh_n "Households"
qui label var phi_corp_n "Private Corporations"
qui label var phi_G_n "General Government"
qui gen phi_hh2_n=phi_hh_n/(phi_hh_n+phi_corp_n)*100
qui gen phi_corp2_n=phi_corp_n/(phi_hh_n+phi_corp_n)*100 
qui egen test10_n=rowtotal(phi_hh_n phi_corp_n phi_G_n)
qui egen test20_n=rowtotal(phi_hh_n phi_corp_n phi_G_n phi_SFL_n)
qui gen auxi_test20=1 if test20_n<101 & test20_n>99
qui label var phi_hh2_n "Households"
qui label var phi_corp2_n "Private Corporations"

//Get list of Countries
qui levelsof iso2, local(isos)

//Graph (with G, GROSS)
graph twoway (line phi_hh year, lcolor(edkblue)) ///
	(line phi_corp year, lcolor(maroon)) ///
	(line phi_G year, lcolor(sand)) ///
	,by(iso2) ytitle("Share of Total Gross Capital Income (%)") xtitle("") ///
	xlabel(1995(5)2015, labsize(small) angle(horizontal) grid labels) ///
	ylabel(-10(30)90, labsize(small) angle(horizontal) grid labels) ///
	yline(0, lcolor(black) lpattern(dot)) ///
	graphregion(color(white)) plotregion(lcolor(bluishgray)) scale(1.2) ///
	scheme(s1color) subtitle(,fcolor(white) lcolor(bluishgray))
qui graph export "figures_apdx/AllPhis_BpanelG.pdf", replace

//Graph also for each country
foreach c in `isos' {
	graph twoway (line phi_hh year, lcolor(edkblue)) ///
	(line phi_corp year, lcolor(maroon)) ///
	(line phi_G year, lcolor(sand)) if iso2 == "`c'" ///
	, ytitle("Share of Total Gross Capital Income (%)") xtitle("") ///
	xlabel(1995(5)2015, labsize(small) angle(horizontal) grid labels) ///
	ylabel(, labsize(small) angle(horizontal) grid labels) ///
	yline(0, lcolor(black) lpattern(dot)) ///
	graphregion(color(white)) plotregion(lcolor(bluishgray)) scale(1.2) ///
	scheme(s1color) subtitle(,fcolor(white) lcolor(bluishgray))
qui graph export "figures_apdx/AllPhis_G_`c'.pdf", replace
}

//Graph (w/o G, GROSS)
graph twoway (line phi_hh2 year, lcolor(edkblue)) ///
	(line phi_corp2 year, lcolor(maroon)) ///
	,by(iso2) ytitle("Share of Total Gross Capital Income (%)") xtitle("") ///
	xlabel(1995(5)2015, labsize(small) angle(horizontal) grid labels) ///
	ylabel(20(20)80, labsize(small) angle(horizontal) grid labels) ///
	graphregion(color(white)) plotregion(lcolor(bluishgray)) scale(1.2) ///
	scheme(s1color) subtitle(,fcolor(white) lcolor(bluishgray))
qui graph export "figures_apdx/AllPhis_BpanelnoG.pdf", replace

//Graph also for each country
foreach c in `isos' {
	graph twoway (line phi_hh2 year, lcolor(edkblue)) ///
	(line phi_corp2 year, lcolor(maroon)) if iso2 == "`c'" ///
	, ytitle("Share of Total Gross Capital Income (%)") xtitle("") ///
	xlabel(1995(5)2015, labsize(small) angle(horizontal) grid labels) ///
	ylabel(, labsize(small) angle(horizontal) grid labels) ///
	graphregion(color(white)) plotregion(lcolor(bluishgray)) scale(1.2) ///
	scheme(s1color) subtitle(,fcolor(white) lcolor(bluishgray))
qui graph export "figures_apdx/AllPhis_noG_`c'.pdf", replace
}

// III. b) AGGREGATE PICTURE (GROSS)-------------------------------------------//

tempfile tf_bpn
qui save `tf_bpn'

//Create KI_n
qui gen KI_n = NI_n * K_net

//Capital Shares
preserve 
		
	//Prepare variables
	qui replace K = K * 100
	qui replace K_net = K_net * 100
	qui replace K_alt = K_alt * 100

	//Graph for all countries
	graph twoway (line K year, lcolor(edkblue)) ///
		(line K_net year, lcolor(maroon)) ///
		, by(iso2) ytitle("Capital Income Share (%)") xtitle("") ///
		xlabel(1995(5)2015, labsize(medium) angle(horizontal) grid labels) ///
		ylabel(10(10)55, labsize(medium) angle(horizontal) grid labels) ///
		graphregion(color(white)) scale(1.2) legend(label(1 "Gross") ///
		label(2 "Net"))  ///
		scheme(s1color) subtitle(,fcolor(white) lcolor(bluishgray))
		qui graph export "figures/KKnetByCtry_BP.pdf", replace
	qui export excel countryorarea year K K_net countryorarea ///
		using "Tables/data-behind-figures.xlsx"	, ///
		firstrow(variables) sheet("FigureC.1") sheetreplace	

	//Temporary files	
	tempfile tf_aux1 tf_aux2 tf_aux3
	qui save `tf_aux1'
	
	//Merge with Bengtsson and Waldenstrom data
	qui import excel using "Data/Waldenstrom_Data.xlsx", clear ///
		sheet("Database") firstrow cellrange(A1:C2070)
	qui kountry Country, from(other) stuck
	qui rename (_ISO3N_ Year) (iso3 year)
	qui kountry iso3, from(iso3n) to(iso2c)
	qui rename _ISO2C_ iso2 
	qui save `tf_aux2'
	qui use `tf_aux1', clear 	
	qui merge 1:1 iso2 year using `tf_aux2', keep(1 3) nogenerate
	qui save `tf_aux2', replace
	
	//Merge with ILO data
	qui import delimited "Data/ilo-labour.csv", encoding(UTF-8) clear
	qui kountry ref_area, from(iso3c) to(iso2c)	
	qui gen K_ilo = 100 - obs_value 
	qui rename (_ISO2C_ time) (iso2 year)	
	qui drop if missing(iso2)
	qui save `tf_aux3'
	qui use `tf_aux2', clear
	qui merge 1:1 iso2 year using `tf_aux3', keep(1 3) nogenerate
	qui rename Grosscapitalshare K_BW
	
	//Merge with Piketty and Saez 
	qui merge m:1 iso2 year using `temp_PZ', ///
		keepusing(K_PZ_ Ki_PZ_) generate(_merge2)
	qui sort iso2 year	
	qui label var  Ki_PZ_ "PZ2015 incl. Govt. interest"
	qui label var  K_PZ_ "PZ2015 excl. Govt. interest"
	//qui label var K_n "Net Capital Income"
	
	//Graph everything
	graph twoway  (line K year) (line K_ilo year) ///
		(line K_BW year) if iso2 != "NO" & iso2 != "SE" & & iso2 != "CH" & ///
		!missing(K) ///
		, by(countryorarea) ytitle("Capital Share (%)") xtitle("") ///
		xlabel(1995(5)2015, labsize(small) angle(horizontal) grid labels) ///
		ylabel(30(10)50, labsize(small) angle(horizontal) grid labels) ///
		legend(label(1 "Own Estimate") label(2 "ILO Estimate") ///
		label(3 "Bengtsson and Waldenstrom")) ///
		graphregion(color(white)) plotregion(lcolor(bluishgray)) scale(1.2) ///
		scheme(s1color) subtitle(,fcolor(white) lcolor(bluishgray))
	qui graph export "figures/K_comparison.pdf", replace 
	qui export excel countryorarea year K K_ilo K_BW countryorarea ///
		using "Tables/data-behind-figures.xlsx"	, ///
		firstrow(variables) sheet("FigureA.1") sheetreplace
	
	//Compare Gross and Net estimates
	qui collapse (sum) NI_g NI_n LI KI_n, by (year)
	qui gen KI=NI_g-LI
	qui gen K= KI / NI_g * 100
	qui gen K_net= KI_n / NI_n * 100	
	
	//Graph
	graph twoway (line K year, lcolor(edkblue)) ///
		(line K_net year, lcolor(maroon)) if year >= 1995 ///
		, ytitle("Capital Income Share (%)") xtitle("") ///
		xlabel(1995(5)2015, labsize(small) angle(horizontal) grid labels) ///
		ylabel(0(10)50, labsize(small) angle(horizontal) grid labels) ///
		text(37 2013  "Gross", color(edkblue)) ///
		text(23 2013  "Net", color(maroon)) ///
		graphregion(color(white)) scale(1.2) legend(off)
	qui graph export "figures/KKnet_BP.pdf", replace

	//Save info	
	qui export excel year K K_net ///
		using "Tables/data-behind-figures.xlsx"	, ///
		firstrow(variables) sheet("Figure1") sheetreplace	
		
restore

//Collapse
qui collapse (sum) KI_hh KI_corp KI_G KI_SFL KI KI_n NI_n NI_g ///
	(mean) avgphi_g_HH_notG=phi_hh2 avgphi_g_corp_notG=phi_corp2 ///
	avgphi_g_hh=phi_hh avgphi_g_corp=phi_corp avgphi_g_G=phi_G ///	
	, by (year)	
local isectors "hh corp G SFL"
foreach i in `isectors' {
	qui gen phi_`i'=KI_`i'/KI*100
}	
qui label var phi_hh "Households"
qui label var phi_corp "Private Corporations"
qui label var phi_G "General Government"

//Phis
qui gen phi_hh2=phi_hh/(phi_hh+phi_corp)*100
qui gen phi_corp2=phi_corp/(phi_hh+phi_corp)*100 
qui gen avgphi_g_hh2_NG=avgphi_g_hh/(avgphi_g_hh+avgphi_g_corp)*100 
qui gen avgphi_g_corp2_NG=avgphi_g_corp/(avgphi_g_hh+avgphi_g_corp)*100 

qui egen test1=rowtotal(phi_hh phi_corp phi_G)
qui egen test2=rowtotal(phi_hh phi_corp phi_G phi_SFL)
qui label var phi_hh2 "Households"
qui label var phi_corp2 "Private Corporations"

//Graph (with G, GROSS)
graph twoway (line phi_hh year, lcolor(edkblue)) ///
	(line phi_corp year, lcolor(maroon)) ///
	(line phi_G year, lcolor(sand)) ///
	, yline(0, lcolor(black) lpattern(dot)) title(/*"Structure of Capital Income"*/) ///
	subtitle(/*"Balanced Panel, 1995-2014"*/) ///
	ytitle("Share of Total Capital Income (%)") xtitle("") ///
	xlabel(1995(5)2015, labsize(small) angle(horizontal) grid labels) ///
	ylabel(-10(20)60, labsize(small) angle(horizontal) grid labels) ///
	text(58 2005  "Household Sector", color(edkblue)) ///
	text(40 2005  "Private Corporations", color(maroon)) ///
	text(8 2005  "Public Sector", color(sand)) ///
	graphregion(color(white)) scale(1.2) legend(off)
qui graph export "figures/Phis.pdf", replace
qui export excel year phi_hh phi_corp phi_G using ///
	"Tables/data-behind-figures.xlsx", ///
	firstrow(variables) sheet("Figure2a") sheetreplace	

//Graph (without G, GROSS)
graph twoway (line phi_hh2 year, lcolor(edkblue)) ///
	(line phi_corp2 year, lcolor(maroon)) ///
	, title(/*"Structure of Capital Income, Excluding the Government"*/) ///
	subtitle(/*"Balanced Panel, 1995-2014"*/) ///
	ytitle("Share of Total Capital Income (%)") xtitle("") ///
	xlabel(1995(5)2015, labsize(small) angle(horizontal) grid labels) ///
	ylabel(40(5)60, labsize(small) angle(horizontal) grid labels) ///
	graphregion(color(white)) ///
	text(55 2006  "Household Sector", color(edkblue)) ///
	text(45 2006  "Private Corporations", color(maroon)) ///
	legend(off) scale(1.2)
qui graph export "figures/Phi_wo_G.pdf", replace
qui export excel year phi_hh2 phi_corp2 ///
	using "Tables/data-behind-figures.xlsx", ///
	firstrow(variables) sheet("Figure2b") sheetreplace		

//Average (with G, GROSS)
graph twoway (line avgphi_g_hh year, lcolor(edkblue)) ///
	(line avgphi_g_corp year, lcolor(maroon)) ///
	(line avgphi_g_G year, lcolor(sand)) ///
	, yline(0, lcolor(black) lpattern(dot)) title(/*"Structure of Capital Income"*/) ///
	subtitle(/*"Balanced Panel, 1995-2014"*/) ///
	ytitle("Average Share of Total Capital Income (%)") xtitle("") ///
	xlabel(1995(5)2015, labsize(small) angle(horizontal) grid labels) ///
	ylabel(0(20)60, labsize(small) angle(horizontal) grid labels) ///
	text(35 2005  "Household Sector", color(edkblue)) ///
	text(58 2005  "Private Corporations", color(maroon)) ///
	text(12 2005  "Public Sector", color(sand)) ///
	graphregion(color(white)) scale(1.2) legend(off)
qui graph export "figures/AvgPhisgross.pdf", replace

//Average (without G, GROSS) 
graph twoway (line avgphi_g_hh2_NG year, lcolor(edkblue)) ///
	(line avgphi_g_corp2_NG year, lcolor(maroon)) ///
	, yline(0, lcolor(black) lpattern(dot)) title(/*"Structure of Capital Income"*/) ///
	subtitle(/*"Balanced Panel, 1995-2014"*/) ///
	ytitle("Average Share of Total Capital Income (%)") xtitle("") ///
	xlabel(1995(5)2015, labsize(small) angle(horizontal) grid labels) ///
	ylabel(40(5)60, labsize(small) angle(horizontal) grid labels) ///
	text(48 2005  "Household Sector", color(edkblue)) ///
	text(53 2005  "Private Corporations", color(maroon)) ///
	graphregion(color(white)) scale(1.2) legend(off)
qui graph export "figures/AvgPhisgrossNotG.pdf", replace

//Save info
qui levelsof year, local(years)
foreach y in `years'{
	qui sum KI if year==`y'
	scal scal_KItot_`y'=r(max)
	qui sum phi_hh2 if year==`y'
	scal scal_phihh2_`y'=r(max)
	qui sum phi_hh if year==`y'
	scal scal_phiHH_`y'=r(max)
}

//ZOOM IN PHI G
qui use `randomname2', clear
qui encode countryorarea, gen(xtvar) 
qui xtset xtvar year 
qui levelsof country_series, local(ctries)
local idxes "OS_g NPI"

foreach i in `idxes' {
	qui gen `i'_G_ratio=`i'_G/KI
	qui gen `i'_index=.
	foreach c in `ctries' {
		qui sum `i'_G_ratio if country_series=="`c'" & year==1995
		qui replace `i'_index=(`i'_G_ratio)*100 if country_series=="`c'"
	}
}
qui encode iso2, gen(iso2_id)
qui xtset iso2_id year

//Structure of Phi_G
qui label var OS_g_G_ratio "Operating Surplus"
qui label var NPI_G_ratio "Net Property Income"
qui label var phi_g_G "Total"

graph twoway (line OS_g_G_ratio year) (line NPI_G_ratio year) ///
	(line phi_g_G year, lcolor(gray)) ///
	, by(iso2) ytitle("Share of National Gross Capital Income (%)") ///
	xtitle("") ///
	xlabel(1995(5)2015, labsize(small) angle(horizontal) grid labels) ///
	ylabel(-0.2(0.2)0.4, labsize(small) angle(horizontal) grid labels) ///
	 yline(0, lcolor(black) lpattern(dot)) graphregion(color(white)) ///
	plotregion(lcolor(bluishgray)) scale(1.2) ///
	scheme(s1color) subtitle(,fcolor(white) lcolor(bluishgray))
qui graph export "figures_apdx/Phis_G_comp.pdf", replace	

//Analyze structure 
qui use `randomname2', clear
qui gen KI_share=.
foreach y in `years' {
	qui replace KI_share=KI/scal_KItot_`y'*100 if year==`y'
}
//graph export "figures_apdx/Strucutre.pdf", replace

//On average  
qui collapse (mean) KI_share, by(countryorarea)
qui egen test=total(KI_share)
qui sort KI_share
qui format %9.1g KI_share
qui gen auxi=_n

//Table on average structure
qui gsort -KI_share	
qui gen cumshare=sum(KI_share)
qui format %9.1g cumshare
qui keep countryorarea KI_share cumshare

// III. c) AGGREGATE PICTURE (NET)-------------------------------------------//
qui use `tf_bpn', replace
qui bysort country_series: egen anios_n=count(year) if auxi_test20==1
qui keep if anios_n>=22
 
 //Graph (with G, NET)
graph twoway (line phi_hh_n year, lcolor(edkblue)) ///
	(line phi_corp_n year, lcolor(maroon)) ///
	(line phi_G_n year, lcolor(sand)) ///
	if auxi_test20==1 & iso2!="DE" & iso2!="AT" ///
	,by(iso2) ytitle("Share of Total Net Capital Income (%)") xtitle("") ///
	xlabel(1995(5)2015, labsize(small) angle(horizontal) grid labels) ///
	ylabel(-20(40)100, labsize(small) angle(horizontal) grid labels) ///
	yline(0, lcolor(black) lpattern(dot)) ///
	graphregion(color(white)) plotregion(lcolor(bluishgray)) scale(1.2) ///
	scheme(s1color) subtitle(,fcolor(white) lcolor(bluishgray))
qui graph export "figures_apdx/AllNetPhis_BpanelG.pdf", replace

//Graph (w/o G, NET)
graph twoway (line phi_hh2_n year, lcolor(edkblue)) ///
	(line phi_corp2_n year, lcolor(maroon)) ///
	if auxi_test20==1 & iso2!="DE" & iso2!="AT" ///
	,by(iso2) ytitle("Share of Total Net Capital Income (%)") xtitle("") ///
	xlabel(1995(5)2015, labsize(small) angle(horizontal) grid labels) ///
	ylabel(0(20)100, labsize(small) angle(horizontal) grid labels) ///
	graphregion(color(white)) plotregion(lcolor(bluishgray)) scale(1.2) ///
	scheme(s1color) subtitle(,fcolor(white) lcolor(bluishgray))
qui graph export "figures_apdx/AllNetPhis_BpanelnoG.pdf", replace
 
qui collapse (sum) KI_hh_n KI_corp_n KI_G_n KI_SFL_n KI_net ///
	(mean) avgphi_g_HH_notG=phi_hh2 avgphi_g_corp_notG=phi_corp2 ///
	avgphi_g_hh=phi_hh avgphi_g_corp=phi_corp avgphi_g_G=phi_G ///
	avgphi_n_HH_notG=phi_hh2_n avgphi_n_corp_notG=phi_corp2_n ///
	avgphi_n_hh=phi_hh_n avgphi_n_corp=phi_corp_n avgphi_n_G=phi_G_n ///
	, by (year)	
local isectors "hh corp G SFL"
foreach i in `isectors' {
	qui gen phi_`i'_n=KI_`i'_n/KI_net*100
}	

//Phis
qui gen phi_hh2_n=phi_hh_n/(phi_hh_n+phi_corp_n)*100
qui gen phi_corp2_n=phi_corp_n/(phi_hh_n+phi_corp_n)*100 
qui gen avgphi_n_hh2_NG=avgphi_n_hh/(avgphi_n_hh+avgphi_n_corp)*100 
qui gen avgphi_n_corp2_NG=avgphi_n_corp/(avgphi_n_hh+avgphi_n_corp)*100 
qui egen test1=rowtotal(phi_hh_n phi_corp_n phi_G_n)
qui egen test2=rowtotal(phi_hh_n phi_corp_n phi_G_n phi_SFL_n)

//Graph (with G, NET)
graph twoway (line phi_hh_n year, lcolor(edkblue)) ///
	(line phi_corp_n year, lcolor(maroon)) ///
	(line phi_G_n year, lcolor(sand)) ///
	, yline(0, lcolor(black) lpattern(dot)) title(/*"Structure of Capital Income"*/) ///
	subtitle(/*"Balanced Panel, 1995-2014"*/) ///
	ytitle("Share of Total Net Capital Income (%)") xtitle("") ///
	xlabel(1995(5)2015, labsize(small) angle(horizontal) grid labels) ///
	ylabel(-20(20)80, labsize(small) angle(horizontal) grid labels) ///
	text(60 2005  "Household Sector", color(edkblue)) ///
	text(46 2005  "Private Corporations", color(maroon)) ///
	text(-5 2005  "Public Sector", color(sand)) ///
	graphregion(color(white)) scale(1.2) legend(off)
qui graph export "figures/NetPhis.pdf", replace

//Graph (without G, NET)
graph twoway (line phi_hh2_n year, lcolor(edkblue)) ///
	(line phi_corp2_n year, lcolor(maroon)) ///
	, title(/*"Structure of Capital Income, Excluding the Government"*/) ///
	subtitle(/*"Balanced Panel, 1995-2014"*/) ///
	ytitle("Share of Total Net Capital Income (%)") xtitle("") ///
	xlabel(1995(5)2015, labsize(small) angle(horizontal) grid labels) ///
	ylabel(30(10)70, labsize(small) angle(horizontal) grid labels) ///
	graphregion(color(white)) ///
	text(60 2013  "Household Sector", color(edkblue)) ///
	text(40 2013  "Private Corporations", color(maroon)) ///
	legend(off) scale(1.2)
qui graph export "figures/NetPhi_wo_G.pdf", replace
	
//Average (with G, NET)
graph twoway (line avgphi_n_hh year, lcolor(edkblue)) ///
	(line avgphi_n_corp year, lcolor(maroon)) ///
	(line avgphi_n_G year, lcolor(sand)) ///
	, yline(0, lcolor(black) lpattern(dot)) title(/*"Structure of Capital Income"*/) ///
	subtitle(/*"Balanced Panel, 1995-2014"*/) ///
	ytitle("Average Share of Total Capital Income (%)") xtitle("") ///
	xlabel(1995(5)2015, labsize(small) angle(horizontal) grid labels) ///
	ylabel(0(20)60, labsize(small) angle(horizontal) grid labels) ///
	text(70 2005  "Household Sector", color(edkblue)) ///
	text(33 2005  "Private Corporations", color(maroon)) ///
	text(5 2005  "Public Sector", color(sand)) ///
	graphregion(color(white)) scale(1.2) legend(off)
qui graph export "figures/AvgPhisNetG.pdf", replace

//Average (without G, NET)
graph twoway (line avgphi_n_hh2_NG year, lcolor(edkblue)) ///
	(line avgphi_n_corp2_NG year, lcolor(maroon)) ///
	, yline(0, lcolor(black) lpattern(dot)) title(/*"Structure of Capital Income"*/) ///
	subtitle(/*"Balanced Panel, 1995-2014"*/) ///
	ytitle("Average Share of Total Capital Income (%)") xtitle("") ///
	xlabel(1995(5)2015, labsize(small) angle(horizontal) grid labels) ///
	ylabel(40(5)60, labsize(small) angle(horizontal) grid labels) ///
	text(53 2012  "Household Sector", color(edkblue)) ///
	text(47 2012  "Private Corporations", color(maroon)) ///
	graphregion(color(white)) scale(1.2) legend(off)
qui graph export "figures/AvgPhisNetNotG.pdf", replace	
	
//IV. LONG RUN SERIES --------------------------------------------------------//

//IV. a) GROSS ---------------------------------------------------------------//

qui use `save1st', clear
qui collapse (min) year_min=year (max) year_max=year, by (GEO country_series)
qui encode country_series, gen(ctry_id)
qui levelsof GEO, local(regions)

//Identify series starting before 1990
qui drop if year_min>=1990 & country_series!="JP300" ///
	& country_series!="IT300" & country_series!="US1000" 
qui levelsof country_series, local(cs_before1990)

//Draw those series
qui use `save1st', clear
qui gen marker=.
foreach s in `cs_before1990'{
	qui replace marker=1 if country_series=="`s'"
}
qui keep if marker==1 
qui encode country_series, gen(ctry_id)
qui xtset ctry_id year
qui replace phi_g_hh=phi_g_hh*100
qui replace phi_g_HH=phi_g_HH*100
qui replace phi_n_hh=phi_n_hh*100
qui replace phi_n_HH=phi_n_HH*100
qui replace phi_n_G=phi_n_G*100
qui replace phi_n_SFL=phi_n_SFL*100
qui replace phi_n_corp=phi_n_corp*100
qui replace phi_n_corp_2=phi_n_corp_2*100
qui replace phi_n_HHnpish=phi_n_HHnpish*100
qui replace phi_n_SFSnF=phi_n_SFSnF*100

qui gen Phi_BPanel_noG=.
qui gen Phi_BPanel_G=.
foreach y in `years' {
	qui replace Phi_BPanel_noG=scal_phihh2_`y' if year==`y'
	qui replace Phi_BPanel_G=scal_phiHH_`y' if year==`y'
}

local E_speaking "US GB CA AU"
foreach c in `E_speaking'{
	qui replace GEO="English Speaking" if iso2=="`c'"
}

qui replace GEO="Other European" if GEO=="Western Europe"
qui replace GEO="Other European" if iso2=="IT"
qui replace GEO="Scandinavian" if GEO=="Northern Europe"
qui replace GEO="Asia" if GEO=="Eastern Asia"
local todrop "NO200 FI200 FI300 AU200 AU100"
foreach d in `todrop' {
	qui drop if country_series=="`d'" 
} 
qui drop if year<1960 

qui sum phi_g_HH
local phimax=r(max)
qui sort countryorarea series year
local scalen=1.2

//JAPAN
local varslr "phi_g_hh phi_g_HH"
foreach v in `varslr' {
	if ("`v'"=="phi_g_hh") {
		local fname "noG"
	}
	if ("`v'"=="phi_g_HH") {
		local fname "G"	
	}

//JAPAN	
graph twoway (line `v' year if country_series=="JP100", lcolor(edkblue)) ///
	(line `v' year if country_series=="JP300", lcolor(ltblue))  ///
	(line Phi_BPanel_`fname' year if country_series=="CA1000", lcolor(gs10) lpattern(dash)) ///
	, xlabel(1960(10)2010, grid labels) graphregion(color(white)) ///
	ylabel(10(20)110, angle(horizontal)) /// 
	legend(off) ytitle("Household share of Capital Income (%)") xtitle("") ///
	text(53 1975  "Japan ('100' series)", color(edkblue)) ///
	text(32 1990  "Japan ('300' series)", color(ltblue)) scale(`scalen') 
qui graph export "figures/LR_JP_`fname'.pdf", replace
	
//SCANDINAVIAN
graph twoway (line `v' year if country_series=="FI500", lcolor(edkblue)) ///
	(line `v' year if country_series=="NO300", lcolor(maroon))  ///
	(line Phi_BPanel_`fname' year if country_series=="CA1000", lcolor(gs10) lpattern(dash)) ///
	, xlabel(1960(10)2010, grid labels) graphregion(color(white)) ///
	ylabel(10(20)110, angle(horizontal)) /// 
	legend(off) text(43 1970  "Finland", color(edkblue)) ///
	text(28 1970  "Norway", color(maroon)) ///
	ytitle("Household share of Capital Income (%)") xtitle("") scale(`scalen')
qui graph export "figures/LR_Scandi_`fname'.pdf", replace

//ENGLISH SPEAKING
graph twoway (line `v' year if country_series=="US100", lcolor(edkblue)) ///
	(line `v' year if country_series=="US1000", lcolor(ltblue))  ///
	(line `v' year if country_series=="AU300", lcolor(maroon))  ///
	(line `v' year if country_series=="CA1000", lcolor(sand))  ///
	(line Phi_BPanel_`fname' year if country_series=="CA1000", lcolor(gs10) lpattern(dash)) ///
	, xlabel(1960(10)2010, grid labels) graphregion(color(white)) ///
	ylabel(10(20)110, angle(horizontal)) /// 
	legend(off) text(64 2008  "United States", color(edkblue)) ///
	text(44 2008  "Australia", color(maroon)) ///
	text(28 2008  "Canada", color(sand)) ///
	ytitle("Household share of Capital Income (%)") xtitle("") scale(`scalen')
qui graph export "figures/LR_Eng_`fname'.pdf", replace
	
//OTHER EURO 
graph twoway (line `v' year if country_series=="IT200", lcolor(edkblue)) ///
	(line `v' year if country_series=="IT300", lcolor(ltblue)) ///
	(line `v' year if country_series=="FR300", lcolor(maroon))  ///
	(line `v' year if country_series=="NL300", lcolor(forest_green))  ///
	(line Phi_BPanel_`fname' year if country_series=="CA1000", lcolor(gs10) lpattern(dash)) ///
	, xlabel(1960(10)2010, grid labels) graphregion(color(white)) ///
	ylabel(10(20)110, angle(horizontal)) /// 
	legend(off) text(86 1972 "Italy ('200' series)", color(edkblue)) ///
	text(65 1998 "Italy ('300' series)", color(ltblue)) ///
	text(62 1972 "France", color(maroon)) ///
	text(35 1972 "Netherlands", color(forest_green)) ///
	ytitle("Household share of Capital Income (%)") xtitle("")	scale(`scalen')
qui graph export "figures/LR_EUR_`fname'.pdf", replace
	
qui export excel year country_series phi_g_HH ///
	using "Tables/data-behind-figures.xlsx"	, ///
	firstrow(variables) sheet("Figure4") sheetreplace
}

// b) NET ---------------------------------------------------------------------//

qui egen test10_n=rowtotal(phi_n_HH phi_n_corp phi_n_G)
qui egen test20_n=rowtotal(phi_n_HH phi_n_corp phi_n_G phi_n_SFL)
qui egen test30_n=rowtotal(phi_n_HHnpish phi_n_corp_2 phi_n_G)
qui egen test40_n=rowtotal(phi_n_HH phi_n_corp_2 phi_n_G)
qui gen auxi_test20=1 if test20_n<101 & test20_n>99

local varslr "phi_n_hh phi_n_HH"
foreach v in `varslr' {
	if ("`v'"=="phi_n_hh") {
		local fname "noG"
	}
	if ("`v'"=="phi_n_HH") {
		local fname "G"	
	}

//JAPAN
graph twoway (line `v' year if country_series=="JP100", lcolor(edkblue)) ///
	(line `v' year if country_series=="JP300", lcolor(ltblue))  ///
	(line Phi_BPanel_`fname' year if country_series=="CA1000", lcolor(gs10) ///
	lpattern(dash)) if auxi_test20==1 ///
	, xlabel(1960(10)2010, grid labels) graphregion(color(white)) ///
	ylabel(10(30)160, angle(horizontal)) /// 
	legend(off) ytitle("Household share of Capital Income (%)") xtitle("") ///
	text(60 1975  "Japan ('100' series)", color(edkblue)) ///
	text(35 2004  "Japan ('300' series)", color(ltblue)) scale(`scalen') 
qui graph export "figures/LRnet_JP_`fname'.pdf", replace
	
//SCANDINAVIAN
graph twoway (connected `v' year if country_series=="FI500", lcolor(edkblue) ///
	msize(small) mfcolor(white)) ///
	(line `v' year if country_series=="NO300", lcolor(maroon))  ///
	(line Phi_BPanel_`fname' year if country_series=="CA1000", lcolor(gs10) ///
	lpattern(dash)) if auxi_test20==1 & `v'>-100 & `v'<100 ///
	, xlabel(1960(10)2010, grid labels) graphregion(color(white)) ///
	ylabel(10(30)160, angle(horizontal)) /// 
	legend(off) text(60 1970  "Finland", color(edkblue)) ///
	text(28 1970  "Norway", color(maroon)) ///
	ytitle("Household share of Capital Income (%)") xtitle("") scale(`scalen')
qui graph export "figures/LRnet_Scandi_`fname'.pdf", replace
	
//OTHER EURO 
graph twoway (line `v' year if country_series=="IT200", lcolor(edkblue)) ///
	(line `v' year if country_series=="IT300", lcolor(ltblue)) ///
	(line `v' year if country_series=="FR300", lcolor(maroon)) ///
	(line `v' year if country_series=="NL300", lcolor(forest_green))  ///
	(line Phi_BPanel_`fname' year if country_series=="CA1000", lcolor(gs10) ///
	lpattern(dash)) if auxi_test20==1 ///
	, xlabel(1960(10)2010, grid labels) graphregion(color(white)) ///
	ylabel(10(30)160, angle(horizontal)) /// 
	legend(off) text(120 1972 "Italy ('200' series)", color(edkblue)) ///
	text(100 1995 "Italy ('300' series)", color(ltblue)) ///
	text(80 1972 "France", color(maroon)) ///
	text(35 1998 "Netherlands", color(forest_green)) ///
	ytitle("Household share of Capital Income (%)") xtitle("")	scale(`scalen')
qui graph export "figures/LRnet_EUR_`fname'.pdf", replace
}

//V. PHI: UNBALANCED PANEL ----------------------------------------------------//

qui use `save1st', clear
qui encode country_series, gen(country_series_id)
qui xtset country_series_id year
qui replace phi_g_hh=phi_g_hh*100
qui replace phi_g_HH=phi_g_HH*100
qui replace phi_g_corp=phi_g_corp*100
qui replace phi_g_G=phi_g_G*100
qui replace phi_g_cp=phi_g_cp*100
di "Unbalanced Panel"
qui xtdescribe

qui replace phi_n_hh=phi_n_hh*100
qui replace phi_n_HH=phi_n_HH*100
qui replace phi_n_corp=phi_n_corp*100
qui replace phi_n_G=phi_n_G*100
qui replace phi_n_cp=phi_n_cp*100

//US
qui gen Phi_BPanel_noG=.
qui gen Phi_BPanel_G=.
foreach y in `years' {
	qui replace Phi_BPanel_noG=scal_phihh2_`y' if year==`y'
	qui replace Phi_BPanel_G=scal_phiHH_`y' if year==`y'
}
 
graph twoway (line phi_g_HH year if country_series=="US100", lcolor(edkblue)) ///
	(line phi_g_HH year if country_series=="US1000", lcolor(ltblue)) ///
	(line phi_g_corp year if country_series=="US1000", lcolor(maroon)) ///
	(line phi_g_corp year if country_series=="US100", lcolor(orange_red)) ///
	(line phi_g_G year if country_series=="US1000", lcolor(sand)) ///
	(line phi_g_G year if country_series=="US100", lcolor(sandb)) ///
	if year>=1970 & year<=2016, ///
	ylabel(10(10)70, angle(horizontal)) ///
	xlabel(1970(5)2015, grid labels) ///
	ytitle("Share of Capital Income (%)") xtitle("") ///
	graphregion(color(white)) legend(label(1 "Households - SNA94") ///
	label(2 "Households - SNA08") label(3 "Corporations - SNA94") ///
	label(4 "Corporations - SNA08") label(5 "Public Sector - SNA94") ///
	label(6 "Public Sector - SNA08"))
qui graph export "figures_apdx/US1995-2015_G.pdf", replace
	
	graph twoway (line phi_g_hh year if country_series=="US100", lcolor(ltblue)) ///
	(line phi_g_hh year if country_series=="US1000", lcolor(edkblue)) ///
	(line phi_g_cp year if country_series=="US1000", lcolor(maroon)) ///
	(line phi_g_cp year if country_series=="US100", lcolor(orange_red)) ///
	if year>=1970 & year<=2016, ///
	ylabel(10(10)70, angle(horizontal)) ///
	xlabel(1970(5)2015, grid labels) ///
	ytitle("Share of Capital Income (%)") xtitle("") ///
	graphregion(color(white)) legend(label(1 "Households - SNA94") ///
	label(2 "Households - SNA08") label(3 "Corporations - SNA94") ///
	label(4 "Corporations - SNA08"))
qui graph export "figures_apdx/US1995-2015_noG.pdf", replace
	
//K trends
//xtline K if GEO=="South America" | GEO=="Central America"

//Phi trends 
qui sort countryorarea country_series year
qui egen timegroup=cut(year), at(1970(10)1999 2000(15)2015)
qui egen timegroup1995=cut(year), at(1995(20)2015)

//Manage series
qui egen country_tgroup=concat(iso2 timegroup)
qui levelsof country_tgroup, local(ctry_tg)
foreach c in `ctry_tg' {
	qui sum series if country_tgroup=="`c'"
	qui drop if country_tgroup=="`c'" & series!=r(max)
}

//Choose period
qui keep if timegroup1995==1995
qui egen nyears=count(year), by(country_series)
qui keep if nyears>=6

//identify ctries in bpanel
qui gen aux_bp=.
foreach c in `aux_bp' {
	replace aux_bp=1 if iso2=="`c'"
}
*di `aux_bp'
	
graph twoway (line phi_g_HH year, lcolor(edkblue)) ///
	(line phi_g_corp year, lcolor(maroon)) ///
	(line phi_g_G year, lcolor(sand)) ///
	if aux_bp!=1 & iso2!="US" ///
	, by(country_series) yline(0, lcolor(black) lpattern(dot)) ///
	ytitle("Share of Total Capital Income (%)") xtitle("") ///
	xlabel(1995(5)2015, labsize(small) angle(horizontal) grid labels) ///
	ylabel(-10(20)80, labsize(small) angle(horizontal) grid labels) ///
	graphregion(color(white)) scale(1.2) legend(off)
qui graph export "figures/Phis_oth.pdf", replace
	
graph twoway (line phi_n_HH year, lcolor(edkblue)) ///
	(line phi_n_corp year, lcolor(maroon)) ///
	(line phi_n_G year, lcolor(sand)) ///
	if aux_bp!=1 & iso2!="US" ///
	, by(country_series) yline(0, lcolor(black) lpattern(dot)) ///
	ytitle("Share of Total Capital Income (%)") xtitle("") ///
	xlabel(1995(5)2015, labsize(small) angle(horizontal) grid labels) ///
	ylabel(-10(20)80, labsize(small) angle(horizontal) grid labels) ///
	graphregion(color(white)) scale(1.2) legend(off)
qui graph export "figures/NetPhis_oth.pdf", replace
	
graph twoway (line phi_n_hh year, lcolor(edkblue)) ///
	(line phi_n_cp year, lcolor(maroon)) ///
	if aux_bp!=1 & iso2!="US" ///
	, by(country_series) yline(0, lcolor(black) lpattern(dot)) ///
	ytitle("Share of Total Capital Income (%)") xtitle("") ///
	xlabel(1995(5)2015, labsize(small) angle(horizontal) grid labels) ///
	ylabel(-10(20)80, labsize(small) angle(horizontal) grid labels) ///
	graphregion(color(white)) scale(1.2) legend(off)
qui graph export "figures/NetPhis_oth.pdf", replace	

//Reshape data
qui collapse (first) phi_1st_notG=phi_g_hh phi_1st_G=phi_g_HH ///
	phinet_1st_notG=phi_n_hh phinet_1st_G=phi_n_HH ///
	(last) phi_last_notG=phi_g_hh phi_last_G=phi_g_HH ///
	phinet_last_notG=phi_n_hh phinet_last_G=phi_n_HH ///
	(max) year_max=year (min) year_min=year, ///
	by (countryorarea iso2 series timegroup1995 /*timegroup*/)	
qui order countryorarea timegroup year_min year_max phi_1st_notG phi_last_notG

//New variables
qui gen nyears=year_max-year_min
qui keep if nyears>=6

//w/o G (GROSS)
graph twoway (scatter phi_last_notG phi_1st_notG if ///
	timegroup1995==1995 & phi_1st_notG>phi_last_notG ///
	, mlabel(iso2) mcolor(maroon) mlabangle(horizontal) ///
	mlabsize(vsmall) mlabposition(0) msymbol(i) ///
	msize(vsmall) mlabcolor(maroon) mlabgap(0.75)) ///
	(scatter phi_last_notG phi_1st_notG if timegroup1995==1995 ///
	& phi_1st_notG<phi_last_notG ///
	, mlabel(iso2) mcolor(edkblue) mlabangle(horizontal) ///
	mlabsize(vsmall) msize(vsmall) ///
	mlabposition(0) msymbol(i) ///
	mlabcolor(edkblue)) (function y=x, range(20 90) lcolor(gs10)) ///
	, ytitle("Last Observation (%)") xtitle("First Observation (%)") ///
	ylabel(20(20)80, angle(horizontal)) ///
	xlabel(20(20)80, grid labels)  graphregion(color(white)) legend(off) 
qui graph export "figures_apdx/Unbalanced1995-2015_notG.pdf", replace

//With G (GROSS)
graph twoway (scatter phi_last_G phi_1st_G ///
	if timegroup1995==1995 & phi_1st_G>phi_last_G ///
	, mlabel(iso2) mcolor(maroon) mlabangle(horizontal) ///
	mlabsize(vsmall) mlabposition(0) msymbol(i) ///
	msize(vsmall) mlabcolor(maroon) mlabgap(0.75)) ///
	(scatter phi_last_G phi_1st_G if timegroup1995==1995 ///
	& phi_1st_G<phi_last_G ///
	, mlabel(iso2) mcolor(edkblue) mlabangle(horizontal) ///
	mlabsize(vsmall) msize(vsmall) ///
	mlabposition(0) msymbol(i) ///
	mlabcolor(edkblue)) (function y=x, range(20 90) lcolor(gs10)) ///
	, ytitle("Last Observation (%)") xtitle("First Observation (%)") ///
	ylabel(20(20)80, angle(horizontal)) ///
	xlabel(20(20)80, grid labels)  graphregion(color(white)) legend(off)
qui graph export "figures/Unbalanced1995-2015_G.pdf", replace
qui export excel iso2 phi_1st_G phi_last_G ///
	using "Tables/data-behind-figures.xlsx", ///
	firstrow(variables) sheet("Figure3") sheetreplace	

//w/o G (NET)
graph twoway (scatter phinet_last_notG phinet_1st_notG if ///
	timegroup1995==1995 & phinet_1st_notG>phinet_last_notG ///
	, mlabel(iso2) mcolor(maroon) mlabangle(horizontal) mlabsize(vsmall) ///
	mlabposition(0) msymbol(i) msize(vsmall) mlabcolor(maroon) ///
	mlabgap(0.75)) (scatter phinet_last_notG phinet_1st_notG ///
	if timegroup1995==1995 & phinet_1st_notG<phinet_last_notG ///
	, mlabel(iso2) mcolor(edkblue) mlabangle(horizontal) ///
	mlabsize(vsmall) msize(vsmall) mlabposition(0) msymbol(i) ///
	mlabcolor(edkblue)) (function y=x, range(20 120) lcolor(gs10)) ///
	, ytitle("Last Observation (%)") xtitle("First Observation (%)") ///
	ylabel(20(20)120, angle(horizontal)) xlabel(20(20)125, grid labels) ///
	graphregion(color(white)) legend(off)
qui graph export "figures_apdx/UnbalancedNet1995-2015_notG.pdf", replace

//With G (NET)
graph twoway (scatter phinet_last_G phinet_1st_G ///
	if timegroup1995==1995 & phinet_1st_G>phinet_last_G ///
	& iso2!="HU" , mlabel(iso2) mcolor(maroon) mlabangle(horizontal) ///
	mlabsize(vsmall) mlabposition(0) msymbol(i) msize(vsmall) ///
	mlabcolor(maroon) mlabgap(0.75)) (scatter phinet_last_G phinet_1st_G ///
	if timegroup1995==1995 & phinet_1st_G<phinet_last_G ///
	, mlabel(iso2) mcolor(edkblue) mlabangle(horizontal) mlabsize(vsmall) ///
	msize(vsmall) mlabposition(0) msymbol(i) ///
	mlabcolor(edkblue)) (function y=x, range(20 120) lcolor(gs10)) ///
	, ytitle("Last Observation (%)") xtitle("First Observation (%)") ///
	ylabel(20(20)120, angle(horizontal)) ///
	xlabel(20(20)125, grid labels)  graphregion(color(white)) legend(off)
qui graph export "figures/UnbalancedNet1995-2015_G.pdf", replace

//Display results
local Gornot "notG G"
foreach g in `Gornot' {
	qui count if phi_1st_`g'>phi_last_`g' & !missing(timegroup1995)
	local decr`g'=r(N)
	qui count if phi_1st_`g'<phi_last_`g' & !missing(timegroup1995)
	local incr`g'=r(N)
	local decr_pct`g'=`decr`g''/(`incr`g''+`decr`g'')*100
	qui count if phinet_1st_`g'>phinet_last_`g' & !missing(timegroup1995)
	local netdecr`g'=r(N)
	qui count if phinet_1st_`g'<phinet_last_`g' & !missing(timegroup1995)
	local netincr`g'=r(N)
	local netdecr_pct`g'=`netdecr`g''/(`netincr`g''+`netdecr`g'')*100
	if ("`g'"=="G"){
		di "Series including the Government:"
	}
	if ("`g'"=="notG"){
		di "Series excluding the Government:"
	}
	di "GROSS: `decr`g'' Decreased, `incr`g'' Increased, thus: `decr_pct`g''% of cases decrease between 1995-2015 (min. 6 obs.)" 
	di "NET: `netdecr`g'' Decreased, `netincr`g'' Increased, thus: `netdecr_pct`g''% of cases decrease between 1995-2015 (min. 6 obs.)" 
}

//Save for later
tempfile UNDATA
qui save `UNDATA' ,replace

*----------------------------------------------------------------------------*
* LIS-DATA																	 *
*----------------------------------------------------------------------------*

//Prepare to Handle old currencies in UNDATA	
qui import excel "Data/legacy-currency.xlsx", ///
	sheet("factors") firstrow clear	
qui gen iso2=substr(LegacyOldCurrency,1,2)
qui gen xrate=substr(ConversionfromEUR,8,8)	
qui destring xrate, replace
qui gen obs_yr=year(Obsolete)
qui keep iso2 xrate obs_yr
tempfile xrates_legacy 
qui save `xrates_legacy',replace

//Prepare lissy's currency-labels
qui import excel "Data/labels.xlsx" , sheet("Hoja1") firstrow clear
qui rename currency currency_lis	
tempfile curr_labels
qui save `curr_labels', replace

//Bring main dataset and define waves
qui import excel "Data/ccyy2.xlsx", ///
	sheet("Hoja1") firstrow clear	
qui gen iso2=substr(ccyy,1,2)
qui gen year=substr(ccyy,3,2)
qui destring year mean_toti, replace
qui drop if missing(mean_toti)
qui replace year=year+1900 if year>=50
qui replace year=year+2000 if year<50
qui replace iso2=strupper(iso2)
qui replace iso2="GB" if iso2=="UK"
qui egen ctry_year=concat(iso2 year)

//Compare Kshares btw datasets 
preserve
	qui gen K_svy = (tot_K + tot_S * 0.3) / tot_inc * 100
	qui gen L_svy = (tot_L - tot_S * 0.3) / tot_inc * 100
	qui merge 1:m iso2 year using `save1st', ///
		keepusing(K K_net country_series phi_g_HH phi_n_HH)
	qui keep if _merge==3
	qui gen K_alt = K * phi_g_HH / (K * phi_g_HH + (1 - K)) * 100
	qui gen K_altnet = K_net * phi_n_HH / (K_net * phi_n_HH + (1 - K_net))*100
	qui replace K=K*100
	qui gen K_n=K_net*100
	qui gen series=substr(country_series,3,.)
	destring series, replace
	qui levelsof ctry_year, local(cyears)
	foreach y in `cyears' {
		qui sum series if ctry_year=="`y'"
		qui drop if ctry_year=="`y'" & series!=r(max)
	}

	//GROSS
	graph twoway (scatter K_svy K, mfcolor(none) msize(small)) ///
		(function y=x, range(0 60) lcolor(gs10)) if iso2!="CL" & iso2!="MX" /// 
		,xlabel(0(10)60, labsize(small) angle(horizontal) grid labels) ///
		ylabel(0(10)60, labsize(small) angle(horizontal) grid labels) ///
		ytitle("Survey's Figure (%)") xtitle("National Accounts' Figure (%)") ///
		legend(off) graphregion(color(white)) scale(1.2)
	qui graph export "figures/KK.pdf", replace 
		
	graph twoway (scatter K_svy K_alt, mfcolor(none) msize(small)) ///
		(function y=x, range(0 60) lcolor(gs10)) if iso2!="CL" & iso2!="MX" /// 
		,xlabel(0(10)60, labsize(small) angle(horizontal) grid labels) ///
		ylabel(0(10)60, labsize(small) angle(horizontal) grid labels) ///
		ytitle("Survey's Figure (%)") xtitle("National Accounts' Figure (%)") ///
		legend(off) graphregion(color(white)) scale(1.2)	
	qui graph export "figures/KKalt.pdf", replace 
		
	//NET	
	graph twoway (scatter K_svy K_n, mfcolor(none) msize(small)) ///
		(function y=x, range(0 60) lcolor(gs10)) if iso2!="CL" & iso2!="MX" /// 
		,xlabel(0(10)60, labsize(small) angle(horizontal) grid labels) ///
		ylabel(0(10)60, labsize(small) angle(horizontal) grid labels) ///
		ytitle("Survey's Figure (%)") xtitle("National Accounts' Figure (%)") ///
		legend(off) graphregion(color(white)) scale(1.2)
	qui graph export "figures/KKnet.pdf", replace 	

	graph twoway (scatter K_svy K_altnet, mfcolor(none) msize(small)) ///
		(function y=x, range(0 60) lcolor(gs10)) if iso2!="CL" & iso2!="MX" /// 
		,xlabel(0(10)60, labsize(small) angle(horizontal) grid labels) ///
		ylabel(0(10)60, labsize(small) angle(horizontal) grid labels) ///
		ytitle("Survey's Figure (%)") xtitle("National Accounts' Figure (%)") ///
		legend(off) graphregion(color(white)) scale(1.2)	
	qui graph export "figures/KKaltnet.pdf", replace 

	qui sort iso2 year	
	graph twoway (line K K_alt K_n year), by(iso2)	///
		graphregion(color(white)) plotregion(lcolor(bluishgray)) scale(1.2) ///
		scheme(s1color) subtitle(,fcolor(white) lcolor(bluishgray))
	qui graph export "figures_apdx/KperCtry.pdf", replace 

	levelsof iso2, separate(,)
	codebook iso2
	qui count if !missing(K, K_svy)

restore

//
qui egen wave=cut(year), ///
	at(1967, 1979, 1983, 1988, 1993, 1998, 2003, 2006, 2009, 2012, 2015, 2017) ///
	icodes
qui egen wave_yr=cut(year), ///
	at(1967, 1979, 1983, 1988, 1993, 1998, 2003, 2006, 2009, 2012, 2015, 2017) 

//Drop AT years without data 
qui drop if ccyy=="at94" | ccyy=="at95"

//Keep 1 year per wave 
qui egen year_frq=count(year), by(year) 
qui gen wave_pop_yr=.
qui levelsof wave, local(waves)
foreach w in `waves'{
	qui sum year_frq if wave==`w'
	qui sum year if wave==`w' & year_frq==r(max)
	qui replace wave_pop_yr=r(max) if wave==`w'
}
qui gen dist_to_popyear=abs(wave_pop_yr-year)
qui egen ctry_wave=concat(iso2 wave)
qui levelsof ctry_wave, local(ctry_waves)
foreach cw in `ctry_waves'{
	qui sum dist_to_popyear if ctry_wave=="`cw'"
	qui drop if ctry_wave=="`cw'" & dist_to_popyear!=r(min) 
}
qui egen test1=count(year), by(ctry_wave)
foreach cw in `ctry_waves'{
	qui sum year if ctry_wave=="`cw'" & test1>1
	qui drop if year!=r(max) & ctry_wave=="`cw'" & test1>1
}

//declare panel
qui drop if missing(wave)
qui encode iso2, gen(ctry_id)
qui xtset ctry_id wave
qui xtdescribe, patterns(20) 

//Select balanced panel
qui drop if tot_inc==0
qui gen aux1=0
qui replace aux1=1 if wave>=4 & wave<=9
qui egen test2=sum(aux1) if !missing(aux1) ,by(iso2)
qui gen aux_bp=0
qui replace aux_bp=1 if test2==6 & wave>=4 & wave<=9 
qui replace aux_bp=1 if iso2=="US"
qui replace aux_bp=0 if inlist(iso2, "ES", "HU")
//qui keep if aux_bp==1

//Allow NL and HU to merge data with the closest year (for surveys in 1994 & 1993)
preserve
	qui use `save1st', clear 
	qui replace year=1993 if iso2=="NL" & year==1995
	cap qui replace year=1994 if iso2=="HU" & year==1995
	tempfile save2nd
	qui save `save2nd', replace   
restore 

//Merge with unbalanced data from UN
qui merge 1:m iso2 year using `save2nd', ///
	keepusing(LI NI_g NI_n country_series phi_g_HH phi_n_HH K K_net currency_sna)
qui drop if _merge==2 | _merge==1
qui sort iso2 country_series year
qui destring tot_L tot_K tot_S t10_L t10_K t10_S t1_L t1_K t1_S defl ///
	totw mean_toti, replace

//Keep most recent series by year
qui gen series=substr(country_series,3,.)
qui destring series, replace
qui levelsof ctry_year, local(cyears)
foreach y in `cyears' {
	qui sum series if ctry_year=="`y'"
	qui drop if ctry_year=="`y'" & series!=r(max)
}

//Drop Countries with insufficient SNA
qui egen aux_bp2=count(K) if aux_bp==1, by(iso2) 

//Merge with lissy currency-labels
qui merge m:1 ccyy using `curr_labels' , generate(_merge2)

//Merge with legacy-xrates data (transform to EUR)
qui merge m:1 iso2 using `xrates_legacy', generate(_merge3)
local varstoreplace ///
	"tot_inc tot_L tot_K tot_S b50_L b50_K b50_S m40_L m40_K m40_S t10_L t10_K t10_S t1_L t1_K t1_S mean_toti"
foreach v in `varstoreplace' {
	qui replace `v'=`v'/xrate if year<obs_yr & !missing(obs_yr) ///
	& currency_lis!="[978]EUR - Euro" 
}

//Merge with xrates (yearly) data, to USD
qui merge m:m iso2 year using `xrates_yr', generate(_merge4)
qui keep if _merge4==3

//Transform to market USD (yearly)
local toreplace ///
	"NI_g NI_n tot_inc tot_K tot_S tot_L LI b50_L b50_K b50_S m40_L m40_K m40_S t10_L t10_K t10_S t1_L t1_K t1_S "
foreach t in `toreplace' {
	qui replace `t'=`t'/xrateama
}

//Create variables
qui gen KI_svy=(tot_K+0.3*tot_S) 
qui gen LI_svy=(tot_L-0.3*tot_S) 

qui gen KI_HH=phi_g_HH*K*NI_g
qui gen ki_h_svy=KI_svy/NI_g
qui gen ki_h_na=K*phi_g_HH
qui gen li_svy=LI_svy/NI_g
qui gen li_na=LI/NI_g

qui gen LI_n=(1-K_net)*NI_n
qui gen KI_HH_n=phi_n_HH*K_net*NI_n
qui gen ki_h_svy_n=KI_svy/NI_n
qui gen ki_h_na_n=K_net*phi_n_HH
qui gen li_svy_n=LI_svy/NI_n
qui gen li_na_n=LI_n/NI_n

//aqui se puede hacer directamente un test usando 

//EPSILON
qui gen epsiK=KI_svy/KI_HH*100
qui gen epsiL=LI_svy/LI*100
qui gen ratio=epsiK/epsiL*100

qui gen epsiKnet=KI_svy/KI_HH_n*100
qui gen epsiLnet=LI_svy/LI_n*100
qui gen ratio_net=epsiKnet/epsiLnet*100
qui sort iso2 year,stable

//Clean
qui drop _merge*
qui drop if missing(ratio)
qui kountry iso2, from(iso2c) to(iso3n) geo(undet)
//drop if series!=1000

qui sort iso2 year
qui label var epsiK "Gross Capital Income ({&epsilon}{sub:K})"
qui label var epsiL "Labour Income ({&epsilon}{sub:L})"
qui label var ratio "{&epsilon}{sub:K}/{&epsilon}{sub:L}"
qui label var epsiKnet "Net Capital Income ({&epsilon}{sub:K})"
qui label var epsiLnet "Labour Income ({&epsilon}{sub:L})"
qui label var ratio_net "{&epsilon}{sub:K}/{&epsilon}{sub:L}"

//export for comparison with oecd data 
qui export excel ///
	using "Tables/data-behind-figures.xlsx"	, ///
	firstrow(variables) sheet("oecd_comp") sheetreplace

//GROSS
graph twoway (line epsiK wave_pop_yr, lcolor(edkblue)) ///
	(line epsiL wave_pop_yr, lcolor(maroon)) ///
	(line ratio  wave_pop_yr, lcolor(gs10)) ///
	if iso2!="US" & aux_bp==1 & aux_bp2==6 ///
	, by(iso2) ytitle("Share of Total Factor Income Captured (%)") xtitle("") ///
	xlabel(1995(5)2015, labsize(small) angle(horizontal) grid labels) ///
	ylabel(0(20)100, labsize(small) angle(horizontal) grid labels)  ///
	graphregion(color(white)) plotregion(lcolor(bluishgray)) scale(1.2) ///
	scheme(s1color) subtitle(,fcolor(white) lcolor(bluishgray))
qui graph export "figures_apdx/EpsiByCtry.pdf", replace 
	
//Graph countries individually
qui levelsof iso2 if aux_bp==1 & aux_bp2==6, local(isos)
foreach c in `isos' {
	graph twoway (line epsiK wave_pop_yr, lcolor(edkblue)) ///
		(line epsiL wave_pop_yr, lcolor(maroon)) ///
		(line ratio  wave_pop_yr, lcolor(gs10)) ///
		if iso2 == "`c'" & aux_bp==1 & aux_bp2==6 ///
		, ytitle("Share of Tot. Factor Inc. Captured (%)") xtitle("") ///
		xlabel(1995(5)2015, labsize(small) angle(horizontal) grid labels) ///
		ylabel(, labsize(small) angle(horizontal) grid labels)  ///
		graphregion(color(white)) plotregion(lcolor(bluishgray)) scale(1.2) ///
		scheme(s1color) subtitle(,fcolor(white) lcolor(bluishgray))
	qui graph export "figures_apdx/Epsi_`c'.pdf", replace 
}	

//NET
graph twoway (line epsiKnet wave_pop_yr, lcolor(edkblue)) ///
	(line epsiLnet wave_pop_yr, lcolor(maroon)) ///
	(line ratio_net  wave_pop_yr, lcolor(gs10)) ///
	if iso2!="US" & iso2!="DK" & aux_bp==1 & aux_bp2==6 ///
	, by(iso2) ytitle("Share of Total Factor Income Captured (%)") xtitle("") ///
	xlabel(1995(5)2015, labsize(small) angle(horizontal) grid labels) ///
	ylabel(0(20)120, labsize(small) angle(horizontal) grid labels)  ///
	graphregion(color(white)) plotregion(lcolor(bluishgray)) scale(1.2) ///
	scheme(s1color) subtitle(,fcolor(white) lcolor(bluishgray))
qui graph export "figures_apdx/EpsiNetByCtry.pdf", replace 

graph twoway (line epsiKnet wave_pop_yr, lcolor(edkblue)) ///
	(line epsiLnet wave_pop_yr, lcolor(maroon)) ///
	(line ratio_net  wave_pop_yr, lcolor(gs10)) ///
	if iso2!="US" & iso2=="DK" & aux_bp==1 & aux_bp2==6 ///
	, by(iso2) ytitle("Share of Total Factor Income Captured (%)") xtitle("") ///
	xlabel(1995(5)2015, labsize(small) angle(horizontal) grid labels) ///
	ylabel(60(20)180, labsize(small) angle(horizontal) grid labels)  ///
	graphregion(color(white)) plotregion(lcolor(bluishgray)) scale(1.2) ///
	scheme(s1color) subtitle(,fcolor(white) lcolor(bluishgray))
qui graph export "figures_apdx/EpsiNetByCtryDK.pdf", replace 	

//Historical Series	
qui gen histo=.
qui replace histo=1 if iso2=="US" | iso2=="CA" | iso2=="FI" | ///
	iso2=="FR" | iso2=="IT" | iso2=="NL"	

//LR Gross
graph twoway (line epsiK wave_pop_yr, lcolor(edkblue)) ///
	(line epsiL wave_pop_yr, lcolor(maroon)) ///
	(line ratio  wave_pop_yr, lcolor(gs10)) ///
	if histo==1 ///
	, by(iso2) ytitle("Share of Total Factor Income Captured (%)") xtitle("") ///
	xlabel(1975(10)2015, labsize(small) angle(horizontal) grid labels) ///
	ylabel(0(20)80, labsize(small) angle(horizontal) grid labels)  ///
	graphregion(color(white)) plotregion(lcolor(bluishgray)) scale(1.2) ///
	scheme(s1color) subtitle(,fcolor(white) lcolor(bluishgray))
qui graph export "figures_apdx/EpsiByCtry_histo.pdf", replace   
	
//LR Net
graph twoway (line epsiKnet wave_pop_yr, lcolor(edkblue)) ///
	(line epsiLnet wave_pop_yr, lcolor(maroon)) ///
	(line ratio_net  wave_pop_yr, lcolor(gs10)) ///
	if histo==1 ///
	, by(iso2) ytitle("Share of Total Factor Income Captured (%)") xtitle("") ///
	xlabel(1975(10)2015, labsize(small) angle(horizontal) grid labels) ///
	ylabel(0(20)100, labsize(small) angle(horizontal) grid labels)  ///
	graphregion(color(white)) plotregion(lcolor(bluishgray)) scale(1.2) ///
	scheme(s1color) subtitle(,fcolor(white) lcolor(bluishgray))
qui graph export "figures_apdx/NetEpsiByCtry_histo.pdf", replace   	

//Latin America?	
qui gen latam=.
qui replace latam=1 if iso2=="CL" | iso2=="MX" 
graph twoway (line epsiK wave_pop_yr, lcolor(edkblue)) ///
	(line epsiL wave_pop_yr, lcolor(maroon)) ///
	(line ratio  wave_pop_yr, lcolor(gs10)) ///
	if latam==1 ///
	, by(iso2) ytitle("Share of Total Factor Income Captured (%)") xtitle("") ///
	xlabel(1995(5)2015, labsize(small) angle(horizontal) grid labels) ///
	ylabel(0(20)80, labsize(small) angle(horizontal) grid labels)  ///
	graphregion(color(white)) plotregion(lcolor(bluishgray)) scale(1.2) ///
	scheme(s1color) subtitle(,fcolor(white) lcolor(bluishgray))
qui graph export "figures_apdx/EpsiByCtry_latam.pdf", replace   	

//Gross/Net definition
tempvar aux1
qui gen `aux1' = ", "
qui egen income_def = concat(grossnet `aux1' grossnet2)
qui tab iso2 income_def

//GAMMA
qui gen gamma = phi_g_HH * ratio 
qui gen gamma_net = phi_n_HH * ratio_net 

//Percentages
preserve
	foreach v in "K" "K_net" "phi_g_HH" {
		qui replace `v' = `v' * 100
	}
	
	//By country
	graph twoway (line gamma wave_pop_yr) ///
		(line K wave_pop_yr) if iso2!="US" & aux_bp==1 & aux_bp2==6  ///
		, by(iso2) ///
		xlabel(1995(5)2015, labsize(small) angle(horizontal) grid labels) ///
		ylabel(10(10)40, labsize(small) angle(horizontal) grid labels)  ///
		graphregion(color(white)) plotregion(lcolor(bluishgray)) scale(1.2) ///
		ytitle("(%)") xtitle("") legend(label(1 "{&gamma}") label(2 "Gross Capital Share")) ///
		scheme(s1color) subtitle(,fcolor(white) lcolor(bluishgray))
	qui graph export "figures_apdx/KGammaByCtry.pdf", replace 

	
	//Graph countries individually
	qui levelsof iso2 if iso2!="US" & aux_bp==1 & aux_bp2==6, local(isos)
	foreach c in `isos' {
	graph twoway (line gamma wave_pop_yr) ///
		(line K wave_pop_yr) if iso2!="US" & aux_bp==1 & aux_bp2==6  ///
		& iso2 == "`c'" ///
		, xlabel(1995(5)2015, labsize(small) angle(horizontal) grid labels) ///
		ylabel(, labsize(small) angle(horizontal) grid labels)  ///
		graphregion(color(white)) plotregion(lcolor(bluishgray)) scale(1.2) ///
		ytitle("(%)") xtitle("") legend(label(1 "{&gamma}") label(2 "Gross Capital Share")) ///
		scheme(s1color) subtitle(,fcolor(white) lcolor(bluishgray))
	qui graph export "figures_apdx/KGamma_`c'.pdf", replace 
	}
	
	//Decomposition, by country
	graph twoway (line gamma wave_pop_yr) ///
		(line phi_g_HH wave_pop_yr) ///
		(line ratio wave_pop_yr) ///
		if iso2!="US" & aux_bp==1 & aux_bp2==6  ///
		, by(iso2) ///
		xlabel(1995(5)2015, labsize(small) angle(horizontal) grid labels) ///
		ylabel(0(20)80, labsize(small) angle(horizontal) grid labels)  ///
		graphregion(color(white)) plotregion(lcolor(bluishgray)) scale(1.2) ///
		ytitle("(%)") xtitle("") legend(label(1 "{&gamma}") label(2 "{&Phi}{subscript:h}")) ///
		scheme(s1color) subtitle(,fcolor(white) lcolor(bluishgray))
		qui graph export "figures_apdx/DecGammaByCtry.pdf", replace 
	qui export excel iso2 wave_pop_yr gamma phi_g_HH ratio  ///
		using "Tables/data-behind-figures.xlsx"	, ///
		firstrow(variables) sheet("FigureD.7") sheetreplace	
		
	//Individual country decomposition
	foreach c in `isos' {
		graph twoway (line gamma wave_pop_yr) ///
			(line phi_g_HH wave_pop_yr) ///
			(line ratio wave_pop_yr) ///
			if iso2!="US" & aux_bp==1 & aux_bp2==6  ///
			& iso2 == "`c'" ///
			,xlabel(1995(5)2015, labsize(small) angle(horizontal) ///
			grid labels) ylabel(, labsize(small) angle(horizontal) ///
			grid labels)  graphregion(color(white)) ///
			plotregion(lcolor(bluishgray)) scale(1.2) ///
			ytitle("(%)") xtitle("") legend(label(1 "{&gamma}") ///
			label(2 "{&Phi}{subscript:h}")) ///
			scheme(s1color) subtitle(,fcolor(white) lcolor(bluishgray))
			qui graph export "figures_apdx/DecGamma_`c'.pdf", replace 
	}
	
	//Net value, by country
	graph twoway (line gamma_net wave_pop_yr) ///
		(line K_net wave_pop_yr) if iso2!="US" & aux_bp==1 & aux_bp2==6  ///
		, by(iso2) xlabel(1995(5)2015, labsize(small) angle(horizontal) ///
		grid labels) ylabel(10(10)60, labsize(small) angle(horizontal) ///
		grid labels)  graphregion(color(white)) ///
		plotregion(lcolor(bluishgray)) scale(1.2) ///
		ytitle("(%)") xtitle("") ///
		scheme(s1color) subtitle(,fcolor(white) lcolor(bluishgray))
	qui graph export "figures_apdx/NetKGammaByCtry.pdf", replace 
restore

//S_K and S_L
local group "b50 m40 t10 t1"
foreach g in `group'{
	qui gen S`g'_K = (`g'_K + `g'_S * 0.3) / (tot_K + tot_S * 0.3)
	qui gen S`g'_L = (`g'_L - `g'_S * 0.3) / (tot_L - tot_S * 0.3)
	qui gen S`g' = (`g'_L + `g'_K) / (tot_L + tot_K)
	qui gen Dif_`g' = S`g'_K - S`g'_L
}

preserve
	local toch "St1_K St1_L St1"
	foreach v in `toch' {
		qui replace `v' = `v' * 100
	}
	graph twoway (line St1_K wave_pop_yr, lcolor(edkblue)) ///
		(line St1_L wave_pop_yr, lcolor(maroon)) ///
		(line St1 wave_pop_yr, lcolor(gray) lpattern(dash)) ///
		if iso2!="US" & aux_bp==1 & aux_bp2==6  ///
		, by(iso2) ///
		xlabel(1995(5)2015, labsize(small) angle(horizontal) grid labels) ///
		ylabel(0(10)40, labsize(small) angle(horizontal) grid labels)  ///
		graphregion(color(white)) plotregion(lcolor(bluishgray)) scale(1.2) ///
		ytitle("Top 1%'s Factor Income Share") xtitle("") ///
		scheme(s1color) subtitle(,fcolor(white) lcolor(bluishgray))
	qui graph export "figures_apdx/SqByCtry.pdf", replace 	
restore	

preserve
	local toch "St10_K St10_L St10"
	foreach v in `toch' {
	qui replace `v' = `v' * 100
	}
	
	//Graph all together
	graph twoway (line St10_K wave_pop_yr, lcolor(edkblue)) ///
		(line St10_L wave_pop_yr, lcolor(maroon)) ///
		(line St10 wave_pop_yr, lcolor(gray) lpattern(dash)) ///
		if iso2!="US" & aux_bp==1 & aux_bp2==6  ///
		, by(iso2) ///
		xlabel(1995(5)2015, labsize(small) angle(horizontal) grid labels) ///
		ylabel(20(10)70, labsize(small) angle(horizontal) grid labels)  ///
		graphregion(color(white)) plotregion(lcolor(bluishgray)) scale(1.2) ///
		ytitle("Top 10% Factor Income Share") xtitle("") ///
		legend(label(1 "Capital") label(2 "Labour") label(3 "Total")) ///
		scheme(s1color) subtitle(,fcolor(white) lcolor(bluishgray)) 
	qui graph export "figures_apdx/St10ByCtry.pdf", replace 	
		
	//Graph countries individually
	qui levelsof iso2 if ///
		aux_bp==1 & aux_bp2==6, local(isos)
	foreach c in `isos' {
		graph twoway (line St10_K wave_pop_yr, lcolor(edkblue)) ///
			(line St10_L wave_pop_yr, lcolor(maroon)) ///
			(line St10 wave_pop_yr, lcolor(gray) lpattern(dash)) ///
			if iso2=="`c'" & aux_bp==1 & aux_bp2==6, ///
			xlabel(1995(5)2015, labsize(small) angle(horizontal) grid labels) ///
			ylabel(, labsize(small) angle(horizontal) grid labels)  ///
			graphregion(color(white)) plotregion(lcolor(bluishgray)) scale(1.2) ///
			ytitle("Top 10% Factor Income Share") xtitle("") ///
			legend(label(1 "Capital") label(2 "Labour") label(3 "Total")) ///
			scheme(s1color) subtitle(,fcolor(white) lcolor(bluishgray))
		qui graph export "figures_apdx/St10_`c'.pdf", replace 
	}
restore	

//BALANCED PANEL -----------------------------------------------------------------*

//Save info
tempfile randomname3
qui save `randomname3', replace
qui levelsof iso2 if iso2 != "US" & aux_bp == 1 & aux_bp2 == 6 ///
	, local (all_ctries)

// Balanced Panel and US separately	
local ctrygrp "BPanel US `all_ctries'"
foreach cg in `ctrygrp' {
	qui use `randomname3', clear
	qui gen KI_n = NI_n * K_net
	if ("`cg'"=="BPanel") {
		qui drop if iso2=="US" | aux_bp!=1 | aux_bp2!=6 
		qui levelsof wave_pop_yr, local(w_years)
		foreach y in `w_years'{
			qui sum NI_g if wave_pop_yr==`y'
			scal scal_NItot_`y'=r(sum)
		}
		qui collapse (sum) NI_g NI_n tot_K tot_S tot_L ///
			b50_L b50_K b50_S ///
			m40_L m40_K m40_S ///
			t10_K t10_L t10_S ///
			t1_K t1_L t1_S ///
			KI_svy LI_svy LI KI_n KI_HH, by (wave_pop_yr)	
	}
	if ("`cg'"=="US") {
		qui keep if iso2=="US"
	}
	
	if ("`cg'"!="BPanel" & "`cg'"!="US") {
		qui drop if iso2=="US" | aux_bp!=1 | aux_bp2!=6
		qui keep if iso2=="`cg'"
	}
	
	qui keep NI_g NI_n tot_K tot_S tot_L b50_L b50_K b50_S m40_L m40_K ///
		m40_S t10_K t10_L t10_S t1_K t1_L t1_S KI_svy LI_svy LI ///
		KI_n KI_HH wave_pop_yr
	
	//Create variables
	qui gen ki_h_svy = KI_svy / NI_g
	qui gen ki_h_na = KI_HH / NI_g
	qui gen li_svy = LI_svy / NI_g
	qui gen li_na = LI / NI_g
	qui gen KI = NI_g - LI
	qui gen K = KI / NI_g
	qui gen K_net = KI_n / NI_n
	qui gen Phi_h = KI_HH / KI

	//EPSILON
	qui gen epsiK = KI_svy / KI_HH
	qui gen epsiL = LI_svy / LI
	qui gen ratio = epsiK / epsiL
	qui gen K_svy = KI_svy / (KI_svy + LI_svy) * 100

	//Shares of each country put together
	local group "b50 m40 t10 t1"
	foreach g in `group'{
		qui gen S`g'_K = (`g'_K + `g'_S * 0.3) / (tot_K + tot_S * 0.3)
		qui gen S`g'_L = (`g'_L - `g'_S * 0.3) / (tot_L - tot_S * 0.3)
		qui gen S`g' = (`g'_L + `g'_K) / (tot_L + tot_K)
		qui gen Dif_`g' = S`g'_K - S`g'_L
	}
	
	//GAMMA
	qui gen gamma = ratio * Phi_h
	
	//Save data for contrib analysis
	tempfile tf_`cg'
	qui save `tf_`cg'', replace
	
	//Mutliply by 100
	local mult_var ///
		"St10 St10_L St10_K St1 St1_L St1_K K_svy K K_net Sm40 Sm40_K Sm40_L Sb50 Sb50_K Sb50_L epsiL epsiK ratio gamma Phi_h"
	foreach v in `mult_var' {
		qui replace `v' = `v' * 100
	}
	
	if ("`cg'" == "BPanel" | "`cg'" == "US") {
		if ("`cg'" == "BPanel") {
			local min_yr = 1995
		}
		if ("`cg'" == "US") {
			local min_yr = 1975
			qui export excel using "tables/Tables.xlsx"	, ///
				firstrow(variables) sheet("infoUS") sheetreplace	
			qui export excel wave_pop_yr St10 St10_K St10_L ///
				using "Tables/data-behind-figures.xlsx"	, ///
				firstrow(variables) sheet("Figure8a") sheetreplace	
		}
		//GRAPHS
		//Income concentration
		graph twoway (line St1 wave_pop_yr, lcolor(gray)) ///
			(line St1_K wave_pop_yr, lcolor(edkblue)) ///
			(line St1_L wave_pop_yr, lcolor(maroon)) ///
			, ytitle("Top 1%'s share of Factor Income (%)") xtitle("") ///
			xlabel(`min_yr'(5)2015, labsize(small) angle(horizontal) grid labels) ///
			ylabel(0(5)25, labsize(small) angle(horizontal) grid labels) ///
			text(8 1997  "Total", color(gray)) ///
			text(15 1997  "Capital", color(edkblue)) ///
			text(5 1997  "Labour", color(maroon)) ///
			graphregion(color(white)) scale(1.2) legend(off)
		qui graph export "figures/St1_`cg'.pdf", replace			
			
		//Income concentration
		graph twoway (line St10 wave_pop_yr, lcolor(gray) lpattern(dash)) ///
			(line St10_K wave_pop_yr, lcolor(edkblue)) ///
			(line St10_L wave_pop_yr, lcolor(maroon)) ///
			, ytitle("Top 10%'s share of Factor Income (%)") xtitle("") ///
			xlabel(`min_yr'(5)2015, labsize(small) angle(horizontal) grid labels) ///
			ylabel(25(5)50, labsize(small) angle(horizontal) grid labels) ///
			text(37 2013  "Total", color(gray)) ///
			text(45 2013  "Capital", color(edkblue)) ///
			text(32 2013  "Labour", color(maroon)) ///
			graphregion(color(white)) scale(1.2) legend(off)
		qui graph export "figures/St10_`cg'.pdf", replace
			
		if ("`cg'" == "US") {
			graph twoway (line St10 wave_pop_yr, lcolor(gray) lpattern(dash)) ///
				(line St10_K wave_pop_yr, lcolor(edkblue)) ///
				(line St10_L wave_pop_yr, lcolor(maroon)) ///
				, ytitle("Top 10%'s share of Factor Income (%)") xtitle("") ///
				xlabel(`min_yr'(5)2015, labsize(small) angle(horizontal) ///
				grid labels) ///
				ylabel(20(10)80, labsize(small) angle(horizontal) grid labels) ///
				text(39 2013  "Total", color(gray)) ///
				text(48 2013  "Capital", color(edkblue)) ///
				text(30 2013  "Labour", color(maroon)) ///
				graphregion(color(white)) scale(1.2) legend(off)
			qui graph export "figures/St10_`cg'.pdf", replace
		}	
			
		if ("`cg'" == "BPanel") {
			qui export excel wave_pop_yr St10 St10_K St10_L ///
				using "Tables/data-behind-figures.xlsx"	, ///
				firstrow(variables) sheet("Figure7b") sheetreplace
		}	

		//K and Gamma
		if ("`cg'" == "BPanel") {
		graph twoway (line K wave_pop_yr, yaxis(1) lcolor(edkblue)) ///
			(line gamma wave_pop_yr, yaxis(2) lcolor(maroon)) ///
			, ytitle("Capital Share (%)", axis(1)) xtitle("") ///
			ytitle("Gamma coefficient (%)", axis(2)) ///
			xlabel(`min_yr'(5)2015, labsize(small) angle(horizontal) grid labels) ///
			ylabel(32(2)44, axis(1) labsize(small) angle(horizontal) grid labels) ///
			ylabel(10(2)22, axis(2) labsize(small) angle(horizontal) grid labels) ///
			text(40 2012  "Capital Share", color(edkblue)) ///
			text(35 2012  "{&gamma}", color(maroon)) ///
			graphregion(color(white)) scale(1.2) legend(off)
		qui graph export "figures/KGamma_`cg'.pdf", replace
		qui export excel wave_pop_yr K gamma  ///
			using "Tables/data-behind-figures.xlsx"	, ///
			firstrow(variables) sheet("Figure7a") sheetreplace
		}	
			
		graph twoway (line gamma wave_pop_yr, lcolor(gs10)) ///
			(line Phi_h wave_pop_yr, lcolor(edkblue)) ///
			(line ratio wave_pop_yr, lcolor(maroon)) ///
			, ytitle("(%)") xtitle("") ///
			xlabel(`min_yr' 1975(5)2015, labsize(small) angle(horizontal) grid labels) ///
			ylabel(0(10)70, labsize(small) angle(horizontal) grid labels) ///
			graphregion(color(white)) scale(1.2) ///
			legend(label(1 "{&gamma}") label(2 "{&Phi}{subscript:h}") ///
			label(3 "{&epsilon}{sub:K}/{&epsilon}{sub:L}"))
		qui graph export "figures/DecGamma_`cg'.pdf", replace
		
if ("`cg'"=="BPanel"){
}
		//Graphs
		graph twoway (line epsiL wave_pop_yr, lcolor(edkblue)) ///
			(line epsiK wave_pop_yr, lcolor(maroon)) ///
			(line ratio wave_pop_yr, lcolor(gs10) lpattern(dash)) ///
			, title(/*"Structure of Capital Income"*/) ///
			subtitle(/*"Balanced Panel, 1995-2014"*/) ///
			ytitle("Share of Total Factor Income Captured (%)") xtitle("") ///
			xlabel(`min_yr'(5)2015, labsize(small) angle(horizontal) grid labels) ///
			ylabel(0(20)100, labsize(small) angle(horizontal) grid labels) ///
			text(75 2011  "Labour Income ({&epsilon}{sub:L})", color(edkblue)) ///
			text(15 2011  "Capital Income ({&epsilon}{sub:K})", color(maroon)) ///
			text(32 2014  "{&epsilon}{sub:K}/{&epsilon}{sub:L}", color(gs10)) ///
			graphregion(color(white)) scale(1.2) legend(off)
		qui graph export "figures/Epsilon_`cg'.pdf", replace
		qui export excel wave_pop_yr epsiK epsiL ratio ///
			using "Tables/data-behind-figures.xlsx"	, ///
			firstrow(variables) sheet("Figure5a") sheetreplace
	}	
}

//Analyze contributions to change --------------------------------------------//

// Get last country in bpanel list
local n_ctries_bp : word count `all_ctries'
local last_ctry_bp : word `n_ctries_bp' of `all_ctries'

foreach s in "t10" "t1" "m40" "b50" {
	local iter = 1
	foreach cg in `ctrygrp'{
		qui use `tf_`cg'', clear
		
		//DERIVATIVES
		qui gen d_K_`s' = (gamma * (S`s'_K - S`s'_L)) / (K * gamma + (1-K))^2
		qui gen d_S`s'_L = (1-K) / (gamma * K + (1-K))
		qui gen d_S`s'_K = (gamma * K) / (gamma * K + (1-K))
		qui gen d_gam_`s' = (K * (1-K) * (S`s'_K - S`s'_L)) / (gamma * K + (1-K))^2
		qui gen d_phi_`s' = (K * (1-K) * ratio * (S`s'_K - S`s'_L)) / (gamma * K + (1-K))^2
		qui gen d_rat_`s' = (K * (1-K) * Phi_h * (S`s'_K - S`s'_L)) / (gamma * K + (1-K))^2
		qui gen countryorarea="`cg'" 

		//Save table of derivatives
		preserve
			local dev_vars "d_K_`s' d_S`s'_L d_S`s'_K d_gam_`s' d_phi_`s' d_rat_`s'"
			qui collapse (mean) `dev_vars', by(countryorarea) 
			foreach v in `dev_vars' {
				qui format %9.2f `v'
			}
			if (`iter'==1) {
				tempfile tf_base_d_`s'
				qui save `tf_base_d_`s''
			}
			if (`iter'==0) {
				qui append using `tf_base_d_`s''
				qui save `tf_base_d_`s'', replace
			}
		restore
		qui rename (K gamma Phi_h ratio) (K_`s' gam_`s' phi_`s' rat_`s')
		//Deltas and Effects
		local deltavars "K_`s' S`s'_K S`s'_L gam_`s' phi_`s' rat_`s'"
		foreach v in `deltavars' {
			qui gen v_`v' = `v' - `v'[_n-1] if _n != 1
			qui gen e_`v' = v_`v' * d_`v'[_n-1] if _n != 1
		}
		
		qui replace e_gam_`s' = e_phi_`s' + e_rat_`s'
		qui gen S`s'_AgEf = e_K_`s' + e_S`s'_K + e_S`s'_L + e_phi_`s' + e_rat_`s'
		qui gen S`s'_est = S`s'[_n-1] + S`s'_AgEf 
		
		//contribution in period
		preserve 
			qui collapse (sum) e_K_`s' e_S`s'_K e_S`s'_L ///
				e_gam_`s' e_phi_`s' e_rat_`s' ///
				(last) S`s'_est_last = S`s'_est S`s'_last = S`s' ///
				(first) S`s'_first = S`s' ///
				, by(countryorarea)  
			
			qui gen actual_var = S`s'_last - S`s'_first
			qui egen e_tot = rowtotal(e_K_`s' e_S`s'_K e_S`s'_L e_gam_`s')
			qui gen est_error = e_tot - actual_var
			qui keep countryorarea e_K_`s' e_S`s'_K e_S`s'_L e_gam_`s' ///
				e_phi_`s' e_rat_`s' e_tot actual_var est_error
			
			//Percentages
			local pct_vars ///
				"e_K_`s' e_S`s'_K e_S`s'_L e_gam_`s' e_phi_`s' e_rat_`s' e_tot actual_var est_error"
			foreach v in `pct_vars' {
				qui replace `v' = `v' * 100
				qui format %9.1f `v'
			}
			
			//Save or append 
			if (`iter' == 1) {
				tempfile tf_base_`s'
				qui save `tf_base_`s''
			}
			local iter = 0
			if (`iter' == 0) {
				qui append using `tf_base_`s''
				qui save `tf_base_`s'', replace
			}
		
			//Save tables 
			if ("`cg'" == "`last_ctry_bp'") {
				qui use `tf_base_`s'' , clear 
				qui replace countryorarea="Q_BPanel" ///
					if countryorarea=="BPanel"
				qui sort countryorarea
				qui collapse (first) `pct_vars', by(countryorarea)
				qui kountry countryorarea, from(iso2c)
				qui rename NAMES_STD Country 
				qui drop countryorarea
				qui order Country `pct_vars'
				qui export excel using "tables/Tables.xlsx"	, ///
					firstrow(variables) sheet("Contrib_`s'") sheetreplace	
				qui save "tables/Tables_aux.dta", replace 	
				
				//Empirical derivatives 
				qui use `tf_base_d_`s'' , clear 
				qui replace countryorarea="Q_BPanel" ///
					if countryorarea=="BPanel"
				qui sort countryorarea
				qui collapse (first) `dev_vars', by(countryorarea)
				qui kountry countryorarea, from(iso2c)
				qui rename NAMES_STD Country 
				qui drop countryorarea
				qui order Country `dev_vars'
				qui export excel using "tables/Tables.xlsx"	, ///
					firstrow(variables) sheet("Deriv_`s'") sheetreplace			
			}
		restore	
	}
}
//---------------------------------------------------------------------------//

//Analyze structure 
qui use `randomname3', clear
qui drop if iso2 == "US"
qui gen NI_share = .
foreach y in `w_years' {
	replace NI_share = NI_g / scal_NItot_`y' * 100 if wave_pop_yr == `y'
}

qui encode iso2, gen(iso2_id)
qui xtset iso2_id wave_yr
xtline NI_share 
//graph export "figures_apdx/Phi_structure.pdf", replace

//On average  
qui collapse (mean) NI_share, by(iso2)
qui egen test=total(NI_share)
qui sort NI_share
qui format %9.1f NI_share
qui gen auxi=_n

//Table on average structure
qui gsort -NI_share	
qui gen cumshare=sum(NI_share)
qui format %9.1f cumshare
qui keep iso2 NI_share cumshare
