function [d] = highpass_filter_v01(d , samplingrate, filter_length)
% function [d] = highpass_filter_v01(d , samplingrate, filter_length)
%
% Highpass filter of time series (pupil).
%
% d: vector of pupil size measures
% samplingrate: samplingrate of the eyetracker
% filter_length: Fluctuations slower than this will be removed (in s).
%
% The function depends on spm_filter! You most likely need SPM in your
% path.
%
% Author: Antonius Wiehler <antonius.wiehler@gmail.com>
% Original: 2017-06-24
% Modified: 2017-06-24

% set up parameters for spm filter
K.RT     = 1 ./ samplingrate;
K.row    = 1 : length(d); % corresponds to the length of convreg
K.HParam = filter_length;  % cut-off time in seconds
nK       = spm_filter(K);  % generate filter parameters

% apply filter
d = spm_filter(nK, d);

end

