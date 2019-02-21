//
// Income under the CARPET
// Ignacio Flores
// Aug 2018
//
clear all 
set more off
cd "~/GitHub/Under_the_carpet"

//----------------------------------------------------------------------------//
// INSTITUTIONAL SECTOR ACCOUNTS (UN-DATA: http://data.un.org/)
//----------------------------------------------------------------------------//

// 0. LOCALS -----------------------------------------------------------------//

//Institutional sectors and K definition
local i_sector "HH HHnpish SFL G SF SnF SFSnF Total"
local variables "OS_g MI_g CE FKC PIr PIu FISIM"
local ordr "countryorarea series year"
local K "Kg"
local n=5
local year1=1980
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
	
	sort `ordr' subgroup, stable	
	foreach v in `variables' {
		quietly gen `v'_`i' =.
		quietly replace `v'_`i'=value if (item=="`item_`v''" & subgroup=="`subgroup_`v''")
	}

	//Collapse & save (temp)
	quietly collapse (max) `variables' (firstnm) currency_sna=currency, by (`ordr')	
	quietly gen NPI_`i'=PIr_`i'-PIu_`i'
	quietly drop PIr_`i' PIu_`i'
	if ("`i'"=="SnF"){
		quietly gen Kshare_SnF=OS_g_SnF/(OS_g_SnF+CE_SnF)   
	}
	tempfile temp`i'
	save `temp`i''
}
//Merge in 1 file
use `tempTotal', clear
foreach i in `i_sector' {
	if ("`i'"!="Total"){
		merge 1:1 `ordr' using "`temp`i''" , nogenerate
	}	
}

// II. CREATE MAIN VARIABLES FROM NATIONAL ACCOUNTS --------------------------//

//MI and NI
quietly gen MI_g_k=MI_g_Total*0.3
quietly gen MI_g_l=MI_g_Total*(1-0.3)
quietly gen NI_g=OS_g_Total+MI_g_Total+CE_Total+NPI_Total
quietly gen NI_n=OS_g_Total+MI_g_Total+CE_Total+NPI_Total-FKC_Total

//Capital share
quietly gen KI=OS_g_Total+MI_g_k+NPI_Total
quietly gen LI=CE_Total+MI_g_l
quietly gen KI_net=KI-FKC_Total
quietly gen K=KI/NI_g
quietly gen K_net=KI_net/NI_n

//Special cases
quietly replace KI=OS_g_Total+NPI_Total if countryorarea=="China"
quietly replace K=(OS_g_Total+NPI_Total)/(OS_g_Total+CE_Total+NPI_Total) ///
	if countryorarea=="China"
quietly replace K_net=(OS_g_Total+NPI_Total-FKC_Total)/ ///
	(OS_g_Total+CE_Total+NPI_Total-FKC_Total) if countryorarea=="China"

quietly drop if missing(K)	

//FISIM adjustment
quietly replace OS_g_SF=OS_g_SF-FISIM_Total if !missing(FISIM_Total)
quietly replace OS_g_SFSnF=OS_g_SFSnF-FISIM_Total if !missing(FISIM_Total) ///
	& missing(OS_g_SnF) & !missing(OS_g_SFSnF)
rename FISIM_Total fisim
drop FISIM*

//Phi (all sectors)
foreach i in `i_sector'{
	quietly gen KI_`i'=OS_g_`i'+NPI_`i'
	if ("`i'"=="HH" | "`i'"=="HHnpish") {
		quietly replace KI_`i'=OS_g_`i'+MI_g_k+NPI_`i' if countryorarea!="China" 
	}
	quietly gen phi_g_`i'=KI_`i'/KI
	quietly gen phi_n_`i'=(KI_`i'-FKC_`i')/KI_net
}
// if HH is HH+NPISH
quietly replace phi_g_HH=phi_g_HHnpish ///
	if missing(phi_g_HH) & !missing(OS_g_HHnpish)
quietly replace phi_n_HH=phi_n_HHnpish ///
	if missing(phi_n_HH) & !missing(OS_g_HHnpish) 
	
// if SF and SnF reported toghether
quietly gen SFSnF_marker=1 if missing(phi_g_SnF) & !missing(OS_g_SFSnF)
quietly replace phi_g_SnF=phi_g_SFSnF ///
	if missing(phi_g_SnF) & !missing(OS_g_SFSnF)
quietly replace phi_g_SF=. ///
	if phi_g_SnF==phi_g_SFSnF & !missing(OS_g_SFSnF)
quietly replace phi_n_SnF=phi_n_SFSnF ///
	if missing(phi_n_SnF) & !missing(OS_g_SFSnF) 	
	
//Test of consistency
//quietly replace phi_g_SF=0 if !missing(phi_g_SFSnF) & !missing(phi_g_SF)
quietly egen test1=rowtotal(phi_g_SF phi_g_SFL phi_g_SnF phi_g_HH phi_g_G)
quietly replace test1=test1+phi_g_HHnpish if missing(phi_g_HH)
quietly replace test1=round(test1, 0.05) 
quietly gen test2=1 if test1==1
quietly replace test2=0 if test1!=1
tab country test2
order countryorarea year series test1 test2 phi_g_HH phi_g_HHnpish phi_g_SFL ///
	phi_g_SF phi_g_SnF phi_g_SFSnF phi_g_G  phi_g_Total, first 
keep if test1==1

//Phi w/ and w/o G
foreach gn in `grossnet' {
	quietly gen phi_`gn'_corp=phi_`gn'_SF+phi_`gn'_SnF
	quietly egen phi_`gn'_corp_2=rowtotal(phi_`gn'_SF phi_`gn'_SnF)
	quietly replace phi_`gn'_corp=phi_`gn'_corp_2 if SFSnF_marker==1
	quietly gen phi_`gn'_hh=phi_`gn'_HH/(phi_`gn'_corp+phi_`gn'_HH)
	quietly gen phi_`gn'_cp=phi_`gn'_corp/(phi_`gn'_corp+phi_`gn'_HH)
}

//Std. Country names
quietly replace countryorarea="Czech Republic" if countryorarea=="Czechia"
kountry countryorarea, from(other) stuck marker
rename _ISO3N_ countryn
kountry countryn, from(iso3n) to(iso2c) geo(undet)
rename _ISO2C_ iso2
drop if MARKER==0
drop MARKER 
order countryorarea iso2 countryn, first
tostring series, gen(series_st)
gen country_series=iso2+series_st

//SAVE n.1
tempfile save1st
save `save1st', replace

//Compare with Piketty & Zucman 
import excel "Data/PZ_Kshares.xlsx", ///
	sheet("Hoja1") firstrow clear	

reshape long K_PZ_ Ki_PZ_ , i(year) j(country) string
sort country year, stable
drop if missing(K_PZ)
kountry country, from(other) stuck marker
rename _ISO3N_ countryn
kountry countryn, from(iso3n) to(iso2c)
quietly rename _ISO2C_ iso2
tempfile temp_PZ
quietly replace Ki_PZ=Ki_PZ*100
quietly replace K_PZ=K_PZ*100
quietly save `temp_PZ', replace	

use `save1st', clear
quietly merge m:1 iso2 year using `temp_PZ', keepusing(K_PZ_ Ki_PZ_) generate(_merge2)
tempfile save1stKKnet
quietly save `save1stKKnet', replace
quietly sort iso2 year	
drop if _merge2==1
quietly replace K_n=K_net*100
quietly label var  Ki_PZ_ "PZ2015 incl. Govt. interest"
quietly label var  K_PZ_ "PZ2015 excl. Govt. interest"
quietly label var K_n "Net Capital Income"

graph twoway (line K_PZ_ K_n year) if series==1000 & iso2!="AU", by(iso2) ///
	graphregion(color(white)) plotregion(lcolor(bluishgray)) scale(1.2) ///	
	xlabel(1980(10)2010, labsize(medium) grid labels) ///
	ylabel(0(10)30, labsize(medium) angle(horizontal) format(%2.0f) grid labels) ///
	scheme(s1color) subtitle(,fcolor(white) lcolor(bluishgray)) ///
	legend(label(1 "Piketty and Zucman (2014)") label(2 "Own estimates"))
quietly graph export "figures_apdx/KperCtry(PZ).pdf", replace 

// III. PHI: BALANCED PANEL ----------------------------------------------------// 

// III. a) DATA ----------------------------------------------------------------//

//Prepare data
use `save1st', clear
drop if missing(K)
encode country_series, gen(ctry_id)
xtset ctry_id year 
order ctry_id countryorarea, first
xtdescribe

