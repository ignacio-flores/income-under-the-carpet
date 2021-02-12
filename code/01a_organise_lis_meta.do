
//Variable-availability---------------------------------------------------------
import excel "Data/LIS/our-lis-documentation-availability-matrix.xlsx", ///
	sheet("All Waves as of 22-Oct-2019") cellrange(A6:ID16) firstrow clear
quietly drop if strpos(VariableLabel, "person")	
	
//clean strings
ds, has(type numeric)
local ctry_yrs `r(varlist)'
keep `ctry_yrs' Category
quietly replace Category = subinstr(Category, " ", "", .)

//long shape
foreach var in `ctry_yrs'{
	rename `var' dum`var'
}
quietly reshape long dum, i(Category) j(country_year) string

//Split country and year
split country_year
quietly gen iso = substr(country_year, 1,2)
quietly gen year = substr(country_year, 3,4)
destring year, replace
quietly replace year = year + 1900 if year >= 50
quietly replace year = year + 2000 if year < 50
drop country_year
sort iso Category year 

//3 letter names 
kountry iso, from(iso2c) to(iso3c)
quietly rename _ISO3C_ Country
quietly replace Country="GBR" if iso == "UK"

//Keep balanced panel, clean
drop if year < 1995
drop if dum == 0
drop if Category == "IncomeAggregates"
keep Category year Country

//Define Waves
quietly egen wave_yr=cut(year), ///
	at(1993, 1998, 2003, 2006, 2009, 2012, 2015, 2017) 

//Reshape manually
tostring wave_yr, replace
levelsof wave_yr, local(yrs)
foreach y in `yrs' {
	quietly gen y`y'=1 if wave_yr == "`y'"
}
sort Category Country
collapse (firstnm) y* ,by(Category Country)

//Save table for each variable
quietly levelsof Category, local(items)
foreach i in `items' {
	preserve 
		keep if Category=="`i'"
		drop year Category
		quietly rename (y*) (I II III IV V VI VII)
		ds, has(type numeric)
		local waves "`r(varlist)'"
		tostring `waves', replace
		foreach w in `waves' {
			quietly replace `w' = "x" if `w' == "1"
			quietly replace `w' = "" if `w' == "."
		}

		//Send to tex doc
		listtab using "tables/`i'.tex", rstyle(tabular) ///
			head("\begin{tabular}{lccccccc}" `"Country & I & II & III & IV & V & VI & VII \\  \hline "') ///
			foot("\hline \end{tabular}") replace
	restore 
}


//Metadata----------------------------------------------------------------------
//Select items
quietly import excel "Data/LIS/our-lis-documentation.xlsx", firstrow clear
quietly rename A item 
quietly keep if inlist(item, "Coverage", "Sampling procedure", ///
	"Collection mode", "Non-response error", "Item non-response / imputation" ///
	, "Taxes and contributions", "Description of instruments")
	
//Reshape	
foreach x in " " "/" "-" { 	
	quietly replace item = subinstr(item, "`x'", "",.)
} 
	
//Convert to long	
quietly ds item, not
local ctry_yrs "`r(varlist)'"
foreach cy in `ctry_yrs' {
	quietly rename `cy' description`cy'
}
quietly reshape long description, i(item) j(country_year) string

//split country_year
quietly gen iso = substr(country_year, 1,2)
quietly gen year = substr(country_year, 3,4)
destring year, replace
quietly replace year = year + 1900 if year >= 50
quietly replace year = year + 2000 if year < 50
drop country_year
sort iso item year 

//Prepare for meta tables 
quietly replace description = lower(description)
kountry iso, from(iso2c) to(iso3c)
quietly rename _ISO3C_ Country
quietly replace Country="GBR" if iso == "UK"

//Identify Gross or Net reporting of income ------------------------------------
preserve  
	quietly collapse (min) min_year = year (max) max_year = year ///
		if item =="Taxesandcontributions", by(Country description)
	foreach exp in "net" "gross"  { 
		quietly gen coll_`exp' = .
		quietly replace coll_`exp' = 1 if ///
			strpos(description, "collected `exp'") 
		quietly gen rec_`exp' = .
		quietly replace rec_`exp' = 1 if ///
			strpos(description, "recorded' `exp'") 	
		quietly gen coll2_`exp' = 1 if ///
			strpos(description, "the `exp' income was")
	}

	foreach exp in "modelled" "modeled" "simulated" "imputation" "both" ///
	"imputed" "algorithm" "while" {
		quietly gen `exp' = .
		quietly replace `exp' = 1 if strpos(description, "`exp'") 
	}
	
	//Define categories
	quietly gen desc = "No Info." if description == "-"
	
	//Gross, some simulations
	quietly replace desc = "Gross, at least partly simulated" ///
		if coll_gross == 1 & (!mi(modelled) | !mi(modeled) | ///
		!mi(simulated) | !mi(imputation) | !mi(imputed))
	quietly replace desc = "Gross, at least partly simulated" ///
		if mi(desc) & (!mi(modeled))
	quietly replace desc = "Gross, at least partly simulated" ///
		if mi(desc) & (!mi(imputation))	
		
	//Reported gross	
	quietly replace desc = "Reported Gross" if mi(desc) & (!mi(coll_gross) ///
		| !mi(rec_gross)) 
	quietly replace desc = "Reported Gross" if mi(desc) & !mi(coll2_gross)	
	quietly replace desc = "Reported Gross" if mi(desc) & mi(while) ///
		& !mi(both) & Country!="EST"
		
	//Reported gross with exeptions
	quietly replace desc = "Reported gross with exeptions" if mi(desc) & ///
		!mi(while)
	
	order desc description
restore	
	

//Identify use of register or administrative data ------------------------------
//preserve
	quietly gen marker = .
	foreach exp in "register" "administrative" "tax records" { 
		quietly replace marker = 1 if ///
		(item =="Collectionmode" | item == "Descriptionofinstruments" ///
		| item == "Taxesandcontributions") & strpos(description, "`exp'") 
	}
	
	//Build table
	collapse marker (min) min_year=year (max) max_year=year ///
		if (item=="Collectionmode" | item == "Descriptionofinstruments" ///
		| item == "Taxesandcontributions") ///
		& marker ==1, by(Country)
	quietly egen Period = concat(*year), punct(" - ")
	quietly order Country Period
	quietly keep Country Period
	//clean
	drop if inlist(Country, "CHL", "CHE", "ST", "FRA", "LUX", "NOR", "SWE", "SVN")
	
	//Send to tex doc
	listtab using "tables/register.tex", rstyle(tabular) ///
		head("\begin{tabular}{cc}" `"Country & Period\\  \hline "') ///
		foot("\hline \end{tabular}") replace

//restore 

	
