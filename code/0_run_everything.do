///////////////////////////////////////////////////////////////////////////////
//																			 //
//																			 //
//  			   THE CAPITAL SHARE AND INCOME INEQUALITY 	 				 //
//			            	Ignacio Flores (2021)							 //
//				    Goal: Runs every dofile in the project					 //
//																		     //
///////////////////////////////////////////////////////////////////////////////

macro drop _all 
clear all

//general settings  
global mydirectory ~/Dropbox/ForGitHub/Under_the_carpet/
qui cd "${mydirectory}code/"

//list codes 
**********************************************************

global n_cat = 2
global do_codes1 " "01a" "01b" "01c" "
global do_codes2 " "02a" "02b" "

**********************************************************

//report and save start time 
local start_t "($S_TIME)"
di as result "Started running everything at `start_t'"

//prepare list of do-files 
forvalues n = 1 / 2 {

	//get do-files' name 
	foreach docode in ${do_codes`n'} { 
	
		local do_name : dir . files "`docode'*.do" 
		global doname_`docode' `do_name'
		
	}
}	


//loop over all files  
forvalues n = 1/2 {
	foreach docode in ${do_codes`n'} {
	
		//always confirm directory
		qui cap cd "${mydirectory}"
		
		****************************
		do "code/${doname_`docode'}"
		****************************
		
		//record time
		global do_endtime_`docode' " - ended at ($S_TIME)"
		
		//remember work plan
		di as result "{hline 70}" 
		di as result "list of files to run, started at `start_t'"
		di as result "{hline 70}"
		forvalues x = 1/2 {
			di as result "Stage nº`x'"
			foreach docode2 in ${do_codes`x'} {
				di as text "  * " "${doname_`docode2'}" _continue
				di as text " ${do_endtime_`docode2'}"
			}
			if `x' == 2 di as result "{hline 70}"	
		}
	}
}

