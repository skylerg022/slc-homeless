/*
Y_i | mu_i                    ~ Pois(mu_i)
mu_i = exp(x_dist1*beta_1 + ... + x_dist7*beta_7 +
           x_hasincome*beta_8 + x_density*beta_9 +
           x_logincome*beta_10 + x_cases_avg7*beta_11)
beta_1, ..., beta_11          ~ N(mu_0, tau_0^2)

Note: X's for continuous variables are centered and scaled
*/

data {                       // Data block
  int<lower=1> N;
  int<lower=0> y[N];
  matrix[N, 11] X;
  
  // Priors for distributions on betas below
  real mu_0;
  real<lower=0> tau2_0;
}
 
transformed data {
  real<lower=0> sigma2_0 = 1/tau2_0;
}

parameters {                    // Parameters block
  vector[11] beta;
}

transformed parameters {
  vector[N] lp;
  vector[N] mu;
  lp = X*beta;
  mu = exp(lp);
}

model {                  // Model block
  // Data model
  y ~ poisson_log_glm(X, 0, beta);
  
  // Prior model
  for (i in 1:11) {
    beta[i] ~ normal(mu_0, sigma2_0);
  }
}

/*                      // Sampling data block. Not used here.
generated quantities {
}
*/