//Get balanced sub-panel
 keep if year>=1995 & year<=2016 & iso2!="US" 
 bysort country_series: egen anios=count(year) 
 keep if anios>=22
  tab iso2 year
 quietly levelsof iso2, local(paises)
 quietly levelsof countryorarea, local(paises2)
 foreach p in `paises' {
	quietly sum series if iso2=="`p'" 
	drop if iso2=="`p'" & series!=r(max)
 }
quietly gen KI_hh=phi_g_HH*KI
quietly gen KI_hh_n=phi_n_HH*KI_net
quietly gen KI_corp=phi_g_corp*KI
quietly gen KI_corp_n=phi_n_corp*KI_net

//Generate Net vars
quietly gen KI_G_n=KI_G-FKC_G
quietly gen KI_SFL_n=KI_SFL-FKC_SFL
quietly gen OS_n_G=OS_g_G-FKC_G

//Keep most recent series by year
egen country_year=concat(iso2 year)
quietly levelsof country_year, local(cyears)
foreach y in `cyears' {
	quietly sum series if country_year=="`y'"
	quietly drop if country_year=="`y'" & series!=r(max)
}

levelsof iso2, local(aux_bp)

tempfile randomname
save "`randomname'", replace
di "Balanced Panel"
xtdescribe 

//Get Exchange rates
quietly levelsof iso2, local(ctries)
quietly levelsof year, local(yrs)
import delimited "Data/UN/UNdata_xrates.csv" ///
	, encoding(ISO-8859-1)clear
quietly replace countryorarea = subinstr(countryorarea, ", People's Republic of", "",.) 
quietly replace countryorarea = subinstr(countryorarea, "Former ", "",.) 
quietly replace countryorarea = subinstr(countryorarea, " of Great Britain and Northern Ireland", "",.) 
quietly replace countryorarea = subinstr(countryorarea, " (Bolivarian Republic of)", "",.) 	

//Harmonize country names
kountry countryorarea, from(other) stuck marker
rename _ISO3N_ iso3
kountry iso3, from(iso3n) to(iso2c)
rename _ISO2C_ iso2
drop if MARKER==0
keep iso2 xrateama year xrateamanote

tempfile xrates_yr
save `xrates_yr', replace
quietly merge m:1 iso2 year using `randomname'
format %15s xrateamanote
keep if _merge==3

//Transform to market USD (yearly)
local toreplace_gross "KI KI_hh KI_corp KI_G KI_SFL NPI_G OS_g_G" 
local toreplace_net "KI_net KI_hh_n KI_corp_n KI_G_n KI_SFL_n OS_n_G"
local toreplace "`toreplace_gross' `toreplace_net'"
foreach t in `toreplace' {
	quietly replace `t'=`t'/xrateama
}

tempfile randomname2
save "`randomname2'", replace

// III. b) GRAPHS BY COUNTRY---------------------------------------------------//

//Capital Shares


// Graphs per country (gross)
local isectors "hh corp G SFL"
foreach i in `isectors' {
	quietly gen phi_`i'=KI_`i'/KI*100
}	
label var phi_hh "Households"
label var phi_corp "Private Corporations"
label var phi_G "General Government"
quietly gen phi_hh2=phi_hh/(phi_hh+phi_corp)*100
quietly gen phi_corp2=phi_corp/(phi_hh+phi_corp)*100 
quietly egen test10=rowtotal(phi_hh phi_corp phi_G)
quietly egen test20=rowtotal(phi_hh phi_corp phi_G phi_SFL)
label var phi_hh2 "Households"
label var phi_corp2 "Private Corporations"

// Graphs per country (net)
local isectors "hh corp G SFL"
foreach i in `isectors' {
	quietly gen phi_`i'_n=KI_`i'_n/KI_n*100
}	
label var phi_hh_n "Households"
label var phi_corp_n "Private Corporations"
label var phi_G_n "General Government"
quietly gen phi_hh2_n=phi_hh_n/(phi_hh_n+phi_corp_n)*100
quietly gen phi_corp2_n=phi_corp_n/(phi_hh_n+phi_corp_n)*100 
quietly egen test10_n=rowtotal(phi_hh_n phi_corp_n phi_G_n)
quietly egen test20_n=rowtotal(phi_hh_n phi_corp_n phi_G_n phi_SFL_n)
quietly gen auxi_test20=1 if test20_n<101 & test20_n>99
label var phi_hh2_n "Households"
label var phi_corp2_n "Private Corporations"

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
graph export "figures_apdx/AllPhis_BpanelG.pdf", replace

//Graph (w/o G, GROSS)
graph twoway (line phi_hh2 year, lcolor(edkblue)) ///
	(line phi_corp2 year, lcolor(maroon)) ///
	,by(iso2) ytitle("Share of Total Gross Capital Income (%)") xtitle("") ///
	xlabel(1995(5)2015, labsize(small) angle(horizontal) grid labels) ///
	ylabel(20(20)80, labsize(small) angle(horizontal) grid labels) ///
	graphregion(color(white)) plotregion(lcolor(bluishgray)) scale(1.2) ///
	scheme(s1color) subtitle(,fcolor(white) lcolor(bluishgray))
graph export "figures_apdx/AllPhis_BpanelnoG.pdf", replace

// III. b) AGGREGATE PICTURE (GROSS)-------------------------------------------//

tempfile tf_bpn
quietly save `tf_bpn'

//Create KI_n
quietly gen KI_n=NI_n*K_net

//Capital Shares
preserve 
		local cg "BPanel"
		local min_yr=1995
		quietly replace K=K*100
		quietly replace K_net=K_net*100
	
		graph twoway (line K year, lcolor(edkblue)) ///
			(line K_net year, lcolor(maroon)) ///
			, by(iso2) ytitle("Capital Income Share (%)") xtitle("") ///
			xlabel(1995(5)2015, labsize(medium) angle(horizontal) grid labels) ///
			ylabel(10(10)55, labsize(medium) angle(horizontal) grid labels) ///
			graphregion(color(white)) scale(1.2) legend(label(1 "Gross") label(2 "Net"))  ///
			scheme(s1color) subtitle(,fcolor(white) lcolor(bluishgray))
			quietly graph export "figures/KKnetByCtry_BP.pdf", replace

		quietly collapse (sum) NI_g NI_n ///
			LI KI_n, by (year)
		quietly gen KI=NI_g-LI
		quietly gen K=KI/NI_g*100
		quietly gen K_net=KI_n/NI_n*100	
		
		graph twoway (line K year, lcolor(edkblue)) ///
			(line K_net year, lcolor(maroon)) ///
			, ytitle("Capital Income Share (%)") xtitle("") ///
			xlabel(1995(5)2015, labsize(small) angle(horizontal) grid labels) ///
			ylabel(0(10)50, labsize(small) angle(horizontal) grid labels) ///
			text(37 2013  "Gross", color(edkblue)) ///
			text(23 2013  "Net", color(maroon)) ///
			graphregion(color(white)) scale(1.2) legend(off)
			quietly graph export "figures/KKnet_BP.pdf", replace	
restore

//Collapse
quietly collapse (sum) KI_hh KI_corp KI_G KI_SFL KI KI_n NI_n NI_g ///
	(mean) avgphi_g_HH_notG=phi_hh2 avgphi_g_corp_notG=phi_corp2 ///
	avgphi_g_hh=phi_hh avgphi_g_corp=phi_corp avgphi_g_G=phi_G ///	
	, by (year)	
local isectors "hh corp G SFL"
foreach i in `isectors' {
	quietly gen phi_`i'=KI_`i'/KI*100
}	
label var phi_hh "Households"
label var phi_corp "Private Corporations"
label var phi_G "General Government"

//Phis
quietly gen phi_hh2=phi_hh/(phi_hh+phi_corp)*100
quietly gen phi_corp2=phi_corp/(phi_hh+phi_corp)*100 
quietly gen avgphi_g_hh2_NG=avgphi_g_hh/(avgphi_g_hh+avgphi_g_corp)*100 
quietly gen avgphi_g_corp2_NG=avgphi_g_corp/(avgphi_g_hh+avgphi_g_corp)*100 

quietly egen test1=rowtotal(phi_hh phi_corp phi_G)
quietly egen test2=rowtotal(phi_hh phi_corp phi_G phi_SFL)
label var phi_hh2 "Households"
label var phi_corp2 "Private Corporations"

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
graph export "figures/Phis.pdf", replace

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
	graph export "figures/Phi_wo_G.pdf", replace

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
graph export "figures/AvgPhisgross.pdf", replace

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
graph export "figures/AvgPhisgrossNotG.pdf", replace

