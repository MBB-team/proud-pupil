function [contrast_pos_values, out_effect_pos] = stats_compare_two_timeseries(mat1, mat2, contrast)
% USAGE function [contrast_pos_values, out_effect_pos] = stats_compare_two_timeseries(mat1, mat2, contrast)
%
% A quick t-test of two time series.
%
% Requires VBA toolbox in the path.
%
% ARGS
% mat1           Data matrix 1. Observations in rows, time in collumns
% mat2           Data matrix 2. Observations in rows, time in collumns
% contrast       Contrast for t-test to compare the two matrices
%
% Author:        Antonius Wiehler <antonius.wiehler@gmail.com>
% Original:      2017-04-06
% Last modified: 2017-07-20


% combine data
mat = [mat1; mat2];
mat(isnan(mat)) = 0;  % just a quick fix for the statistics, make sure we dont have nan

% build design matrix
X = zeros(size(mat, 1), 3);
X(:, 3) = 1;  % constant
X(1 : size(mat1, 1), 1) = 1;  % constant for mat 1
X((size(mat1, 1) + 1) : end, 2) = 1;  % constant for mat 2


% RUN 1D RFT
[contrast_pos_values, out_effect_pos] = RFT_GLM_contrast(X, mat, contrast, 't', [], 0);


end

