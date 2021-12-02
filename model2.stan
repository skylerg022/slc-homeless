/* FIXME: HAVE NOT INCLUDED POPULATION OFFSET YET
Y_ij | mu_ij                    ~ Pois(mu_ij)
mu_ij = exp(beta_i0 + x_ij*beta_1)
beta_i0, beta_1                 ~ N(mu_0, tau_0^2)

*/

data {                       // Data block
  int<lower=1> districts;    // Number of districts; should be 7
  // The number of samples is vastly different for each district
  int<lower=1> districtN[districts];
  int<lower=1> maxN;         // Largest of the sample sizes among districts
  int<lower=0> y[districts, maxN];
  matrix[districts, maxN] x; //real<lower=0> x[districts, maxN];
  
  // Priors for distributions on betas below
  real mu_0;
  real<lower=0> tau2_0;
}
 
transformed data {
  real<lower=0> sigma2_0 = 1/tau2_0;
}

parameters {                    // Parameters block
  real beta0[districts];  // Intercept for each district
  vector[1] beta1;        // Effect of 7-day rolling avg COVID cases on eta_ij
}

model {                  // Model block
  // Data model
  for (i in 1:districts) {
    int n = districtN[i];
    y[i, 1:n] ~ poisson_log_glm(to_matrix(x[i, 1:n])', beta0[i], beta1);
  }
  
  // Prior model
  for (i in 1:districts) {
    beta0[i] ~ normal(mu_0, sigma2_0);
  }
  beta1 ~ normal(mu_0, sigma2_0);
}

/*                      // Sampling data block. Not used here.
generated quantities {
}
*/
