function [output] = hierarchical_bayes_stan(data, max_dim, varargin)
%% “Copyright 2018, Christiane Ahlheim”
%% This program is free software: you can redistribute it and/or modify
%% it under the terms of the GNU General Public License as published by
%% the Free Software Foundation, either version 3 of the License, or
%% (at your option) any later version.
%% This program is distributed in the hope that it will be useful,
%% but WITHOUT ANY WARRANTY; without even the implied warranty of
%% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%% GNU General Public License for more details.
%% You should have received a copy of the GNU General Public License
%% along with this program.  If not, see <http://www.gnu.org/licenses/>.

%% simple hierarchical bayesian model implemented in stan to estimate dimensionality
% add stan package to your path
% addpath(genpath('~/MATLAB/PSIS-master/'));

% necessary inputs:
% data: dimensionality estimates; format is j(runs) x n(participants)
% max_dim: maximal dimensionality; if no hypothesis, that's k(number of
% conditions) - 1

% vargin 1: modelname
% vargin 2: iterations

J = size(data,2);
n_sessions = size(data, 1);
mean_dim = mean(data, 1);
sd_dim = std(data,1);
iter = 1000;

% if no model is predefined and passed on to function, set up basis model
% this is our model
if nargin < 3
    hb_model = {
        'data {'
        '    int<lower=0> J; // number of participants '
        '    real y[J]; // mean estimated dimensionality'
        '    real<lower=0> sigma[J]; // sd of dimensionality estimates '
        '    int n_sessions[J]; // number of sessions '
        '    int max_dim; // maximal dimensionality'
        '    real max_tau_pop;'
        '    real max_tau_sub;'
        '}'
        'parameters {'
        '    real<lower=1,upper= max_dim> mu; '
        '    real<lower=1,upper= max_dim> theta[J];'
        '    real<lower=0, upper=max_tau_pop> tau_pop;'
        '    real<lower=0, upper=max_tau_sub> tau_sub[J];'
        '}'
        'model {'
        ' for (j in 1:J){'
        '    theta[j]   ~normal(mu, tau_pop) T[1,max_dim];'
        '    sigma[j]   ~normal(tau_sub[j],1) T[0,max_tau_sub];'
        '    y[j] ~ student_t(n_sessions[j] -1,theta[j], tau_sub[j]) T[1,max_dim];}'
        '}'
        'generated quantities {'
        '  vector[J] log_lik;'
        '  for (j in 1:J)'
        '    log_lik[j] <- student_t_lpdf(y[j]| n_sessions[j] -1, theta[j], tau_sub[j]);'
        '}'
        };

    % compile the model (needs to be done only once)
    sm = StanModel('model_code',hb_model, 'model_name', 'single_model_psis');
    sm.compile();
    sm = StanModel('file', 'single_model_psis');
else
    sm = StanModel('file', varargin{1});
    if nargin > 3
        iter = vargin{2};
    end
end

data = struct('J',J,...
    'n_sessions', repmat(n_sessions,1,J),...
    'y',mean_dim',...
    'sigma',sd_dim',...
    'max_dim', max_dim, ...
    'max_tau_pop',sqrt((max_dim-1)^2 / 12), ...
    'max_tau_sub', sqrt((max_dim - (max_dim +1)/2)^2 * n_sessions/(n_sessions-1)));

fit = stan('file','single_model_psis','data',data,'file_overwrite',true,'verbose',false, 'iter', iter);
fit.block()
output = fit.extract('permuted',true);

%% optionally, perform Pareto smoothed importance sampling; get leave-one-out log predictive densities
% [loo,loos,pk]=psisloo(output.log_lik);
