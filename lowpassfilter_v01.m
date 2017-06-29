function [ d ] = lowpassfilter_v01( d, samplingrate, cutoff )
%function [ d ] = lowpassfilter_v01( d, samplingrate, cutoff )
% this is a low pass filter for temporal data, e.g. pupil diameter.
%
% d: time series.
% samplingrate: sampling rate in Hz.
% cutoff: Filter lower than this.
%
% Author: Antonius Wiehler <antonius.wiehler@gmail.com>
% Original: 2017-06-29
% Modified: 2017-06-29

filtfilt(fir1(35, 2 * cutoff/samplingrate), 1, d);

end

