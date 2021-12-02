/* FIXME: HAVE NOT INCLUDED POPULATION CORRECTION YET
Y_ij | mu_ij                    ~ Pois(mu_ij)
eta_ij = mu_ij
eta_ij | beta_i0, beta_1, tau^2 ~ N(beta_i0 + x_ij*beta_1, tau^2)
beta_i0, beta_1                 ~ N(mu_0, tau_0^2)
tau^2                           ~ Gamma(alpha, beta)

*/

data {                    // Data block
  int<lower=1> districts; // Number of districts
  int<lower=1> districtN[districts]; // Sample sizes of each district
  int<lower=1> maxN;      // Largest of the sample sizes among districts
  int<lower=0> y[districts, maxN];
  real<lower=0> x[districts, maxN]; //matrix[districts, maxN] x;
  // Priors for distributions on betas and tau^2 below
  real mu_0;
  real<lower=0> tau2_0;
  real<lower=0> a;
  real<lower=0> b;
}
 
transformed data {
  real<lower=0> sigma2_0 = 1/tau2_0;
}

parameters {                    // Parameters block
  real eta[districts, maxN];
  real<lower=0> tau2;
  real beta0[districts];  // Intercept for each district
  real beta1;             // Effect of 7-day rolling avg COVID cases on eta_ij
}

transformed parameters {
  real<lower=0> mu[districts, maxN] = exp(eta);
  real<lower=0> sigma2 = 1/tau2;
}

model {                  // Model block
  // Data model
  for (i in 1:districts) {
    int n = districtN[i];
    y[i, 1:n] ~ poisson(mu[i, 1:n]);
    eta[i, 1:n] ~ normal(beta0[i] + to_vector(x[i, 1:n]) * beta1, sigma2);
    // y[i, 1:districtN[i]] ~ poisson_log_glm(to_matrix(x[i, 1:districtN[i]]), beta0[i], beta1);
  }
  
  // Prior model
  for (i in 1:districts) {
    beta0[i] ~ normal(mu_0, sigma2_0);
  }
  beta1 ~ normal(mu_0, sigma2_0);
  tau2 ~ gamma(a, b);
  
  
}

/*                      // Sampling data block. Not used here.
generated quantities {
}
*/