//Save info
quietly levelsof year, local(years)
foreach y in `years'{
	quietly sum KI if year==`y'
	scal scal_KItot_`y'=r(max)
	quietly sum phi_hh2 if year==`y'
	scal scal_phihh2_`y'=r(max)
	quietly sum phi_hh if year==`y'
	scal scal_phiHH_`y'=r(max)
}

//ZOOM IN PHI G
quietly use `randomname2', clear
quietly encode countryorarea, gen(xtvar) 
quietly xtset xtvar year 
quietly levelsof country_series, local(ctries)
local idxes "OS_g NPI"

foreach i in `idxes' {
	quietly gen `i'_G_ratio=`i'_G/KI
	quietly gen `i'_index=.
	foreach c in `ctries' {
		quietly sum `i'_G_ratio if country_series=="`c'" & year==1995
		quietly replace `i'_index=(`i'_G_ratio)*100 if country_series=="`c'"
	}
}
quietly encode iso2, gen(iso2_id)
quietly xtset iso2_id year

//Structure of Phi_G
quietly label var OS_g_G_ratio "Operating Surplus"
quietly label var NPI_G_ratio "Net Property Income"
quietly label var phi_g_G "Total"

graph twoway (line OS_g_G_ratio year) (line NPI_G_ratio year) (line phi_g_G year, lcolor(gray)) ///
	, by(iso2) ytitle("Share of National Gross Capital Income (%)") xtitle("") ///
	xlabel(1995(5)2015, labsize(small) angle(horizontal) grid labels) ///
	ylabel(-0.2(0.2)0.4, labsize(small) angle(horizontal) grid labels) ///
	 yline(0, lcolor(black) lpattern(dot)) graphregion(color(white)) ///
	plotregion(lcolor(bluishgray)) scale(1.2) ///
	scheme(s1color) subtitle(,fcolor(white) lcolor(bluishgray))
	graph export "figures_apdx/Phis_G_comp.pdf", replace	

//Analyze structure 
use `randomname2', clear
quietly gen KI_share=.
foreach y in `years' {
	replace KI_share=KI/scal_KItot_`y'*100 if year==`y'
}
//graph export "figures_apdx/Strucutre.pdf", replace

//On average  
quietly collapse (mean) KI_share, by(countryorarea)
quietly egen test=total(KI_share)
quietly sort KI_share
quietly format %9.1g KI_share
quietly gen auxi=_n

//Table on average structure
quietly gsort -KI_share	
quietly gen cumshare=sum(KI_share)
format %9.1g cumshare
keep countryorarea KI_share cumshare

// III. c) AGGREGATE PICTURE (NET)-------------------------------------------//
use `tf_bpn', replace
 bysort country_series: egen anios_n=count(year) if auxi_test20==1
 keep if anios_n>=22
 
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
graph export "figures_apdx/AllNetPhis_BpanelG.pdf", replace

//Graph (w/o G, NET)
graph twoway (line phi_hh2_n year, lcolor(edkblue)) ///
	(line phi_corp2_n year, lcolor(maroon)) ///
	if auxi_test20==1 & iso2!="DE" & iso2!="AT" ///
	,by(iso2) ytitle("Share of Total Net Capital Income (%)") xtitle("") ///
	xlabel(1995(5)2015, labsize(small) angle(horizontal) grid labels) ///
	ylabel(0(20)100, labsize(small) angle(horizontal) grid labels) ///
	graphregion(color(white)) plotregion(lcolor(bluishgray)) scale(1.2) ///
	scheme(s1color) subtitle(,fcolor(white) lcolor(bluishgray))
graph export "figures_apdx/AllNetPhis_BpanelnoG.pdf", replace
 
quietly collapse (sum) KI_hh_n KI_corp_n KI_G_n KI_SFL_n KI_net ///
	(mean) avgphi_g_HH_notG=phi_hh2 avgphi_g_corp_notG=phi_corp2 ///
	avgphi_g_hh=phi_hh avgphi_g_corp=phi_corp avgphi_g_G=phi_G ///
	avgphi_n_HH_notG=phi_hh2_n avgphi_n_corp_notG=phi_corp2_n ///
	avgphi_n_hh=phi_hh_n avgphi_n_corp=phi_corp_n avgphi_n_G=phi_G_n ///
	, by (year)	
local isectors "hh corp G SFL"
foreach i in `isectors' {
	quietly gen phi_`i'_n=KI_`i'_n/KI_net*100
}	

//Phis
quietly gen phi_hh2_n=phi_hh_n/(phi_hh_n+phi_corp_n)*100
quietly gen phi_corp2_n=phi_corp_n/(phi_hh_n+phi_corp_n)*100 
quietly gen avgphi_n_hh2_NG=avgphi_n_hh/(avgphi_n_hh+avgphi_n_corp)*100 
quietly gen avgphi_n_corp2_NG=avgphi_n_corp/(avgphi_n_hh+avgphi_n_corp)*100 
quietly egen test1=rowtotal(phi_hh_n phi_corp_n phi_G_n)
quietly egen test2=rowtotal(phi_hh_n phi_corp_n phi_G_n phi_SFL_n)

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
graph export "figures/NetPhis.pdf", replace

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
	graph export "figures/NetPhi_wo_G.pdf", replace
	
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
graph export "figures/AvgPhisNetG.pdf", replace

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
graph export "figures/AvgPhisNetNotG.pdf", replace	
	
//IV. LONG RUN SERIES --------------------------------------------------------//

//IV. a) GROSS ---------------------------------------------------------------//

use `save1st', clear
quietly collapse (min) year_min=year (max) year_max=year, by (GEO country_series)
quietly encode country_series, gen(ctry_id)
quietly levelsof GEO, local(regions)

//Identify series starting before 1990
drop if year_min>=1990 & country_series!="JP300" & country_series!="IT300" & country_series!="US1000" 
quietly levelsof country_series, local(cs_before1990)

//Draw those series
use `save1st', clear
gen marker=.
foreach s in `cs_before1990'{
	quietly replace marker=1 if country_series=="`s'"
}
keep if marker==1 
encode country_series, gen(ctry_id)
xtset ctry_id year
quietly replace phi_g_hh=phi_g_hh*100
quietly replace phi_g_HH=phi_g_HH*100
quietly replace phi_n_hh=phi_n_hh*100
quietly replace phi_n_HH=phi_n_HH*100
quietly replace phi_n_G=phi_n_G*100
quietly replace phi_n_SFL=phi_n_SFL*100
quietly replace phi_n_corp=phi_n_corp*100
quietly replace phi_n_corp_2=phi_n_corp_2*100
quietly replace phi_n_HHnpish=phi_n_HHnpish*100
quietly replace phi_n_SFSnF=phi_n_SFSnF*100

quietly gen Phi_BPanel_noG=.
quietly gen Phi_BPanel_G=.
foreach y in `years' {
	replace Phi_BPanel_noG=scal_phihh2_`y' if year==`y'
	replace Phi_BPanel_G=scal_phiHH_`y' if year==`y'
}

local E_speaking "US GB CA AU"
foreach c in `E_speaking'{
	replace GEO="English Speaking" if iso2=="`c'"
}

quietly replace GEO="Other European" if GEO=="Western Europe"
quietly replace GEO="Other European" if iso2=="IT"
quietly replace GEO="Scandinavian" if GEO=="Northern Europe"
quietly replace GEO="Asia" if GEO=="Eastern Asia"
local todrop "NO200 FI200 FI300 AU200 AU100"
foreach d in `todrop' {
drop if country_series=="`d'" 
} 
drop if year<1960 

quietly sum phi_g_HH
local phimax=r(max)
sort countryorarea series year
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
	graph export "figures/LR_JP_`fname'.pdf", replace
	
