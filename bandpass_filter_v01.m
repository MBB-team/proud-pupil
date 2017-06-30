function [ d ] = bandpass_filter_v01( d, fs, fcutlow, fcuthigh )
%function [ d ] = bandpass_filter_v01( d, fs, fcutlow, fcuthigh )
% this is a low pass filter for temporal data, e.g. pupil diameter.
%
% d: time series.
% fs: sampling rate in Hz.
% fcutlow: Filter lower than this.
% fcuthigh: Filter higher than this.
%
% Author: Antonius Wiehler <antonius.wiehler@gmail.com>
% Original: 2017-06-30
% Modified: 2017-06-30

order  = 1;
[b, a] = butter(order, [fcutlow, fcuthigh] / (fs / 2), 'bandpass');
d      = filter(b,a,d);  %filtered signal

end

