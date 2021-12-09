/*
Y_i | mu_i                    ~ Pois(mu_i)
mu_i = exp(beta_1 + x_dist2*beta_2 + ... + x_dist7*beta_7 +
           x_density*beta_8 + x_logincome*beta_9 + x_cases_avg7*beta_10)
beta_1, ..., beta_10          ~ N(mu_0, tau_0^2)

Note: X's for continuous variables are centered and scaled
*/

data {
  int<lower=1> N;
  int<lower=0> y[N];
  matrix[N,10] X;
  
  // Priors for distributions on betas below
  real mu_0;
  real<lower=0> tau2_0;
}

transformed data {
  real<lower=0> sd_0;
  sd_0 = 1 / sqrt(tau2_0);
}
 
parameters {
  vector[10] beta;
}

model {
  // Data model
  y ~ poisson(exp(X*beta));
  
  // Prior model
  beta ~ normal(mu_0, sd_0);
}