//SCANDINAVIAN
graph twoway (line `v' year if country_series=="FI500", lcolor(edkblue)) ///
	(line `v' year if country_series=="NO300", lcolor(maroon))  ///
	(line Phi_BPanel_`fname' year if country_series=="CA1000", lcolor(gs10) lpattern(dash)) ///
	, xlabel(1960(10)2010, grid labels) graphregion(color(white)) ///
	ylabel(10(20)110, angle(horizontal)) /// 
	legend(off) text(43 1970  "Finland", color(edkblue)) ///
	text(28 1970  "Norway", color(maroon)) ///
	ytitle("Household share of Capital Income (%)") xtitle("") scale(`scalen')
	graph export "figures/LR_Scandi_`fname'.pdf", replace

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
	graph export "figures/LR_Eng_`fname'.pdf", replace
	
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
	graph export "figures/LR_EUR_`fname'.pdf", replace
}

// b) NET ---------------------------------------------------------------------//

quietly egen test10_n=rowtotal(phi_n_HH phi_n_corp phi_n_G)
quietly egen test20_n=rowtotal(phi_n_HH phi_n_corp phi_n_G phi_n_SFL)
quietly egen test30_n=rowtotal(phi_n_HHnpish phi_n_corp_2 phi_n_G)
quietly egen test40_n=rowtotal(phi_n_HH phi_n_corp_2 phi_n_G)
quietly gen auxi_test20=1 if test20_n<101 & test20_n>99

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
	(line Phi_BPanel_`fname' year if country_series=="CA1000", lcolor(gs10) lpattern(dash)) ///
	if auxi_test20==1 ///
	, xlabel(1960(10)2010, grid labels) graphregion(color(white)) ///
	ylabel(10(30)160, angle(horizontal)) /// 
	legend(off) ytitle("Household share of Capital Income (%)") xtitle("") ///
	text(60 1975  "Japan ('100' series)", color(edkblue)) ///
	text(35 2004  "Japan ('300' series)", color(ltblue)) scale(`scalen') 
	graph export "figures/LRnet_JP_`fname'.pdf", replace
	
//SCANDINAVIAN
graph twoway (connected `v' year if country_series=="FI500", lcolor(edkblue) msize(small) mfcolor(white)) ///
	(line `v' year if country_series=="NO300", lcolor(maroon))  ///
	(line Phi_BPanel_`fname' year if country_series=="CA1000", lcolor(gs10) lpattern(dash)) ///
	if auxi_test20==1 & `v'>-100 & `v'<100 ///
	, xlabel(1960(10)2010, grid labels) graphregion(color(white)) ///
	ylabel(10(30)160, angle(horizontal)) /// 
	legend(off) text(60 1970  "Finland", color(edkblue)) ///
	text(28 1970  "Norway", color(maroon)) ///
	ytitle("Household share of Capital Income (%)") xtitle("") scale(`scalen')
	graph export "figures/LRnet_Scandi_`fname'.pdf", replace
	
//OTHER EURO 
graph twoway (line `v' year if country_series=="IT200", lcolor(edkblue)) ///
	(line `v' year if country_series=="IT300", lcolor(ltblue)) ///
	(line `v' year if country_series=="FR300", lcolor(maroon)) ///
	(line `v' year if country_series=="NL300", lcolor(forest_green))  ///
	(line Phi_BPanel_`fname' year if country_series=="CA1000", lcolor(gs10) lpattern(dash)) ///
	if auxi_test20==1 ///
	, xlabel(1960(10)2010, grid labels) graphregion(color(white)) ///
	ylabel(10(30)160, angle(horizontal)) /// 
	legend(off) text(120 1972 "Italy ('200' series)", color(edkblue)) ///
	text(100 1995 "Italy ('300' series)", color(ltblue)) ///
	text(80 1972 "France", color(maroon)) ///
	text(35 1998 "Netherlands", color(forest_green)) ///
	ytitle("Household share of Capital Income (%)") xtitle("")	scale(`scalen')
	graph export "figures/LRnet_EUR_`fname'.pdf", replace
}

//V. PHI: UNBALANCED PANEL ----------------------------------------------------//

use `save1st', clear
encode country_series, gen(country_series_id)
xtset country_series_id year
quietly replace phi_g_hh=phi_g_hh*100
quietly replace phi_g_HH=phi_g_HH*100
quietly replace phi_g_corp=phi_g_corp*100
quietly replace phi_g_G=phi_g_G*100
quietly replace phi_g_cp=phi_g_cp*100
di "Unbalanced Panel"
xtdescribe

quietly replace phi_n_hh=phi_n_hh*100
quietly replace phi_n_HH=phi_n_HH*100
quietly replace phi_n_corp=phi_n_corp*100
quietly replace phi_n_G=phi_n_G*100
quietly replace phi_n_cp=phi_n_cp*100

//US
quietly gen Phi_BPanel_noG=.
quietly gen Phi_BPanel_G=.
foreach y in `years' {
	replace Phi_BPanel_noG=scal_phihh2_`y' if year==`y'
	replace Phi_BPanel_G=scal_phiHH_`y' if year==`y'
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
	ytitle("Household share of Capital Income (%)") xtitle("") ///
	graphregion(color(white)) legend(label(1 "US SNA94") ///
	label(2 "US SNA08") label(3 "Balanced Panel (20 Countries)"))
	graph export "figures_apdx/US1995-2015_G.pdf", replace
	
	graph twoway (line phi_g_hh year if country_series=="US100", lcolor(ltblue)) ///
	(line phi_g_hh year if country_series=="US1000", lcolor(edkblue)) ///
	(line phi_g_cp year if country_series=="US1000", lcolor(maroon)) ///
	(line phi_g_cp year if country_series=="US100", lcolor(orange_red)) ///
	if year>=1970 & year<=2016, ///
	ylabel(10(10)70, angle(horizontal)) ///
	xlabel(1970(5)2015, grid labels) ///
	ytitle("Household share of Capital Income (%)") xtitle("") ///
	graphregion(color(white)) legend(label(1 "US SNA94") ///
	label(2 "US SNA08") label(3 "Balanced Panel (20 Countries)"))
	graph export "figures_apdx/US1995-2015_noG.pdf", replace
	
//K trends
//xtline K if GEO=="South America" | GEO=="Central America"

//Phi trends 
sort countryorarea country_series year
quietly egen timegroup=cut(year), at(1970(10)1999 2000(15)2015)
quietly egen timegroup1995=cut(year), at(1995(20)2015)

//Manage series
egen country_tgroup=concat(iso2 timegroup)
quietly levelsof country_tgroup, local(ctry_tg)
foreach c in `ctry_tg' {
	quietly sum series if country_tgroup=="`c'"
	quietly drop if country_tgroup=="`c'" & series!=r(max)
}

//Choose period
quietly keep if timegroup1995==1995
quietly egen nyears=count(year), by(country_series)
quietly keep if nyears>=6

//identify ctries in bpanel
quietly gen aux_bp=.
foreach c in `aux_bp' {
	replace aux_bp=1 if iso2=="`c'"
}
di `aux_bp'
	
graph twoway (line phi_g_HH year, lcolor(edkblue)) ///
	(line phi_g_corp year, lcolor(maroon)) ///
	(line phi_g_G year, lcolor(sand)) ///
	if aux_bp!=1 & iso2!="US" ///
	, by(country_series) yline(0, lcolor(black) lpattern(dot)) ///
	ytitle("Share of Total Capital Income (%)") xtitle("") ///
	xlabel(1995(5)2015, labsize(small) angle(horizontal) grid labels) ///
	ylabel(-10(20)80, labsize(small) angle(horizontal) grid labels) ///
	graphregion(color(white)) scale(1.2) legend(off)
	//text(58 2005  "Household Sector", color(edkblue)) ///
	//text(40 2005  "Private Corporations", color(maroon)) ///
	//text(8 2005  "Public Sector", color(sand)) ///
	graph export "figures/Phis_oth.pdf", replace
	
graph twoway (line phi_n_HH year, lcolor(edkblue)) ///
	(line phi_n_corp year, lcolor(maroon)) ///
	(line phi_n_G year, lcolor(sand)) ///
	if aux_bp!=1 & iso2!="US" ///
	, by(country_series) yline(0, lcolor(black) lpattern(dot)) ///
	ytitle("Share of Total Capital Income (%)") xtitle("") ///
	xlabel(1995(5)2015, labsize(small) angle(horizontal) grid labels) ///
	ylabel(-10(20)80, labsize(small) angle(horizontal) grid labels) ///
	graphregion(color(white)) scale(1.2) legend(off)
	//text(58 2005  "Household Sector", color(edkblue)) ///
	//text(40 2005  "Private Corporations", color(maroon)) ///
	//text(8 2005  "Public Sector", color(sand)) ///
	graph export "figures/NetPhis_oth.pdf", replace
	
graph twoway (line phi_n_hh year, lcolor(edkblue)) ///
	(line phi_n_cp year, lcolor(maroon)) ///
	if aux_bp!=1 & iso2!="US" ///
	, by(country_series) yline(0, lcolor(black) lpattern(dot)) ///
	ytitle("Share of Total Capital Income (%)") xtitle("") ///
	xlabel(1995(5)2015, labsize(small) angle(horizontal) grid labels) ///
	ylabel(-10(20)80, labsize(small) angle(horizontal) grid labels) ///
	graphregion(color(white)) scale(1.2) legend(off)
	//text(58 2005  "Household Sector", color(edkblue)) ///
	//text(40 2005  "Private Corporations", color(maroon)) ///
	//text(8 2005  "Public Sector", color(sand)) ///
	graph export "figures/NetPhis_oth.pdf", replace	

//Reshape data
quietly collapse (first) phi_1st_notG=phi_g_hh phi_1st_G=phi_g_HH ///
	phinet_1st_notG=phi_n_hh phinet_1st_G=phi_n_HH ///
	(last) phi_last_notG=phi_g_hh phi_last_G=phi_g_HH ///
	phinet_last_notG=phi_n_hh phinet_last_G=phi_n_HH ///
	(max) year_max=year (min) year_min=year, ///
	by (countryorarea iso2 series timegroup1995 /*timegroup*/)	
order countryorarea timegroup year_min year_max phi_1st_notG phi_last_notG

//New variables
quietly gen nyears=year_max-year_min
keep if nyears>=6

//w/o G (GROSS)
graph twoway (scatter phi_last_notG phi_1st_notG if timegroup1995==1995 & phi_1st_notG>phi_last_notG ///
	, mlabel(iso2) mcolor(maroon) mlabangle(horizontal) mlabsize(vsmall) mlabposition(0) msymbol(i) ///
	msize(vsmall) mlabcolor(maroon) mlabgap(0.75)) ///
	(scatter phi_last_notG phi_1st_notG if timegroup1995==1995 & phi_1st_notG<phi_last_notG ///
	, mlabel(iso2) mcolor(edkblue) mlabangle(horizontal) mlabsize(vsmall) msize(vsmall) ///
	mlabposition(0) msymbol(i) ///
	mlabcolor(edkblue)) (function y=x, range(20 90) lcolor(gs10)) ///
	, ytitle("Last Observation (%)") xtitle("First Observation (%)") ylabel(20(20)80, angle(horizontal)) ///
	xlabel(20(20)80, grid labels)  graphregion(color(white)) legend(off) ///
	//title("Evolution of the Household Share of Capital Income, Excluding Public Income 1995-2015")
quietly graph export "figures_apdx/Unbalanced1995-2015_notG.pdf", replace

//With G (GROSS)
graph twoway (scatter phi_last_G phi_1st_G if timegroup1995==1995 & phi_1st_G>phi_last_G ///
	, mlabel(iso2) mcolor(maroon) mlabangle(horizontal) mlabsize(vsmall) mlabposition(0) msymbol(i) ///
	msize(vsmall) mlabcolor(maroon) mlabgap(0.75)) ///
	(scatter phi_last_G phi_1st_G if timegroup1995==1995 & phi_1st_G<phi_last_G ///
	, mlabel(iso2) mcolor(edkblue) mlabangle(horizontal) mlabsize(vsmall) msize(vsmall) ///
	mlabposition(0) msymbol(i) ///
	mlabcolor(edkblue)) (function y=x, range(20 90) lcolor(gs10)) ///
	, ytitle("Last Observation (%)") xtitle("First Observation (%)") ylabel(20(20)80, angle(horizontal)) ///
	xlabel(20(20)80, grid labels)  graphregion(color(white)) legend(off)
	//title("Evolution of the Household Share of Capital Income, Excluding Public Income 1995-2015")
quietly graph export "figures/Unbalanced1995-2015_G.pdf", replace

//w/o G (NET)
graph twoway (scatter phinet_last_notG phinet_1st_notG if timegroup1995==1995 & phinet_1st_notG>phinet_last_notG ///
	, mlabel(iso2) mcolor(maroon) mlabangle(horizontal) mlabsize(vsmall) mlabposition(0) msymbol(i) ///
	msize(vsmall) mlabcolor(maroon) mlabgap(0.75)) ///
	(scatter phinet_last_notG phinet_1st_notG if timegroup1995==1995 & phinet_1st_notG<phinet_last_notG ///
	, mlabel(iso2) mcolor(edkblue) mlabangle(horizontal) mlabsize(vsmall) msize(vsmall) ///
	mlabposition(0) msymbol(i) ///
	mlabcolor(edkblue)) (function y=x, range(20 120) lcolor(gs10)) ///
	, ytitle("Last Observation (%)") xtitle("First Observation (%)") ylabel(20(20)120, angle(horizontal)) ///
	xlabel(20(20)125, grid labels)  graphregion(color(white)) legend(off)
	//title("Evolution of the Household Share of Capital Income, Excluding Public Income 1995-2015")
 quietly graph export "figures_apdx/UnbalancedNet1995-2015_notG.pdf", replace

//With G (NET)
graph twoway (scatter phinet_last_G phinet_1st_G if timegroup1995==1995 & phinet_1st_G>phinet_last_G ///
	& iso2!="HU" , mlabel(iso2) mcolor(maroon) mlabangle(horizontal) mlabsize(vsmall) mlabposition(0) msymbol(i) ///
	msize(vsmall) mlabcolor(maroon) mlabgap(0.75)) ///
	(scatter phinet_last_G phinet_1st_G if timegroup1995==1995 & phinet_1st_G<phinet_last_G ///
	, mlabel(iso2) mcolor(edkblue) mlabangle(horizontal) mlabsize(vsmall) msize(vsmall) ///
	mlabposition(0) msymbol(i) ///
	mlabcolor(edkblue)) (function y=x, range(20 120) lcolor(gs10)) ///
	, ytitle("Last Observation (%)") xtitle("First Observation (%)") ylabel(20(20)120, angle(horizontal)) ///
	xlabel(20(20)125, grid labels)  graphregion(color(white)) legend(off)
	//title("Evolution of the Household Share of Capital Income, Excluding Public Income 1995-2015")
quietly graph export "figures/UnbalancedNet1995-2015_G.pdf", replace

//Display results
local Gornot "notG G"
foreach g in `Gornot' {
	quietly count if phi_1st_`g'>phi_last_`g' & !missing(timegroup1995)
	local decr`g'=r(N)
	quietly count if phi_1st_`g'<phi_last_`g' & !missing(timegroup1995)
	local incr`g'=r(N)
	local decr_pct`g'=`decr`g''/(`incr`g''+`decr`g'')*100
	
	quietly count if phinet_1st_`g'>phinet_last_`g' & !missing(timegroup1995)
	local netdecr`g'=r(N)
	quietly count if phinet_1st_`g'<phinet_last_`g' & !missing(timegroup1995)
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
save `UNDATA' ,replace

*----------------------------------------------------------------------------*
* LIS-DATA																	 *
*----------------------------------------------------------------------------*

//Prepare to Handle old currencies in UNDATA	
import excel "Data/legacy-currency.xlsx", ///
	sheet("factors") firstrow clear	
quietly gen iso2=substr(LegacyOldCurrency,1,2)
quietly gen xrate=substr(ConversionfromEUR,8,8)	
quietly destring xrate, replace
quietly gen obs_yr=year(Obsolete)
keep iso2 xrate obs_yr
tempfile xrates_legacy 
save `xrates_legacy',replace

//Prepare lissy's currency-labels
import excel "Data/labels.xlsx" ///
	, sheet("Hoja1") firstrow clear
rename currency currency_lis	
tempfile curr_labels
save `curr_labels', replace

//Bring main dataset and define waves
import excel "Data/ccyy2.xlsx", ///
	sheet("Hoja1") firstrow clear	
quietly gen iso2=substr(ccyy,1,2)
quietly gen year=substr(ccyy,3,2)
destring year mean_toti, replace
drop if missing(mean_toti)
quietly replace year=year+1900 if year>=50
quietly replace year=year+2000 if year<50
quietly replace iso2=strupper(iso2)
quietly replace iso2="GB" if iso2=="UK"
quietly egen ctry_year=concat(iso2 year)

//Compare Kshares btw datasets 
preserve
quietly gen K_svy=(tot_K+tot_S*0.3)/tot_inc*100
quietly gen L_svy=(tot_L-tot_S*0.3)/tot_inc*100
quietly merge 1:m iso2 year using `save1st', keepusing(K K_net country_series phi_g_HH phi_n_HH)
keep if _merge==3
quietly gen K_alt=K*phi_g_HH/(K*phi_g_HH+(1-K))*100
quietly gen K_altnet=K_net*phi_n_HH/(K_net*phi_n_HH+(1-K_net))*100
quietly replace K=K*100
quietly gen K_n=K_net*100
quietly gen series=substr(country_series,3,.)
destring series, replace
quietly levelsof ctry_year, local(cyears)
foreach y in `cyears' {
	quietly sum series if ctry_year=="`y'"
	quietly drop if ctry_year=="`y'" & series!=r(max)
}

//GROSS
graph twoway (scatter K_svy K, mfcolor(none) msize(small)) ///
	(function y=x, range(0 60) lcolor(gs10)) if iso2!="CL" & iso2!="MX" /// 
	,xlabel(0(10)60, labsize(small) angle(horizontal) grid labels) ///
	ylabel(0(10)60, labsize(small) angle(horizontal) grid labels) ///
	ytitle("Survey's Figure (%)") xtitle("National Accounts' Figure (%)") ///
	legend(off) graphregion(color(white)) scale(1.2)
	quietly graph export "figures/KK.pdf", replace 
	
graph twoway (scatter K_svy K_alt, mfcolor(none) msize(small)) ///
	(function y=x, range(0 60) lcolor(gs10)) if iso2!="CL" & iso2!="MX" /// 
	,xlabel(0(10)60, labsize(small) angle(horizontal) grid labels) ///
	ylabel(0(10)60, labsize(small) angle(horizontal) grid labels) ///
	ytitle("Survey's Figure (%)") xtitle("National Accounts' Figure (%)") ///
	legend(off) graphregion(color(white)) scale(1.2)	
	quietly graph export "figures/KKalt.pdf", replace 
	
//NET	
graph twoway (scatter K_svy K_n, mfcolor(none) msize(small)) ///
	(function y=x, range(0 60) lcolor(gs10)) if iso2!="CL" & iso2!="MX" /// 
	,xlabel(0(10)60, labsize(small) angle(horizontal) grid labels) ///
	ylabel(0(10)60, labsize(small) angle(horizontal) grid labels) ///
	ytitle("Survey's Figure (%)") xtitle("National Accounts' Figure (%)") ///
	legend(off) graphregion(color(white)) scale(1.2)
	quietly graph export "figures/KKnet.pdf", replace 	

graph twoway (scatter K_svy K_altnet, mfcolor(none) msize(small)) ///
	(function y=x, range(0 60) lcolor(gs10)) if iso2!="CL" & iso2!="MX" /// 
	,xlabel(0(10)60, labsize(small) angle(horizontal) grid labels) ///
	ylabel(0(10)60, labsize(small) angle(horizontal) grid labels) ///
	ytitle("Survey's Figure (%)") xtitle("National Accounts' Figure (%)") ///
	legend(off) graphregion(color(white)) scale(1.2)	
	quietly graph export "figures/KKaltnet.pdf", replace 

quietly sort iso2 year	
graph twoway (line K K_alt K_n year), by(iso2)	///
	graphregion(color(white)) plotregion(lcolor(bluishgray)) scale(1.2) ///
	scheme(s1color) subtitle(,fcolor(white) lcolor(bluishgray))
quietly graph export "figures_apdx/KperCtry.pdf", replace 

levelsof iso2, separate(,)
codebook iso2
count if !missing(K, K_svy)

restore

//
quietly egen wave=cut(year), at(1967, 1979, 1983, 1988, 1993, 1998, 2003, 2006, 2009, 2012, 2015, 2017) icodes
quietly egen wave_yr=cut(year), at(1967, 1979, 1983, 1988, 1993, 1998, 2003, 2006, 2009, 2012, 2015, 2017) 

//Drop AT years without data 
quietly drop if ccyy=="at94" | ccyy=="at95"

//Keep 1 year per wave 
quietly egen year_frq=count(year), by(year) 
quietly gen wave_pop_yr=.
quietly levelsof wave, local(waves)
foreach w in `waves'{
	quietly sum year_frq if wave==`w'
	quietly sum year if wave==`w' & year_frq==r(max)
	quietly replace wave_pop_yr=r(max) if wave==`w'
}
quietly gen dist_to_popyear=abs(wave_pop_yr-year)

quietly egen ctry_wave=concat(iso2 wave)
quietly levelsof ctry_wave, local(ctry_waves)
foreach cw in `ctry_waves'{
	quietly sum dist_to_popyear if ctry_wave=="`cw'"
	quietly drop if ctry_wave=="`cw'" & dist_to_popyear!=r(min) 
}
quietly egen test1=count(year), by(ctry_wave)
foreach cw in `ctry_waves'{
	quietly sum year if ctry_wave=="`cw'" & test1>1
	quietly drop if year!=r(max) & ctry_wave=="`cw'" & test1>1
}

//declare panel
drop if missing(wave)
quietly encode iso2, gen(ctry_id)
xtset ctry_id wave
xtdescribe, patterns(20) 

//Select balanced panel
drop if tot_inc==0
quietly gen aux1=0
quietly replace aux1=1 if wave>=4 & wave<=9
quietly egen test2=sum(aux1) if !missing(aux1) ,by(iso2)
quietly gen aux_bp=0
quietly replace aux_bp=1 if test2==6 & wave>=4 & wave<=9 
quietly replace aux_bp=1 if iso2=="US"

//quietly keep if aux_bp==1

//Allow NL and HU to merge data with the closest year (for surveys in 1994 & 1993)
preserve
quietly use `save1st', clear 
quietly replace year=1993 if iso2=="NL" & year==1995
quietly replace year=1994 if iso2=="HU" & year==1995
tempfile save2nd
quietly save `save2nd', replace   
restore 

//Merge with unbalanced data from UN
quietly merge 1:m iso2 year using `save2nd', keepusing(LI NI_g NI_n country_series phi_g_HH phi_n_HH K K_net currency_sna)
quietly drop if _merge==2 | _merge==1
sort iso2 country_series year
quietly destring tot_L tot_K tot_S t10_L t10_K t10_S t1_L t1_K t1_S defl totw mean_toti, replace

//Keep most recent series by year
quietly gen series=substr(country_series,3,.)
destring series, replace
quietly levelsof ctry_year, local(cyears)
foreach y in `cyears' {
	quietly sum series if ctry_year=="`y'"
	quietly drop if ctry_year=="`y'" & series!=r(max)
}

