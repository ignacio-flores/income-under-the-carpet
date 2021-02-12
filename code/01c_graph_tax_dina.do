//DINA--------------------------------------------------------------------------

quietly import excel using ///
	"Data/US/PSZ2017MainData.xlsx", ///
	sheet("ExtractoPSZ2017") cellrange(A3:S105) firstrow clear
	
//Format variables 
foreach v in "t10" "St10_K" "St10_L" {
	quietly replace `v' = `v' * 100
	quietly format %2.0f `v'
}	

//Graph	
graph twoway (line t10 Year, lcolor(gray) lpattern(dash)) ///
	(line St10_K Year, lcolor(edkblue)) ///
	(line St10_L Year, lcolor(maroon)) if Year >= 1975 ///
	, ytitle("Top 10%'s share of Factor Income (%)") xtitle("") ///
	xlabel(1975(5)2015, labsize(small) angle(horizontal) grid labels) ///
	ylabel(20(10)80, labsize(small) angle(horizontal) grid labels) ///
	text(52 2013  "Total", color(gray)) ///
	text(78 2013  "Capital", color(edkblue)) ///
	text(40 2013  "Labor", color(maroon)) ///
	graphregion(color(white)) scale(1.2) legend(off)
quietly graph export "figures/St10_US_DINA.pdf", replace 
	
//Bring data
quietly import excel using "Data/US/PikettySaez.xlsx", ///
	sheet("Resumen") firstrow clear

	
//TAX DATA ---------------------------------------------------------------------
	
//Format variables 
foreach v in "Gammatax" "gamma_svy" "K" ///
	"Sq10_tax" "St10_K" "Sq10_L" ///
	"EpsilonK" "EpsilonL" "Ratio" {
	quietly replace `v' = `v' * 100
	quietly format %2.0f `v'
}

//Gamma and Capital Share
graph twoway (line Gammatax Year if Year >= 1975 ///
	, lcolor(erose) lpattern(dash)) ///
	(line gamma_svy year, lcolor(maroon))  ///
	, ytitle("Gamma coefficient (%)") xtitle("") ///
	xlabel(1975(5)2015, labsize(small) angle(horizontal) grid labels) ///
	ylabel(0(10)40, labsize(small) angle(horizontal) grid labels) ///
	text(12 2015  "Survey", color(maroon)) ///
	text(27 2007  "Tax", color(erose)) ///
	graphregion(color(white)) scale(1.2) legend(off)
quietly graph export "figures/KGammaUS2.pdf", replace 
	
//Top 10% Share Tax
graph twoway (line Sq10_tax Year, lcolor(gray) lpattern(dash)) ///
	(line St10_K Year, lcolor(edkblue)) ///
	(line Sq10_L Year, lcolor(maroon)) if Year >= 1975 ///
	, ytitle("Top 10%'s share of Factor Income (%)") xtitle("") ///
	xlabel(1975(5)2015, labsize(small) angle(horizontal) grid labels) ///
	ylabel(20(10)80, labsize(small) angle(horizontal) grid labels) ///
	text(52 2013  "Total", color(gray)) ///
	text(78 2013  "Capital", color(edkblue)) ///
	text(40 2013  "Labor", color(maroon)) ///
	graphregion(color(white)) scale(1.2) legend(off)
quietly graph export "figures/St10_UStax.pdf", replace 

//Epsilon in Tax Data
graph twoway (line EpsilonL Year, lcolor(edkblue)) ///
	(line EpsilonK Year, lcolor(maroon)) ///
	(line Ratio  Year, lcolor(gs10)) ///
	if Year >= 1975 ///
	, ytitle("Share of Total Factor Income Captured (%)") xtitle("") ///
	xlabel(1975(5)2015, labsize(small) angle(horizontal) grid labels) ///
	ylabel(0(20)100, labsize(small) angle(horizontal) grid labels)  ///
	graphregion(color(white)) plotregion(lcolor(bluishgray)) scale(1.2) ///
	text(85 2010  "Labor Income ({&epsilon}{sub:L})", color(edkblue)) ///
	text(20 2010  "Capital Income ({&epsilon}{sub:K})", color(maroon)) ///
	text(32 2014  "{&epsilon}{sub:K}/{&epsilon}{sub:L}", color(gs10)) ///
	scheme(s1color) subtitle(,fcolor(white) lcolor(bluishgray)) legend(off)
quietly graph export "figures/Epsilon_UStax.pdf", replace 

