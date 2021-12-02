/* FIXME: HAVE NOT INCLUDED POPULATION OFFSET YET
Y_ij | mu_ij                    ~ Pois(mu_ij)
mu_ij = exp(beta_i0 + x_ij*beta_1)
beta_i0, beta_1                 ~ N(mu_0, tau_0^2)

*/

data {                       // Data block
  int<lower=1> N;
  int<lower=1> districts;
  int<lower=0> y[N];
  matrix[N, 8] x;
  
  // Priors for distributions on betas below
  real mu_0;
  real<lower=0> tau2_0;
}
 
transformed data {
  real<lower=0> sigma2_0 = 1/tau2_0;
}

parameters {                    // Parameters block
  vector[8] beta;        // beta_8: Effect of 7-day rolling avg COVID cases on eta_ij
}

model {                  // Model block
  // Data model
  y ~ poisson_log_glm(x, 0, beta);
  
  // Prior model
  for (i in 1:8) {
    beta[i] ~ normal(mu_0, sigma2_0);
  }
}

/*                      // Sampling data block. Not used here.
generated quantities {
}
*/