//Drop Countries with insufficient SNA
quietly egen aux_bp2=count(K) if aux_bp==1, by(iso2) 
//drop if aux2!=6 & iso2!="US"
//drop aux2

//Merge with lissy currency-labels
quietly merge m:1 ccyy using `curr_labels' , generate(_merge2)

//Merge with legacy-xrates data (transform to EUR)
quietly merge m:1 iso2 using `xrates_legacy', generate(_merge3)
local varstoreplace "tot_inc tot_L tot_K tot_S b50_L b50_K b50_S m40_L m40_K m40_S t10_L t10_K t10_S t1_L t1_K t1_S mean_toti"
foreach v in `varstoreplace' {
	quietly replace `v'=`v'/xrate if year<obs_yr & !missing(obs_yr) & currency_lis!="[978]EUR - Euro" 
}

//Merge with xrates (yearly) data, to USD
quietly merge m:m iso2 year using `xrates_yr', generate(_merge4)
keep if _merge4==3

//Transform to market USD (yearly)
local toreplace "NI_g NI_n tot_inc tot_K tot_S tot_L LI b50_L b50_K b50_S m40_L m40_K m40_S t10_L t10_K t10_S t1_L t1_K t1_S "
foreach t in `toreplace' {
	quietly replace `t'=`t'/xrateama
}

