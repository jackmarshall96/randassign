program define randomize, rclass
		
	* Main steps:
		* Parse syntax.
		* Prepare data for randomization.
		* Implement randomization.
		* Implement balance checks.
		* Return stored results.
		
		
	/***************************************
	Parse syntax.
	****************************************/
	
	* Define syntax.
	syntax , gen(string) groups(string asis) PROBabilities(numlist) [cluster(varname)] [block(varname)] [balance(varlist)] ///
		[seed(numlist max=1 integer)] [overrule]
		
	* Parse group names.
	local remaining = `"`groups'"'
	local counter = 1
	while strlen(`"`remaining'"') > 0 {
		gettoken group`counter' remaining: remaining, parse(",")
		if substr(`"`remaining'"', 1, 1) == "," {
			local remaining = substr(`"`remaining'"', 2, strlen(`"`remaining'"') - 1)
		}
		local counter = `++counter'
	}
	local num_groups = `counter' - 1
	
	* Parse probabilities.
	local counter = 1
	foreach p in `probabilities' {
		local prob`counter' = `p'
		local new_probs "`new_probs', `prob`counter''"
		local counter = `++counter'
	}
	local new_probs = substr("`new_probs'", 3, strlen("`new_probs'") - 2)
	
	* Check that probabilities add up to 1.
	local probsum = subinstr("`new_probs'", ",", "+", .)
	local probsum = `probsum'
	cap assert `probsum' == 1
	if _rc != 0 {
		di as error "WARNING: Probabilities do not add up to 1. Relative sizes will be used."
	}
	
	* Check that there are the same number of groups and probabilities.
	cap assert `num_groups' == `counter' - 1
	if _rc != 0 {
		di as error "Must specify the same number of groups and probabilities."
		exit
	}
	
	* Scale probabilities to integers.
	local min = min(`new_probs')
	while mod(`min', 1) != 0 {
		local new_probs = ""
		forvalues i = 1/`num_groups' {
			local prob`i' = `prob`i'' * (1/`min')
			local new_probs "`new_probs', `prob`i''"
		}
		local new_probs = substr("`new_probs'", 3, strlen("`new_probs'") - 2)
		local min = min(`new_probs')
	}
	
	local sum = subinstr("`new_probs'", ",", " +", .)
	local total = `sum'
	

	/***************************************
	Prepare data for randomization.
	****************************************/
	
	* Save the sort and order of the dataset.
	tempvar roworder
	qui gen `roworder' = _n
	qui ds
	local colorder = "`r(varlist)'"
	
	
	/* Collapse by clustervar. If no clustervar is specified,
	cluster is defined as one cluster for each individual, which
	is equivalent to individual-level randomization. */
	if `"`cluster'"' == "" {
		tempvar cluster
		qui gen `cluster' = `roworder'
	}
	
	* Save long format data in a tempfile.
	tempfile whole
	qui save `whole'
	
	* Define blocks.
	if `"`block'"' == "" {
		tempvar block
		qui gen `block' = 1
	}
	
	* Make sure that blocks are constant witin clusters.
	qui bysort `cluster': egen test = sd(`block')
	cap assert test == 0 | test == .
	if _rc != 0 {
		di as error "Block variable must be constant within clusters."
		qui exit
	}
	
	* Collapse the data to the cluster level.
	collapse (first) `block' `balance', by(`cluster')
		
	* Check that there are enough clusters per block.
	preserve
		gen temp = 1
		bysort `block': egen clusters = sum(temp)
		drop temp
		
		cap assert clusters >= `sum'
		if _rc != 0 & `"`overrule'"' == "" {
			di as error "The stratification blocks are too small to randomize all treatments. Adjust blocks or specify overrule WITH CAUTION."
			qui exit
		}
		else if `"`overrule'"' != "" {
			di as error "WARNING: You have specified stratification blocks that are too small."
		}
	restore
	
	
	
	/*************************************** 
	Implement the randomization.
	****************************************/
	
	* Set seed and generate random variables.
	if `"`seed'"' == "" {
		local seed = subinstr("`c(current_time)'", ":", "", .)
	}
	
	tempvar rand1 rand2
	set seed `seed'
	gen `rand1' = runiform()
	local seed2 = `seed' + 1
	set seed `seed2'
	gen `rand2' = runiform()
	
	* Sort within blocks.
	tempvar temp1 temp2 temp3 lastpart
	qui gen `temp1' = .
	qui bysort `block' (`rand1'): replace `temp1' = mod(_n, `total') + 1
	
	* Randomly assign treatments to mods.
	qui bysort `block' (`rand1'): gen `lastpart' = (_n > `total')
	qui bysort `block' (`lastpart' `rand2'): gen `temp2' = _n if `lastpart' == 0
	qui gen `temp3' = `temp1'
	forvalues i = 1/`total' {
		qui by `block': replace `temp3' = `i' if `temp1' == `temp1'[`i']
	}

	* Combine treatments together based on probabilities.
	qui gen `gen' = .
	local counter = 0
	foreach p in `new_probs' {
		qui replace `gen' = `counter' if `temp3' <= `p'
		qui replace `temp3' = . if `temp3' <= `p'
		qui replace `temp3' = `temp3' - `p'
		
		local counter = `++counter'
	}
	
	* Label values of treatment variable.
	local lab_command = "lab def `gen'_lab "
	forvalues i = 1/`num_groups' {
		local val = `i' - 1
		local lab_command = `"`lab_command' `val' `"`group`i''"'"'
	}
	`lab_command'
	lab val `gen' `gen'_lab
	
	* Restore the data to the original.
	keep `gen' `cluster'
	qui merge 1:m `cluster' using `whole'
	assert _merge == 3
	drop _merge
	sort `roworder'
	order `colorder'
	
	/***************************************
	Balance checks.
	****************************************/
	if "`balance'" != "" {
	
		* Prepare matrix.
		local rows: word count `balance'
		matrix define estimates = J(`rows', `num_groups', .)
		matrix define pvals = J(`rows', `num_groups' - 1, .)
		
		* Estimate differences between groups.
		local r = 1
		local comparisons = `num_groups' - 1
		foreach v of varlist `balance' {
	
			qui areg `v' i.`gen', absorb(`block') cluster(`cluster')
			
			forvalues i = 0/`comparisons' {
			
				qui sum `v' if `gen' == `i'
				matrix estimates[`r', `i' + 1] = `r(mean)'
				if `i' > 0 {
					qui test `i'.`gen' = 0
					matrix pvals[`r', `i'] = `r(p)'
				}
			}
			
			local r = `++r'
		}
		forvalues i = 1/`comparisons' {
			local colnames = `"`colnames' "P-val. (`++i') = (1)""'
		}
		
		* Format matrix
		matrix balance = estimates, pvals
		local groupnames = subinstr("`groups'", ",", "", .)
		matrix colnames balance = `groupnames' `colnames'
		matrix rownames balance = `balance'
		
		* Calculate binomial probabilities.
		matrix p_01 = J(`rows', `num_groups' - 1, .01)
		matrix p_05 = J(`rows', `num_groups' - 1, .05)
		matrix p_1 = J(`rows', `num_groups' - 1, .1)
		local tests = `rows' * (`num_groups' - 1)

		mata: pvals = st_matrix("pvals")
		mata: p_01 = st_matrix("p_01")
		mata: p_05 = st_matrix("p_05")
		mata: p_1 = st_matrix("p_1")
		mata: p_l_01 = pvals :< p_01
		mata: p_l_05 = pvals :< p_05
		mata: p_l_1 = pvals :< p_1
		mata: num_l_01 = sum(p_l_01)
		mata: num_l_05 = sum(p_l_05)
		mata: num_l_1 = sum(p_l_1)
		mata: st_numscalar("num_l_01", num_l_01)
		mata: st_numscalar("num_l_05", num_l_05)
		mata: st_numscalar("num_l_1", num_l_1)
		
		local num_l_01 = num_l_01
		local num_l_05 = num_l_05
		local num_l_1 = num_l_1
		
		qui bitesti `tests' `num_l_01' .01
		local p_l_01 = round(`r(p_u)', .01)
		qui bitesti `tests' `num_l_05' .05
		local p_l_05 = round(`r(p_u)', .01)
		qui bitesti `tests' `num_l_1' .1
		local p_l_1 = round(`r(p_u)', .01)
	}
	

	
	/***************************************
	Return stored results.
	****************************************/
	* Output.
	di ""
	di as result "Randomization results:"
	di ""
	di as result" - Variable `gen' generated:"
	tab `gen'
	di ""
	di as result " - Base seed used for randomization : `seed'"
	di ""
	if `"`balance'"' != "" {
		di as result " - Randomization balance:"
		matrix list balance
		di ""
		di as result " - Binomial probabilities for k rejected null hypotheses:"
		di as result "       Pr(k >= `num_l_1') at the 10% level: `p_l_1'"
		di as result "       Pr(k >= `num_l_05') at the 5% level: `p_l_05'"
		di as result "       Pr(k >= `num_l_01') at the 1% level: `p_l_01'"
		
		return scalar p01 = `p_l_01'
		return scalar p05 = `p_l_05'
		return scalar p10 = `p_l_1'
		return matrix balance = balance
	}
end

