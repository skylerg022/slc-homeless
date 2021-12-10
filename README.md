---
author:
- Skyler Gray
date: 'December 9, 2021'
title: Homelessness Response Times in Salt Lake City
---

Introduction
============

Homelessness is a perpetual challenge in Salt Lake City. The city
government has a protocol for investigating suspicious activity,
disbanding homeless communities, and referring individuals to homeless
resources in the area. One way city residents and visitors can support
these measures is through reporting concerns of homelessness directly to
the city government via the web or the SLC Mobile app.

I am interested in investigating the city’s recent efforts to resolve
concerns of homelessness in the last two years. Specifically, I want to
know whether there is a difference in response time among the city’s
seven city council districts. As a secondary objective, I want to know
how the prevalence of COVID-19 affects response time. To investigate
this potential difference in performance and the effects of COVID-19 on
response time, I propose a Bayesian Poisson regression model to estimate
the average number of days needed for the city to respond to and close a
homelessness service request.

The Data
========

The data on service requests within Salt Lake City are publicly
available through the State of Utah’s web page
(<https://opendata.utah.gov/Government-and-Taxes/Service-Request-SLCMobile/yga5-qpeq/data>).
Each service request has a creation date, closed date, request type, and
GPS coordinates. The data was first filtered down to “Concern of
Homelessness” requests between January 1, 2020 and October 31, 2021.
Because of both an unrealistic number of cases closed on a given day or
the short lag behind closing another case, the requests data was further
filtered from about 5,000 to around 1,500 requests (see Figure
\[fig:data-openclose\]). Those removed included days with five or more
requests closed within three minutes of each other as well as days with
number of cases closed above the 90th percentile.

![The unfiltered concern of homelessness request data (left) and the
filtered data used in the analysis
(right)[]{data-label="fig:data-openclose"}](plots/data_openclose.png){width="0.60\linewidth"}

COVID-19 new case data for Salt Lake county was obtained from the Center
of Systems Science and Engineering (CSSE) at Johns Hopkins University
(JHU)
(<https://github.com/CSSEGISandData/COVID-19/blob/master/csse_covid_19_data/csse_covid_19_time_series/time_series_covid19_confirmed_US.csv>).
Information on the 2010 Census tract that a request belonged to was
evaluated using the GIS data available through the state government’s
website (<https://gis.utah.gov/data/demographic/census/>). Lastly, 2019
tract estimates of population density and median income were pulled from
the 2020 Salt Lake City Data Book
(<https://www.slc.gov/hand/wp-content/uploads/sites/12/2020/10/SLC-Data-Book-2020forWeb.pdf>).

  **Variable**      **Description**
  ----------------- ------------------------------------------------------------------------------------------------------------------
  District          City council district of the request GPS coordinates
  New COVID Cases   The 7-day rolling average of new COVID-19 cases in Salt Lake county as of request creation date
  Density           Estimated 2019 population density (people/$mi^2$) of the relevant 2010 Census tract matching the GPS coordinates
  Income            Estimated 2019 median household income of the Census tract that the GPS coordinates were located in
  Days Open         Number of days until the request was closed; rounded to nearest 24-hour period

  : Brief descriptions of the data to be used in model
  development[]{data-label="tab:data-intro"}

![Reports of homelessness concerns since January 1, 2021. Each
observation is colored by its respective city council
district.[]{data-label="fig:data-reports"}](plots/reports_map.png){width="0.60\linewidth"}

Figure \[fig:eda-density\] shows that the response time to any given
request is right-skewed and takes values between 0 and 209.

![The distribution of days until a report of concern of homelessness is
closed.[]{data-label="fig:eda-density"}](plots/eda_days_histogram.png){width="0.60\linewidth"}

EDA
===

Table \[tab:eda-districts\] and Figure \[fig:eda-districts\] provide
insight into the response time across districts. The mean response times
are in the range of 14 to 16 days except for district 6. However, we do
not have nearly as large of a sample in district 6 as we do in all other
districts. The boxplots of Figure \[fig:eda-districts\] suggest that, on
the log scale, all districts except district 6 appear to be similarly
distributed.

  **District**     **n**   **Days Open**
  -------------- ------- ---------------
  1                  159           14.66
  2                  327           14.13
  3                   56           16.46
  4                  360           15.47
  5                  250           12.56
  6                    6           30.50
  7                  150           14.07

  : Sample sizes and mean response time across
  districts[]{data-label="tab:eda-districts"}

![Visualization of the distribution of the log days open across
districts. Only district 6 appears to have a different distribution than
the other districts, but district 6 has significantly less observations
behind its distribution than all the
others.[]{data-label="fig:eda-districts"}](plots/eda_days_districts.png){width="0.60\linewidth"}

Multiple variables will be included in the model as potential predictors
of average response time. These three variables are the 7-day rolling
average of new covid cases, the log-scaled median household income, and
population density. The independent effects of these variables on
log(Days Open) are explored in Figure \[fig:eda-predictors\].

![Exploratory plots of potential predictors against the log number of
days a report is
open.[]{data-label="fig:eda-predictors"}](plots/eda_cont_predictors.png){width="0.60\linewidth"}

Methods
=======

Model: Poisson Regression
-------------------------

To understand the district effect on mean response time after accounting
for other potential confounding variables, I propose a Bayesian Poisson
regression model with the logit link. Let $Y_{i}$ be the number of days
until the $i$th request concerning homelessness in Salt Lake City is
closed. Additionally, let $\mu_i$ be the average number of days until a
request is closed for the $i$th and let $X_{i}$ be a $1 \times 10$
matrix of the covariates for request $i$ and let $\beta$ be a
$10 \times 1$ matrix with coefficients for the intercept, districts 2
through 7, the 7-day rolling average of new COVID cases in Salt Lake
county, median household income, and population density. Then I propose
the following model for response time:

$$\begin{aligned}
Y_{i} | \mu_{i} &\stackrel{ind}\sim Pois(\mu_{i}), \\
log(\mu_{i}) &= X\beta, \\
\beta_{1}, ..., \beta_{10} &\sim N(\mu_0, \tau_0^2),\end{aligned}$$

where the $\beta$ coefficients have diffuse priors centered on 0. My
initial choice of a prior is $\mu_0 = 0$ and $\tau_0^2 = 1/100$ because
I am not sure whether an effect is positive or negative for most $\beta$
estimates and want the data to do the estimating.

I sampled from the posterior distribution using two different methods.
First, I sampled from the posterior distribution via a univariate slice
sampler for each $\beta$. Second, I used the probabilistic programming
language (PPL) Stan to sample from the posterior distribution. In order
to stabilize sampling from the posterior, I centered and scaled the
three continuous variables before sampling from the posterior. After, I
rescaled the coefficients again. So $\beta_8$ will be interpreted as the
effect of an increase in Census tract population by 1,000 people/$mi^2$
on the log mean response time, holding all other variables constant.
$\beta_9$ is interpreted as the effect of an increase of log median
household income on log mean response time, and $\beta_{10}$ is the
effect of an increase in the 7-day rolling average of new COVID-19 cases
on log mean response time.

Diagnostics
-----------

Table \[tab:results-mixing\] shows the convergence diagnostics of both
the slice sampler and Stan approaches to sampling from the posterior
distribution. I could sample more draws using the slice sampler to
potentially reduce the $\hat{R}$ calculations, but for the sake of
saving myself time, I am going to just use the much larger sample from
Stan.

  ----------------- ----------- ---------- ----------- ---------- ----------- ----------
   **Coefficient**    **Slice**   **Stan**   **Slice**   **Stan**   **Slice**   **Stan**
      $\beta_1$           2.671      2.671        2252      21441        1.52          1
      $\beta_2$          -0.013     -0.013        2757      25318        1.33          1
      $\beta_3$           0.108      0.107        4714      35126        1.48          1
      $\beta_4$           0.062      0.062        2695      25432        1.47          1
      $\beta_5$          -0.149     -0.149        3133      28564        1.52          1
      $\beta_6$           0.731      0.731        7986      45810        1.52          1
      $\beta_7$          -0.037     -0.036        3532      30704        1.13          1
      $\beta_8$          0.0085     0.0085        8294      50664         1.5          1
      $\beta_9$          0.0035     0.0032        7701      43888        1.52          1
    $\beta_{10}$         0.0005     0.0005        9000      65405        1.52          1
  ----------------- ----------- ---------- ----------- ---------- ----------- ----------

  : Both samplers produced the same coefficient estimates up to Monte
  Carlo error, but Stan yields a much larger effective sample size and
  lower $\hat{R}$ than my slice sampler and in a fraction of the time.
  The high $\hat{R}$ values for the slice sampler suggest that the
  chains have not converged yet, which may be due to the relatively
  small sample size.[]{data-label="tab:results-mixing"}

![Trace plots for posterior draws via
Stan.[]{data-label="fig:results-trace"}](plots/results_trace.png){width="0.60\linewidth"}

Sensitivity Analysis
--------------------

Due to the model structure’s simplicity, the sensitivity analysis I
could investigate only pertains to giving the $\beta$ coefficients
either stronger or weaker priors centered in different locations. Given
the intercept $\beta_1$ is highly correlated with all other $\beta_j$,
creating an unrealistically strong prior will dramatically influence our
$\beta$ estimates. Given my lack of necessary time to explore it, I will
let this commentary on a sensitivity analysis suffice. Because of the
large sample size we have, we can expect the $\beta$ coefficients to be
fairly robust against prior center as well as varying precision levels.

Results
=======

The primary question behind this analysis is whether, after accounting
for several potential confounding variables, there is an apparent
difference in city government response time to homelessness concerns
among Salt Lake City’s seven city council districts. Figure
\[fig:analysis-districts\] shows us that, even after accounting for
uncertainty, a request from every district except district 6 should
expect to be resolved within about 13 to 17 days. I would be interested
to see the city government’s input on these observed differences, as an
imbalance in request investigation could mean neglecting larger needs in
districts that may be overlooked, which could be districts 3 and 4.

Again, because district 6 only has 6 observations behind its estimated
effects, I believe we do not have enough information to really observe
any useful pattern as compared to all other districts.

![Posterior estimates and 95% credible intervals of mean days a
homelessness concern request is
open.[]{data-label="fig:analysis-districts"}](plots/post_district_ci.png){width="0.60\linewidth"}

The secondary goal of this analysis is to understand the relationship
between COVID-19 prevalence and average response time to concerns of
homelessness. The 95% credible interval for the 7-day rolling average of
new COVID cases is (0.0004, 0.0005). Because the data for this analysis
is not a random sample, we cannot conclude causation, but there is a
positive correlation between the rolling average of new COVID cases and
the average response time for a request.

  **Coefficient**     **Estimate**   **Lower**   **Upper**
  ----------------- -------------- ----------- -----------
  Density                   0.0085      0.0027      0.0142
  Log(Income)               0.0032     -0.0598      0.0657
  New Cases                 0.0005      0.0004      0.0005

  : Posterior mean and 95% credible
  intervals.[]{data-label="tab:analysis-effects"}

Conclusion
==========

I have taken an initial dive into Salt Lake City’s publicly available
data on requests submitted to the city’s Department of Health. It is
interesting to note that there may be some discrepancies in equitable
resource allocation to resolve homelessness concerns among Salt Lake
City’s seven city council districts, but it is hard to call anything a
true concern without speaking to a domain expert. Additionally, the
model follows one’s intuition that a dramatic rise in new COVID-19 cases
should slow down the city government’s efforts to resolve problems that
involve increased contact with others.

There are so many ways this project could develop down the road. For one
thing, I have not made contact with the right person within the Salt
Lake City Department of Health. Making contact with the department and
learning more about the investigation process of these reports will be
crucial to performing some helpful analysis.

Additionally, there are several routes of improvement open to this
model. First, I believe this first model does not reflect the
uncertainty behind the mean effects of district 6 on response time. The
next step to approaching this may be to develop a hierarchical model
with an unknown precision parameter for each $\beta_j$. In addition to
more accurately reflecting our uncertainty in the model, we may consider
checking for overdispersion by modeling the random error behind response
time as a negative binomial distribution rather than as Poisson error.