//Create variables
quietly gen KI_svy=(tot_K+0.3*tot_S) 
quietly gen LI_svy=(tot_L-0.3*tot_S) 

quietly gen KI_HH=phi_g_HH*K*NI_g
quietly gen ki_h_svy=KI_svy/NI_g
quietly gen ki_h_na=K*phi_g_HH
quietly gen li_svy=LI_svy/NI_g
quietly gen li_na=LI/NI_g

quietly gen LI_n=(1-K_net)*NI_n
quietly gen KI_HH_n=phi_n_HH*K_net*NI_n
quietly gen ki_h_svy_n=KI_svy/NI_n
quietly gen ki_h_na_n=K_net*phi_n_HH
quietly gen li_svy_n=LI_svy/NI_n
quietly gen li_na_n=LI_n/NI_n

//EPSILON
quietly gen epsiK=KI_svy/KI_HH*100
quietly gen epsiL=LI_svy/LI*100
quietly gen ratio=epsiK/epsiL*100

quietly gen epsiKnet=KI_svy/KI_HH_n*100
quietly gen epsiLnet=LI_svy/LI_n*100
quietly gen ratio_net=epsiKnet/epsiLnet*100
sort iso2 year,stable

//Clean
drop _merge*
drop if missing(ratio)
kountry iso2, from(iso2c) to(iso3n) geo(undet)
//drop if series!=1000

