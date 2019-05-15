{smcl}
{* *! version 1.2.1  07mar2013}{...}
{findalias asfradohelp}{...}
{vieweralsosee "" "--"}{...}
{vieweralsosee "[R] help" "help help"}{...}
{viewerjumpto "Syntax" "examplehelpfile##syntax"}{...}
{viewerjumpto "Description" "examplehelpfile##description"}{...}
{viewerjumpto "Options" "examplehelpfile##options"}{...}
{viewerjumpto "Remarks" "examplehelpfile##remarks"}{...}
{viewerjumpto "Examples" "examplehelpfile##examples"}{...}
{title:Title}

{phang}
{bf:randassign} {hline 2} Perform randomizations


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:randassign}
[{bf:if} {it:exp}]
{cmd:,}
{opth gen:erate(newvar)}
{opth prob:abilities(numlist)}
[{it:options}]

{synoptset 20 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Main}
{synopt:{opth gen:erate(newvar)}}specify name of treatment status variable{p_end}
{synopt:{opth prob:abilities(numlist)}}specify allocation fractions for each group{p_end}

{syntab:Randomization details}
{synopt:{opth block(varname)}}blocks for stratified randomization{p_end}
{synopt: {opth clus:ter(varname)}}cluster variable for clustered randomization{p_end}
{synopt: {opt seed(integer)}}specify randomization seed{p_end}
{synopt: {opt overrule}}allow blocks without all treatment statuses{p_end}

{syntab:Output and formatting}
{synopt:{opt lab:els(string)}}names of treatmet arms, to be used as value labels, seperated by commas{p_end}
{synopt:{opt str:ings(string)}}names of treatmet arms, to be used as string values, seperated by commas{p_end}
{synopt:{opt countf:rom(integer)}}specify numeric value for first treatment group, default is 0{p_end}
{synopt:{opth val:ues(numlist)}}specify values for each treatment group in ordered list{p_end}

{syntab:Balance}
{synopt: {opth bali:ndiv(varlist)}}specify individual-level varaibles on which check randomization balance{p_end}
{synopt: {opth balc:luster(varlist)}}specify cluster-level variables on which to check randomization balance{p_end}

{synoptline}
{p2colreset}{...}
{p 4 6 2}


{marker description}{...}
{title:Description}

{pstd}
{cmd:randassign} randomizes the sample into groups, with allocation fractions
spedified by {opt probabilities}. It will perform clustered randomizations specified in {opt cluster}, 
and also can perform stratified randomizations within levels of {opt block}. The command can also perform
baseline balance checks.


{marker options}{...}
{title:Options}

{dlgtab:Main}

{phang}
{opth gen:erate(newvar)} generates a new variable {newvar} with the treatment statuses.

{phang}
{opth prob:abilities(numlist)} specifies the relative sizes of each treatment arm. For example, 
for two groups of equal size, specify prob(.5 .5). If probabilities do not add up to 1, the command
will display a warning message and use relative sizes. Therefore, prob(.5 .5) and prob(1 1) will give the same result.

{dlgtab: Randomization details}

{phang}
{opth block(varname)} specifies a variable to be used as a block variable for stratification. Randomization will be
performed only within each level specified. If you specify blocks small enough that some levels will not have all treatment
statuses, you will get an error. To allow blocks without all treatment statuses, specify {opt overrule}. If you do not specify
this option, the randomization will not be stratified.

{phang}
{opth clus:ter(varname)} specifies a variable within which to cluster randomization. Each unique level
of this variable will be randomized together. If you specify {opt cluster} and {opt blocks}, all
observations in each cluster must have the same values of the block variable. If you do not specify this option,
randomization will not be clustered.

{phang}
{opt seed(integer)} specifies the seed for the randomization. If you do not specify a seed, one is randomly selected 
and returned as a stored value to be accessed later.

{phang}
{opt overrule} allows randomization blocks without all treatment statuses.

{dlgtab:Ouptut and formatting}

{phang}
{opt lab:els(string)} specifies value labels for each level of the treatment status, in the order of {opt probabilities}. Labels
should be seperated by commas. If you specify this option, there must be the same number of labels as treatment groups.

{phang}
{opt str:ings(string)} functions the same as labels, except that it results in a string output variable in stead of a labeled numeric.

{phang}
{opt countf:rom} specifies the value for the first treatment status, counting up by 1 for subsequent groups, in the order that they
are listed in {opt probabilities}. The default is 0.

{phang}
{opth val:ues(numlist)} specifies values for each treatment in order. For example, if you specify prob(.25 .75) val(50 100), for approximately
25% of the observations, the treatment variable will take on value 50, and for the remaining observations it will take value 100. You cannot
specify both this option and {opt countfrom}.

{dlgtab:Balance}

{phang}
{opth bali:ndiv(varlist)} produces a balance table for differences across groups within randomization
blocks on specified variables. Also, it displays binomial probabilities of seeing the observed number
of rejected null hypotheses if all tests were independent. Comparisons will be relative to the first group
listed in {opt probabilities}, so it makes sense to list a control group first if you will specify the balance option. 
This option should not be used for cluster-level variables; see {opt balc:luster}.

{phang}
{opth balc:luster(varlist)} functions the same way as {opt bali:ndiv}, but is used for cluster-level variables. You
may want to check balance on variables that are necessarily the same across clusters, such as the cluster size, etc. In this case,
you want to compare only one observation per cluster across experimental groups. Specifying {opt balc:luster} is the equivalent to
specifying {opt bali:ndiv} on a variable with only 1 non-missing observation per cluster, which you can also do manually. You can 
only specify this option with {opt cluster}.

{phang}
Note that re-randomizing is generally not a best practice, so these options should be used with caution.



{marker examples}{...}
{title:Examples}

Load the data. Extract from 1988 U.S. National Longitudinal Study of Young Women.
{phang}{cmd: sysuse nlsw88, clear}{p_end}

Randomize the sample into treatment or control, stratifying on college graduation. Check balance on age, race, and marital status.
{phang}{cmd: randassign, gen(treatment) prob(.25 .75) labels(Control, Treatment) block(collgrad) balindiv(age race married)}{p_end}

Randomize treated women to receive various incentives.
{phang}{cmd: randassign if treatment == 1, gen(incentive) prob(.2 .2 .2 .2 .2) values(10 20 30 40 50)}{p_end}

{title:Installation}

You can download the most recent version from github:
{phang}{cmd: net install randassign, from(https://raw.githubusercontent.com/johndentmarshall/randassign/master/) replace}

{title:Stored results}

{bf: randassign} stored the following results in {bf:r():}

	Scalars
		{bf:r(seed)}		seed used for the randomization
		{bf:r(p10)} 		probability of finding k or greater tests significant at 10% level in balance checks
		{bf:r(p05)} 		probability of finding k or greater tests significant at 5% level in balance checks
		{bf:r(p01)} 		probability of finding k or greater tests significant at 1% level in balance checks
		
		where k is the observed number of rejected null hypotheses at a given level.
		
	Matrices
		{bf:r(balance)}		balance table


{title:Author}
	John Marshall
	Precision Agriculture for Development
	jmarshall@precisionag.org
