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
{bf:randomize} {hline 2} Perform randomizations


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:randomize}
{cmd:,}
{opth gen:erate(newvar)}
{opth groups(string)}
{opth prob:abilities(numlist)}
[{it:options}]

{synoptset 20 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Main}
{synopt:{opth gen:erate(newvar)}}specify name of treatment status variable{p_end}
{synopt:{opth groups(string)}}names of treatmet arms, seperated by commas{p_end}
{synopt:{opth blocks(varname)}}blocks for stratified randomization{p_end}
{synopt: {opth cluster(varname)}}cluster variable for clustered randomization{p_end}
{synopt: {opth seed(integer)}}specify randomization seed{p_end}
{synopt: {opt randomseed}}automatically set seed{p_end}
{synopt: {opth balance(varlist)}}specify varlist to check randomization balance

{synoptline}
{p2colreset}{...}
{p 4 6 2}


{marker description}{...}
{title:Description}

{pstd}
{cmd:randomize} randomizes the sample into groups specified in {opt groups}, with allocation fractions
spedified by {opt probabilities}. It will perform clustered randomizations specified in {opt cluster}, 
and also can perform stratified randomizations within specified {opt blocks}.


{marker options}{...}
{title:Options}

{dlgtab:Main}

{phang}
{opth generate(newvar)} generates a new variable {newvar} with the treatment statuses.

{phang}
{opth groups(string)} will ranomize the sample into the specified groups. Group names should
be seperated by commas. If {opt balance} is specified, comparisons will be against the first
group specified here.

{phang}
{opth probabilities(numlist)} specifies the relative sizes of each treatment arm. Order must
correspond with {opt groups}. For example, for two groups of equal size, specify prob(.5 .5).

{phang}
{opth cluster(varname)} specifies a variable within which to cluster randomization. Each unique level
of this variable will be randomized together. If you specify {opt cluster} and {opt blocks}, all
observations in each cluster must have the same values of the block variable.

{phang}
{opth seed(integer)} specifies the seed for the randomization.
values.

{phang}
{opt randomseed} selects a seed based on the exact time of the randomization. This seed is displayed
in the output so that the randomization can be replicated. This cannot be combined with {opt seed}. If
you do not specify {opt seed} or {opt randomseed}, the program uses the previously set seed, or allows
Stata to select at random.

{phang}
{opth balance(varlist)} produces a balance table for differences across groups within randomization
blocks on specified variables. Also, it displays binomial probabilities of seeing the observed number
of rejected null hypotheses if all tests were independent.



{marker examples}{...}
{title:Examples}


{phang}{cmd:. sysuse auto, clear}{p_end}

{phang}{cmd:. randomize, gen(treatment) groups(Treatment, Control) prob(.5 .5) blocks(foreign)}{p_end}

{phang}{cmd:. randomize, gen(treatment2) groups(A, B, C) prob(.5, .25, .25) cluster(rep78)}{p_end}