sort iso2 year
label var epsiK "Gross Capital Income ({&epsilon}{sub:K})"
label var epsiL "Labor Income ({&epsilon}{sub:L})"
label var ratio "{&epsilon}{sub:K}/{&epsilon}{sub:L}"
label var epsiKnet "Net Capital Income ({&epsilon}{sub:K})"
label var epsiLnet "Labor Income ({&epsilon}{sub:L})"
label var ratio_net "{&epsilon}{sub:K}/{&epsilon}{sub:L}"

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
	quietly graph export "figures_apdx/EpsiByCtry.pdf", replace 
	
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
	quietly graph export "figures_apdx/EpsiNetByCtry.pdf", replace 

graph twoway (line epsiKnet wave_pop_yr, lcolor(edkblue)) ///
	(line epsiLnet wave_pop_yr, lcolor(maroon)) ///
	(line ratio_net  wave_pop_yr, lcolor(gs10)) ///
	if iso2!="US" & iso2=="DK" & aux_bp==1 & aux_bp2==6 ///
	, by(iso2) ytitle("Share of Total Factor Income Captured (%)") xtitle("") ///
	xlabel(1995(5)2015, labsize(small) angle(horizontal) grid labels) ///
	ylabel(60(20)180, labsize(small) angle(horizontal) grid labels)  ///
	graphregion(color(white)) plotregion(lcolor(bluishgray)) scale(1.2) ///
	scheme(s1color) subtitle(,fcolor(white) lcolor(bluishgray))
	quietly graph export "figures_apdx/EpsiNetByCtryDK.pdf", replace 	

//Historical Series	
quietly gen histo=.
quietly replace histo=1 if iso2=="US" | iso2=="CA" | iso2=="FI" | iso2=="FR" | iso2=="IT" | iso2=="NL"	

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
	quietly graph export "figures_apdx/EpsiByCtry_histo.pdf", replace   
	
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
quietly graph export "figures_apdx/NetEpsiByCtry_histo.pdf", replace   	

	
quietly gen latam=.
quietly replace latam=1 if iso2=="CL" | iso2=="MX" 
graph twoway (line epsiK wave_pop_yr, lcolor(edkblue)) ///
	(line epsiL wave_pop_yr, lcolor(maroon)) ///
	(line ratio  wave_pop_yr, lcolor(gs10)) ///
	if latam==1 ///
	, by(iso2) ytitle("Share of Total Factor Income Captured (%)") xtitle("") ///
	xlabel(1995(5)2015, labsize(small) angle(horizontal) grid labels) ///
	ylabel(0(20)80, labsize(small) angle(horizontal) grid labels)  ///
	graphregion(color(white)) plotregion(lcolor(bluishgray)) scale(1.2) ///
	scheme(s1color) subtitle(,fcolor(white) lcolor(bluishgray))
	quietly graph export "figures_apdx/EpsiByCtry_latam.pdf", replace   	

//Gross/Net definition
tempvar aux1
quietly gen `aux1'=", "
quietly egen income_def=concat(grossnet `aux1' grossnet2)
tab iso2 income_def

//GAMMA
quietly gen gamma=phi_g_HH*ratio 
quietly gen gamma_net=phi_n_HH*ratio_net 

preserve
quietly replace K=K*100
quietly replace K_net=K_net*100
quietly replace phi_g_HH=phi_g_HH*100

graph twoway (line gamma wave_pop_yr) ///
	(line K wave_pop_yr) if iso2!="US" & aux_bp==1 & aux_bp2==6  ///
	, by(iso2) ///
	xlabel(1995(5)2015, labsize(small) angle(horizontal) grid labels) ///
	ylabel(10(10)40, labsize(small) angle(horizontal) grid labels)  ///
	graphregion(color(white)) plotregion(lcolor(bluishgray)) scale(1.2) ///
	ytitle("(%)") xtitle("") legend(label(1 "{&gamma}") label(2 "Gross Capital Share")) ///
	scheme(s1color) subtitle(,fcolor(white) lcolor(bluishgray))
		quietly graph export "figures_apdx/KGammaByCtry.pdf", replace 
		
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
	quietly graph export "figures_apdx/DecGammaByCtry.pdf", replace 		
	
graph twoway (line gamma_net wave_pop_yr) ///
	(line K_net wave_pop_yr) if iso2!="US" & aux_bp==1 & aux_bp2==6  ///
	, by(iso2) ///
	xlabel(1995(5)2015, labsize(small) angle(horizontal) grid labels) ///
	ylabel(10(10)60, labsize(small) angle(horizontal) grid labels)  ///
	graphregion(color(white)) plotregion(lcolor(bluishgray)) scale(1.2) ///
	ytitle("(%)") xtitle("") ///
	scheme(s1color) subtitle(,fcolor(white) lcolor(bluishgray))
quietly graph export "figures_apdx/NetKGammaByCtry.pdf", replace 
restore

//S_K and S_L
local group "b50 m40 t10 t1"
foreach g in `group'{
	quietly gen S`g'_K=(`g'_K+`g'_S*0.3)/(tot_K+tot_S*0.3)
	quietly gen S`g'_L=(`g'_L-`g'_S*0.3)/(tot_L-tot_S*0.3)
	quietly gen S`g'=(`g'_L+`g'_K)/(tot_L+tot_K)
	quietly gen Dif_`g'=S`g'_K-S`g'_L
	foreach geo in `geo_r'{		 
	}
}


preserve
local toch "St1_K St1_L St1"
foreach v in `toch' {
replace `v'=`v'*100
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
	quietly graph export "figures_apdx/SqByCtry.pdf", replace 	
restore	
//Tests of consistency
/*
quietly gen test_t1=((St1_K*gamma*K)+(St1_L*(1-K)))/(gamma*K+(1-K))
quietly gen testing=St1-test_t1
quietly replace testing=round(testing, 0.00001)
levelsof testing

quietly egen test11=rowtotal(b50_L b50_K m40_L m40_K t10_L t10_K)
quietly replace test11=test11/tot_inc
replace test11=round(test11, 0.001)
levelsof test11
*/
//BALANCED PANEL -----------------------------------------------------------------*

//Save info

