
//Loopy loops
foreach s in "t1" "t10" "m40" "b50" {
	foreach t in "Deriv" "Contrib" {
	
		//Get 1 line of US tax data and save for later (P&S2003) 
		if inlist("`s'", "t1", "t10") {

			//define cell range
			if "`s'" == "t1" & "`t'" == "Deriv" local cellr "A2:G3"
			if "`s'" == "t10" & "`t'" == "Deriv" local cellr "A7:G8"
			if "`s'" == "t1" & "`t'" == "Contrib" local cellr "I2:S3"
			if "`s'" == "t10" & "`t'" == "Contrib" local cellr "I7:S8"
		
			//Import
			qui import excel "Data/US/PikettySaez.xlsx", ///
				sheet("input tables") ///
				firstrow cellrange(`cellr') clear
			
			//Format	
			qui ds, has(type numeric)
			foreach v in `r(varlist)' {
				qui replace `v' = round(`v', 0.01)
				qui tostring `v', replace format(%03.2f) force
			}
			capture replace blank = "" if blank == "."
			
			//Save
			tempfile tf2_`t'_`s' 
			qui save `tf2_`t'_`s''
		}
		
		//Get DINA Results and save for later (PSZ 2018)
		qui import excel using "Data/US/PSZ2017MainData.xlsx" ///
			,firstrow sheet("ExtractoPSZ2017") cellrange(A3:AH105) clear 	
		qui keep if Year >= 1974

		if "`t'" == "Deriv" {
			//get partial derivative of Sq L & K
			qui gen d_S`s'_K = K 
			qui gen d_S`s'_L = 1 - K
			qui collapse d_K_`s' d_S`s'_*
			qui ds, has(type numeric)
			foreach v in `r(varlist)' {
				qui replace `v' = round(`v', 0.01)
				qui tostring `v', replace format(%03.2f) force
			}	
			qui gen Country = "DINA"
			tempfile tfDINA_`t'_`s' 
			qui save `tfDINA_`t'_`s''	
		}
		
		if "`t'" == "Contrib" {
			//if "`t'" == "Contrib" & "`s'" == "b50" exit 1
			qui collapse  (sum) e_K_`s' e_S`s'_L e_S`s'_K ///
				(first) `s'_1st = `s' e_tot_1st=e_tot_`s' ///
				(last) `s'_last = `s' e_tot_last=e_tot_`s'
				
			qui gen actual_var = `s'_last - `s'_1st
			qui gen e_tot = e_tot_last - e_tot_1st
			qui gen est_error = actual_var - e_tot
			drop `s'_1st `s'_last e_tot_1st e_tot_last
			
			qui ds 
			local varli `r(varlist)'
			foreach v in `varli' {
				qui replace `v' = `v' * 100
				qui replace `v' = round(`v', 0.01)
				qui tostring `v', replace format(%03.2f) force
			}
		qui gen Country = "DINA"
		qui gen blank = ""
		tempfile tfDINA_`t'_`s' 
		qui save `tfDINA_`t'_`s''	
		}
		
		//Get data from Surveys (Main Do-file)
		if "`t'" == "Contrib" local cellr2 "A1:J14"
		if "`t'" == "Deriv" local cellr2 "A1:G14"
		qui import excel "tables/Tables.xlsx",  cellrange(`cellr2') ///
			sheet("`t'_`s'") firstrow clear

		//Format	
		qui ds, has(type numeric)
		foreach v in `r(varlist)' {
			qui replace `v' = round(`v', 0.01)
			qui tostring `v', replace format(%03.2f) force
		}
		
		//Deal with missing values
		ds, not(type numeric) 
		foreach v in `r(varlist)' {
			qui replace `v' = "" if `v' == "."
		}

		//Get name of variables
		qui ds Country, not 
		local vars "`r(varlist)'" 
		
		//Get country names 
		qui replace Country = subinstr(Country, " ", "_",.)
		qui levelsof Country , local(countries)
			
		//Remember values 	
		foreach c in `countries' {
			foreach v in `vars' {
				qui levelsof `v' if Country == "`c'", local(`c'_`v')
			}
		}
	
		//Make room for titles
		local N = _N
		qui drop in 2/`N'
		
		//Write part of header for derivatives
		if ("`t'" == "Deriv") {
			qui replace Country = ""
			qui replace d_K_`s' = "[1]" in 1
			qui replace d_S`s'_L = "[2]" in 1
			qui replace d_S`s'_K = "[3]" in 1
			qui replace d_phi_`s' = "[4]" in 1
			qui replace d_rat_`s' = "[5]" in 1
			qui replace d_gam_`s' = "[6]" in 1
		}
		
		//Erase header in Contrib
		if ("`t'" == "Contrib") {
			qui ds Country, not 
			local list "`r(varlist)'" 
			foreach v in `list' {
				qui replace `v' = "" in 1
			}
		}
 		
		//Define starting obs for table
		if "`t'" == "Contrib" local start = 1
		if "`t'" == "Deriv" local start = 2
		
		//Make room
		local nN = `N' + `start' + 1 
		qui set obs `nN'
		
		//Fill everything again
		if ("`t'" == "Deriv") {
			qui replace Country = "\hline Panel (1995--2013):" in `start'
		}
		if ("`t'" == "Contrib") {
			qui replace Country = "Panel (1995--2013):" in `start'
		} 
		local n = `start' + 1 
		foreach c in `countries' {
			if ("`c'" != "United_States") {
			qui replace Country = "`c'" in `n'
			local n = `n' + 1
			}
		}
		
		//Deal with the US
		local rep_n = `start' + 13
		local rep_n2 = `start' + 14
		qui replace Country = "\hline U.S. (1974--2011):" in `rep_n'
		qui replace Country = "Survey" in `rep_n2'
		foreach v in `vars' {
			foreach c in `countries' {
				qui replace `v' = ``c'_`v'' if Country == "`c'"
			}
			qui replace `v' = `United_States_`v'' if Country == "Survey"
		}
		
		//Append data from tax series 
		if inlist("`s'", "t1", "t10") qui append using `tf2_`t'_`s''
		
		//Append DINA results
		qui append using `tfDINA_`t'_`s''	
		
		//Make beautiful
		qui levelsof Country if Country != "\hline Panel (1995--2013):" ///
			& Country != "\hline U.S. (1974--2011):" & Country != "" ///
			,local (countries)
		qui replace Country = "Total:" if Country == "q_bpanel"	
		foreach c in `countries'{
			qui replace Country = "---`c'" if Country == "`c'" 
		}
		qui replace Country = subinstr(Country, "_", " ",.)
		
		//Order
		if ("`t'" == "Contrib") {
			capture qui gen blank = ""
			order Country e_K_`s' e_S`s'_L  e_S`s'_K e_phi_`s' ///
				 e_rat_`s' e_gam_`s' blank e_tot actual_var est_error
		//More order	 
		}
		if ("`t'" == "Deriv") {
			order Country d_K_`s' d_S`s'_L d_S`s'_K d_phi_`s' ///
				d_rat_`s' d_gam_`s' 
		}
		
		//Save
		listtab * using "tables/`s'_`t'.tex", rstyle(tabular) replace 
	}
}


