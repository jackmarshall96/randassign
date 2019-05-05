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
	syntax [if/], GENerate(string) PROBabilities(numlist min=2) [LABels(string asis)] [STRings(string asis)] [CLUSter(varname)] [block(varname)] ///
		[seed(numlist max=1 integer)] [overrule] [COUNTFrom(numlist integer max=1)] [VALues(numlist)] [BALCluster(varlist numeric)] ///
		[BALIndiv(varlist numeric)]
	
	
	
	/* Parse probabilities. To do this, we will scale all probabilities up to integers.
	This will take the following main steps. 
		- Parse local into different versions for each operation (space, comma, and + seperated).
		- Logical checks (probs add to 1, correct number of groups).
		- Find the smallest probability.
		- Multiply all probabilities by the minimum, so the smallest is 1.
		- Iterate through each probability and check prob % 1. If this is not 0.
			then scale all probabilities up by (1/(prob % 1). */
	
	* Parse into different versions.
	local counter = 1
	foreach p in `probabilities' {
		local prob`counter' = `p'
		local commas "`commas', `prob`counter''"
		local counter = `++counter'
	}
	local commas = substr("`commas'", 3, strlen("`commas'") - 2)
	local pluses = subinstr("`commas'", ",", "+", .)

	* Logical checks - probabilities should add to 1. Otherwise, display warning.
	local probsum = `pluses'
	cap assert `probsum' == 1
	if _rc != 0 {
		di as error "WARNING: Probabilities do not add up to 1. Relative sizes will be used."
	}
	
	* Calculate minimum and scale probabilities so that the smallest number is 1.
	local min = min(`commas')
	local num_groups: word count `probabilities'
	forvalues i = 1/`num_groups' {
		local prob`i' = `prob`i'' * (1/`min')
	}
	
	* Iterate through probabilities, scaling by mod.
	forvalues i = 1/`num_groups' {
		if mod(`prob`i'', 1) != 0 {
			local multiplier = 1/mod(`prob`i'', 1)
			forvalues j = 1/`num_groups' {
				local prob`j' = `prob`j'' * `multiplier'
			}
		}
	}
	
	* Calculate the total of the scaled probabilities.
	local total = 0
	forvalues i = 1/`num_groups' {
		local total = `total' + `prob`i''
	}
	
	* Parse group names.
	cap assert `"`labels'"' == "" | `"`strings'"' == ""
	if _rc != 0 {
		di as error "Cannot specify both labels and strings."
		exit 198
	}
	
	if `"`strings'"' != "" {
		local labels = `"`strings'"'
	}
	
	if `"`labels'"' != "" {
		local remaining = `"`labels'"'
		local counter = 1
		while strlen(`"`remaining'"') > 0 {
			gettoken label`counter' remaining: remaining, parse(",")
			if substr(`"`remaining'"', 1, 1) == "," {
				local remaining = substr(`"`remaining'"', 2, strlen(`"`remaining'"') - 1)
			}
			local counter = `++counter'
		}
		cap assert `num_groups' == `counter' - 1
		if _rc != 0 {
			di as error "Must specify the same number of groups and probabilities."
			exit 198
		}
	}
	
	* Check that strings and values are not both specified.
	cap assert `"`strings'"' == "" | `"`values'"' == ""
	if _rc != 0 {
		di as error "Cannot specify both strings and values."
		exit 198
	}
	* Check that values and countfrom are not both specified.
	cap assert `"`values'"' == "" | `"`countfrom'"' == ""
	if _rc != 0 {
		di as error "Cannot specify both values and countfrom."
		exit 198
	}
	
	* Update countfrom to 0 if it is missing (default, but added here to allow previous step).
	if `"`countfrom'"' == "" {
		local countfrom = 0
	}
	
	* Check that the number of values is correct.
	if `"`values'"' != "" {
		local num_values: word count `values'
		cap assert `num_values' == `num_groups'
		if _rc != 0 {
			di as error "Cannot specify different numbers of probabilities and values."
			exit 198
		}
	}
	
	* Fill in values if it is missing.
	else if `"`values'"' == "" {
		local counter = `countfrom'
		forvalues i = 1/`num_groups' {
			local values `values' `counter++'
		}
	}
	
	* Cannot specify balcluster without cluster.
	cap assert "`cluster'" != "" | "`balcluster'" == ""
	if _rc != 0 {
		di as error "Cannot specify balcluster without cluster."
		exit 198
	}
	
	* Cannot have overlapping variables in balindiv and balcluster.
	if "`balcluster'" != "" & "`balindiv'" != "" {
		local words: word count `balcluster'
		forvalues i = 1/`words' {
			local word: word `i' of `balcluster'
			cap assert strpos(" `balindiv' ", " `word' ") == 0
			if _rc != 0 {
				di as error "Cannot have the same variable in balcluster and balindiv."
				exit 198
			}
		}
	}
	
	local specified_cluster = ("`cluster'" != "")
	
	/***************************************
	Prepare data for randomization.
	****************************************/
	
	* Save the sort and order of the dataset.
	tempvar roworder
	qui gen `roworder' = _n
	qui ds
	local colorder = "`r(varlist)'"
	
	
	/* If no clustervar is specified, cluster is defined as one cluster for each individual, which
	is equivalent to individual-level randomization. */
	if `"`cluster'"' == "" {
		tempvar cluster
		qui gen `cluster' = `roworder'
	}
	
	* If there is no block, make a tempvar to allow for balance checks to work properly later.
	if `"`block'"' == "" {
		tempvar block
		qui gen `block' = 1
	}
	
	* Save long format data in a tempfile.
	tempfile whole
	qui save `whole'
	
	* Allow for string block variables.
	cap confirm numeric variable `block'
	if _rc != 0 {
		local block_orig `block'
		tempvar block
		encode `block_orig', gen(`block')
	}
	
	* Make sure that blocks are constant witin clusters.
	tempvar test
	qui bysort `cluster': egen `test' = sd(`block')
	cap assert `test' == 0 | `test' == .
	if _rc != 0 {
		di as error "Block variable must be constant within clusters."
		exit 459
	}
	
	* Limit the sample to only selected observations.
	if `"`if'"' != "" {
		qui keep if `if'
	}
	
	* Collapse the data to the cluster level.
	collapse (first) `block' `balance', by(`cluster')
		
	* Check that there are enough clusters per block.
	preserve
		tempvar temp
		gen `temp' = 1
		bysort `block': egen clusters = sum(`temp')
		drop `temp'
		
		cap assert clusters >= `total'
		if _rc != 0 & `"`overrule'"' == "" {
			di as error "The stratification blocks are too small to randomize all treatments. Adjust blocks or specify overrule WITH CAUTION."
			exit 459
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
		local seed = runiformint(10000, 99999)
	}
	local seed2 = `seed' + 1
	local seed3 = `seed' + 2
	
	tempvar rand1 rand2
	set seed `seed'
	gen `rand1' = runiform()
	set seed `seed2'
	gen `rand2' = runiform()
	
	* Sort within blocks.
	tempvar temp1 temp2
	qui gen `temp1' = .
	qui bysort `block' (`rand1'): replace `temp1' = mod(_n, `total') + 1
	
	qui order_treatments `block' `temp1' `temp2' `total' `seed3'

	* Combine treatments together based on probabilities.
	qui gen `generate' = .
	forvalues i = 1/`num_groups' {
		local value: word `i' of `values'
		qui replace `generate' = `value' if `temp2' <= `prob`i''
		qui replace `temp2' = . if `temp2' <= `prob`i''
		qui replace `temp2' = `temp2' - `prob`i''
	}
	
	* Convert to string values if string() is specified.
	if `"`strings'"' != "" {
		qui rename `generate' `generate'_old
		qui gen `generate' = ""
		local counter = 1
		foreach i in `values' {
			local str = `"`label`counter++''"'
			qui replace `generate' = `"`str'"' if `generate'_old == `i'
		}
		qui drop `generate'_old
	}

	* Label values of treatment variable.
	else if `"`labels'"' != "" {
		local counter = 1
		local tool replace
		foreach i in `values' {
			lab def `generate' `i' `"`label`counter++''"', `tool'
			local tool add
		}
		lab val `generate' `generate'
	}
	

	* Restore the data to the original.
	keep `generate' `cluster' `block'
	qui merge 1:m `cluster' using `whole', nogen
	sort `roworder'
	order `colorder'

	* Update treatment variable to missing if outside of if/in.
	if `"`if'"' != "" {
		cap replace `generate' = . if !(`if')
		if _rc != 0 {
			cap replace `generate' = "" if !(`if')
		}
	}
	
	/***************************************
	Balance checks.
	****************************************/
	if "`balcluster'" != "" {
	
		tempvar tag
		qui egen `tag' = tag(`cluster')
		foreach v of varlist `balcluster' {
		
			* Check that it is actually a group-level variable.
			tempvar `v'_mean
			qui bysort `cluster': egen ``v'_mean' = mean(`v')
			cap assert `v' == ``v'_mean'
			if _rc != 0 & `specified_cluster' == 0 {
				di as error "`v' is not consistent within cluster variable. If you want to include it, use balanceindividual."
				exit 459
			}
			
			* Create a version with only 1 non-missing observation per cluster.
			tempvar `v'_tag
			qui gen ``v'_tag' = `v' if `tag'
			local balcluster_tag `balcluster_tag' ``v'_tag'
		}
	}
	
	if "`balindiv'" != "" & `specified_cluster' {
		foreach v of varlist `balindiv' {
			tempvar `v'_mean
			qui bysort `cluster': egen ``v'_mean' = mean(`v')
			cap assert `v' == ``v'_mean'
			if _rc == 0 {
				di as error "WARNING: `v' has the same levels within all clusters. Did you mean to include it in balancecluster?"
			}
		}
	}
	
	if "`balcluster'" != "" | "`balindiv'" != "" {
		
		* Combine varlist.
		local balance `balindiv' `balcluster_tag'
		
		* Prepare matrix.
		local rows: word count `balance'
		matrix define estimates = J(`rows', `num_groups', .)
		matrix define pvals = J(`rows', `num_groups' - 1, .)
		
		* Estimate differences between groups.
		local r = 1
		foreach v of varlist `balance' {

			qui areg `v' i.`generate', absorb(`block') cluster(`cluster')
			
			local c = 1
			foreach i in `values' {
				qui sum `v' if `generate' == `i'
				matrix estimates[`r', `c'] = `r(mean)'
				if `c' > 1 {
					qui test `i'.`generate' = 0
					matrix pvals[`r', `c' - 1] = `r(p)'
				}
				
				local c = `++c'
			}
			
			local r = `++r'
		}
		
		local comparisons = `num_groups' - 1
		forvalues i = 1/`comparisons' {
			local colnames = `"`colnames' "pval (`++i')=(1)""'
		}
		
		* Format matrix
		if `"`labels'"' == "" {
			local counter = 1
			foreach i in `values' {
				local word: word `counter++' of `values'
				local labels "`labels' `generate'=`i'"
			}
		}
		matrix balance = estimates, pvals
		local groupnames = subinstr("`groups'", ",", "", .)
		matrix colnames balance = `labels' `colnames'
		matrix rownames balance = `balindiv' `balcluster'
		
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
	di as result" - Variable `generate' generated:"
	tab `generate'
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
		
		return scalar seed = `seed'
		return scalar p01 = `p_l_01'
		return scalar p05 = `p_l_05'
		return scalar p10 = `p_l_1'
		return matrix balance = balance
	}
end

* Program to randomly assign treatment statuses to each group.
program define order_treatments

	* Define arguements.
	args block oldvar newvar levels seed

	* Save current data as a tempfile.
	tempfile randdata
	save `randdata'

	* Collapse data by the block variable.
	collapse (firstnm) `oldvar', by(`block')
	
	* Expand the data to the number of treatment statuses.
	expand `levels'
	bysort `block': replace `oldvar' = _n
	
	* Generate random variable and sort.
	set seed `seed'
	tempvar rand
	gen `rand' = runiform()
	by `block' (`rand'): gen `newvar' = _n
	
	* Merge with full randomization data and update statuses.
	tempvar mergevar
	merge 1:m `block' `oldvar' using `randdata', gen(`mergevar')
	assert `mergevar' != 2
	keep if `mergevar' == 3

end