tempfile randomname3
quietly save `randomname3', replace
quietly levelsof iso2 if iso2!="US" & aux_bp==1 & aux_bp2==6, local (all_ctries)

// Balanced Panel and US separately	
local ctrygrp "BPanel US `all_ctries'"
foreach cg in `ctrygrp' {
	use `randomname3', clear
	quietly gen KI_n=NI_n*K_net
	if ("`cg'"=="BPanel") {
		quietly drop if iso2=="US" | aux_bp!=1 | aux_bp2!=6 
		quietly levelsof wave_pop_yr, local(w_years)
		foreach y in `w_years'{
			quietly sum NI_g if wave_pop_yr==`y'
			scal scal_NItot_`y'=r(sum)
		}
		quietly collapse (sum) NI_g NI_n tot_K tot_S tot_L ///
			b50_L b50_K b50_S ///
			m40_L m40_K m40_S ///
			t10_K t10_L t10_S ///
			t1_K t1_L t1_S ///
			KI_svy LI_svy LI KI_n KI_HH, by (wave_pop_yr)	
	}
	if ("`cg'"=="US") {
		keep if iso2=="US"
	}
	
	if ("`cg'"!="BPanel" & "`cg'"!="US") {
		quietly drop if iso2=="US" | aux_bp!=1 | aux_bp2!=6
		keep if iso2=="`cg'"
	}
	
	keep NI_g NI_n tot_K tot_S tot_L b50_L b50_K b50_S m40_L m40_K m40_S t10_K t10_L t10_S t1_K t1_L t1_S KI_svy LI_svy LI KI_n KI_HH wave_pop_yr
	
	//Create variables
	quietly gen ki_h_svy=KI_svy/NI_g
	quietly gen ki_h_na=KI_HH/NI_g
	quietly gen li_svy=LI_svy/NI_g
	quietly gen li_na=LI/NI_g
	quietly gen KI=NI_g-LI
	quietly gen K=KI/NI_g
	quietly gen K_net=KI_n/NI_n
	quietly gen Phi_h=KI_HH/KI

	//EPSILON
	quietly gen epsiK=KI_svy/KI_HH
	quietly gen epsiL=LI_svy/LI
	quietly gen ratio=epsiK/epsiL
	quietly gen K_svy=KI_svy/(KI_svy+LI_svy)*100

	//Top 1% of each country put together
	local group "b50 m40 t10 t1"
	foreach g in `group'{
		quietly gen S`g'_K=(`g'_K+`g'_S*0.3)/(tot_K+tot_S*0.3)
		quietly gen S`g'_L=(`g'_L-`g'_S*0.3)/(tot_L-tot_S*0.3)
		quietly gen S`g'=(`g'_L+`g'_K)/(tot_L+tot_K)
		quietly gen Dif_`g'=S`g'_K-S`g'_L
	}
	
	//GAMMA
	quietly gen gamma=ratio*Phi_h
	
	//Save data for contrib analysis
	tempfile tf_`cg'
	quietly save `tf_`cg'', replace
	
	//Mutliply by 100
	local mult_var "St10 St10_L St10_K St1 St1_L St1_K K_svy K K_net Sm40 Sm40_K Sm40_L Sb50 Sb50_K Sb50_L epsiL epsiK ratio gamma Phi_h"
	foreach v in `mult_var' {
		quietly replace `v'=`v'*100
	}
	
	if ("`cg'"=="BPanel" | "`cg'"=="US") {
		if ("`cg'"=="BPanel") {
			local min_yr=1995
		}
		if ("`cg'"=="US") {
			local min_yr=1975
			export excel using "Tables/Tables.xlsx"	,firstrow(variables) sheet("infoUS") sheetreplace	
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
			text(5 1997  "Labor", color(maroon)) ///
			graphregion(color(white)) scale(1.2) legend(off)
			quietly graph export "figures/St1_`cg'.pdf", replace			
			
		//Income concentration
		graph twoway (line St10 wave_pop_yr, lcolor(gray) lpattern(dash)) ///
			(line St10_K wave_pop_yr, lcolor(edkblue)) ///
			(line St10_L wave_pop_yr, lcolor(maroon)) ///
			, ytitle("Top 10%'s share of Factor Income (%)") xtitle("") ///
			xlabel(`min_yr'(5)2015, labsize(small) angle(horizontal) grid labels) ///
			ylabel(10(10)50, labsize(small) angle(horizontal) grid labels) ///
			text(37 2013  "Total", color(gray)) ///
			text(48 2013  "Capital", color(edkblue)) ///
			text(30 2013  "Labor", color(maroon)) ///
			graphregion(color(white)) scale(1.2) legend(off)
			quietly graph export "figures/St10_`cg'.pdf", replace

		//K and Gamma
		graph twoway (line K wave_pop_yr, lcolor(edkblue)) ///
			(line gamma wave_pop_yr, lcolor(maroon)) ///
			, ytitle("(%)") xtitle("") ///
			xlabel(`min_yr'(5)2015, labsize(small) angle(horizontal) grid labels) ///
			ylabel(10(10)70, labsize(small) angle(horizontal) grid labels) ///
			text(41 2013  "Capital Share", color(edkblue)) ///
			text(17 2013  "{&gamma}", color(maroon)) ///
			graphregion(color(white)) scale(1.2) legend(off)
			quietly graph export "figures/KGamma_`cg'.pdf", replace
			
		graph twoway (line gamma wave_pop_yr, lcolor(gs10)) ///
			(line Phi_h wave_pop_yr, lcolor(edkblue)) ///
			(line ratio wave_pop_yr, lcolor(maroon)) ///
			, ytitle("(%)") xtitle("") ///
			xlabel(`min_yr' 1975(5)2015, labsize(small) angle(horizontal) grid labels) ///
			ylabel(0(10)70, labsize(small) angle(horizontal) grid labels) ///
			graphregion(color(white)) scale(1.2) ///
			legend(label(1 "{&gamma}") label(2 "{&Phi}{subscript:h}") label(3 "{&epsilon}{sub:K}/{&epsilon}{sub:L}"))
			quietly graph export "figures/DecGamma_`cg'.pdf", replace
		
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
			text(75 2011  "Labor Income ({&epsilon}{sub:L})", color(edkblue)) ///
			text(15 2011  "Capital Income ({&epsilon}{sub:K})", color(maroon)) ///
			text(32 2014  "{&epsilon}{sub:K}/{&epsilon}{sub:L}", color(gs10)) ///
			graphregion(color(white)) scale(1.2) legend(off)
		quietly graph export "figures/Epsilon_`cg'.pdf", replace
	}	
}

//Analyze contributions to change --------------------------------------------//
	local iter=1
foreach cg in `ctrygrp'{
	use `tf_`cg'', clear
	//DERIVATIVES
	quietly gen d_K=(gamma*(St1_K-St1_L))/(K*gamma+(1-K))^2
	quietly gen d_St1_L=(1-K)/(gamma*K+(1-K))
	quietly gen d_St1_K=(gamma*K)/(gamma*K+(1-K))
	quietly gen d_gamma=(K*(1-K)*(St1_K-St1_L))/(gamma*K+(1-K))^2
	quietly gen d_phi=(K*(1-K)*ratio*(St1_K-St1_L))/(gamma*K+(1-K))^2
	quietly gen d_ratio=(K*(1-K)*Phi_h*(St1_K-St1_L))/(gamma*K+(1-K))^2
	quietly gen countryorarea="`cg'"

	//Save table of derivatives
	preserve
	local dev_vars "d_K d_St1_L d_St1_K d_gamma d_phi d_ratio"
	quietly collapse (mean) `dev_vars', by(countryorarea) 
	foreach v in `dev_vars' {
		quietly format %9.2f `v'
	}
	if (`iter'==1) {
		tempfile tf_base_d
		quietly save `tf_base_d'
	}
	if (`iter'==0) {
		append using `tf_base_d'
		quietly save `tf_base_d', replace
	}
	restore
	
	quietly rename Phi_h phi
	//Deltas and Effects
	local deltavars "K St1_K St1_L gamma phi ratio"
	foreach v in `deltavars' {
		quietly gen v_`v'=`v'-`v'[_n-1] if _n!=1
		quietly gen e_`v'=v_`v'*d_`v'[_n-1] if _n!=1
	}
	quietly replace e_gamma=e_phi+e_ratio
	quietly gen St1_AgEf=e_K+e_St1_K+e_St1_L+e_phi+e_ratio
	quietly gen St1_est=St1[_n-1]+St1_AgEf 
	
	//contribution in period
	quietly collapse (sum) e_K e_St1_K e_St1_L e_gamma e_phi e_ratio ///
		(last) St1_est_last=St1_est St1_last=St1 ///
		(first) St1_first=St1, by(countryorarea)  
	quietly gen actual_var=St1_last-St1_first
	quietly egen e_tot=rowtotal(e_K e_St1_K e_St1_L e_gamma)
	quietly gen est_error=e_tot-actual_var
	quietly keep countryorarea e_K e_St1_K e_St1_L e_gamma e_phi e_ratio e_tot actual_var est_error
	
	//
	local pct_vars "e_K e_St1_K e_St1_L e_gamma e_phi e_ratio e_tot actual_var est_error"
	foreach v in `pct_vars' {
		quietly replace `v'=`v'*100
		quietly format %9.1f `v'
	}
	
	//Save or append 
	if (`iter'==1) {
		tempfile tf_base
		quietly save `tf_base'
	}
	local iter=0
	if (`iter'==0) {
		append using `tf_base'
		quietly save `tf_base', replace
	}
}

//Save tables 
use `tf_base' , clear 
quietly replace countryorarea="Q_BPanel" if countryorarea=="BPanel"
sort countryorarea
quietly collapse (first) `pct_vars', by(countryorarea)
export excel using "Tables/Tables.xlsx"	,firstrow(variables) sheet("Contributions_t1") sheetreplace	

use `tf_base_d' , clear 
quietly replace countryorarea="Q_BPanel" if countryorarea=="BPanel"
sort countryorarea
quietly collapse (first) `dev_vars', by(countryorarea)
export excel using "Tables/Tables.xlsx"	,firstrow(variables) sheet("Derivatives_t1") sheetreplace	

	//Plots
	//graph twoway (line St10 St10_est wave_pop_yr)

//---------------------------------------------------------------------------//
//Analyze structure 
use `randomname3', clear
quietly drop if iso2=="US"
quietly gen NI_share=.
foreach y in `w_years' {
	replace NI_share=NI_g/scal_NItot_`y'*100 if wave_pop_yr==`y'
}

quietly encode iso2, gen(iso2_id)
quietly xtset iso2_id wave_yr
xtline NI_share 
//graph export "figures_apdx/Phi_structure.pdf", replace

//On average  
quietly collapse (mean) NI_share, by(iso2)
quietly egen test=total(NI_share)
quietly sort NI_share
quietly format %9.1f NI_share
quietly gen auxi=_n

//Table on average structure
quietly gsort -NI_share	
quietly gen cumshare=sum(NI_share)
format %9.1f cumshare
keep iso2 NI_share cumshare
