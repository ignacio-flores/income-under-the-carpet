//Retrieve data
wid, indicators(ansdep agdpro) ages(999) clear
quietly egen ctry_year=concat(country year)
quietly replace variable="gdp" if variable=="agdpro999i"
quietly replace variable="dep" if variable=="ansdep999i"

//Reshape
reshape wide value, i(ctry_year) j(variable) string 
quietly rename valuegdp gdp
quietly rename valuedep dep
quietly keep if !missing(gdp, dep)

//Create main variable
quietly gen dep_gdp=dep/gdp*100

//Graph
graph twoway (line dep_gdp year) if year>=1950 ///
	, by(country) ytitle("% of GDP") xtitle("") ///
	xlabel(1950(10)2015, labsize(small) angle(45) grid labels) ///
	ylabel(0(10)30, labsize(small) angle(horizontal) grid labels) ///
	graphregion(color(white)) plotregion(lcolor(bluishgray)) scale(1.2) ///
	scheme(s1color) subtitle(,fcolor(white) lcolor(bluishgray))
graph export "~/Dropbox/Aplicaciones/Overleaf/Income under the Carpet/figures_apdx/All_Kdep.pdf", replace
graph export "~/Dropbox/Aplicaciones/Overleaf/Income under the Carpet/figures_apdx/All_Kdep.png", replace
