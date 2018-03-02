function [samplingrate] = eyetribe_estimate_samplingrate_v01(timestamps)
% function [samplingrate] = eyetribe_estimate_samplingrate_v01(timestamps)
%   This compute the empirical sampling rate of eyetribe eytracker
%   recordings.
%
%   Input:
%   - timestamps: A vector of time stamps from an eyetribe recording (i.e.
%   eyeTrackdata.time). This is recorded by the eyetribe in milliseconds.
%   Two possible settings in the eyetribe: 30Hz and 60Hz.
%
%   Outputs:
%   - samplingrate: An estimate of the samplingrate.
%
%   Author:   Antonius Wiehler <antonius.wiehler@gmail.com>
%   Original: 2018-02-28
%   Modified: 2018-03-02

samplingrate = 1000/nanmedian(diff(timestamps));

if round(samplingrate) ~=30 && round(samplingrate) ~=60
    warning('The estimated sampling rate of %02.2fHz is not 30Hz or 60Hz (the two possible states of the eyetribe).', samplingrate);
end % warning

end  % function