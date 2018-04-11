function [pupil_size, timestamps, sampling_factor] = pupil_preprocessing_canonical_v01(timestamps, pupil_size, valid_recording)
% function [pupil_size, timestamps, sampling_factor] = pupil_preprocessing_canonical_v01(timestamps, pupil_size, valid_recording)
%
%  Preprocessing of pupil recordings.
%  On a timeseries of pupil diameter, the following preprocessing steps are
%  performed:
%  1) Calculate the recorded sampling rate
%  2) Remove outliers outside 3 MAD
%  3) Bandpass filter
%  4) Linearly interpolate bad states
%  5) Resampling to 60Hz if needed
%  6) Z-score
%
%  If you have recordings form both eyes, please preprocess each eye
%  separately, and average them afterwards.
%
%  Please add SPM12 to your path before running this script.
%
%   Inputs
%   timestamps:      Vector of time stamps, in ms resolution, size: nx1
%   pupil_size:      Vector of pupil diameter, size: nx1
%   valid_recording: Vector indicating good and bad states of recording (signal lost,
%                    fixations outside your stimuli on the screen, blinks etc.) 
%                    The results should be a vector, indicating for each time sample
%                    if it is valid (1) or not (0).  Samples marked with 0 will be interpolated
%                    in pupil_size later. Size: nx1
%
%   Outputs
%   pupil_size:      Preprocessed pupil_size vector.
%   timestamps:      Timestamps after interpolation, downsampling etc.
%   sampling_factor: How much we did up- or downsample
%
%   Author: Antonius Wiehler <antonius.wiehler@gmail.com>
%   Original: 2018-03-16
%   Modified: 2018-04-11



%% PARAMETERS - PLEASE DO NOT TOUCH :)
% =========================================================================
cfg.pupil.blink           = 0;      % bad data in the pupil vector will be replaced by this
cfg.pupil.samplingrate    = 60;     % sampling rate we want to have after preprocessing
cfg.pupil.blinkwindow     = 0.1;    % how many seconds before and after blink do we want to remove?
cfg.pupil.mad_cutoff      = 3;      % ouliers of how many mad should be rejected? (median deviance)
cfg.pupil.highpass_filter = 1/128;  % pupil highpass filter in Hz.
cfg.pupil.lowpass_filter  = 1;      % Filter everything faster than this Hz.
cfg.pupil.delete_at_begin = 3;      % how many seconds at the beginning of the timeseries should be deleted to remove filter artifacts?


%% CHECKS
% =========================================================================
if nargin < 3
    error('Not enough input arguments.');
end

% correct vector orientation
timestamps = timestamps(:);
pupil_size = pupil_size(:);
valid_recording = valid_recording(:);

if ~all(size(pupil_size) == size(timestamps) & size(pupil_size) == size(valid_recording))
    error('Inputs do not have the same length.');
end

if ~contains(path, 'spm')
    error('Please add SPM12 to your path before running this script.');
end


%% PREPROCESSING
% =========================================================================

% calculate sampling rate
% -------------------------------------------------------------------------
samplingrate = estimate_samplingrate_v01(timestamps);


% remove bad states
% -------------------------------------------------------------------------
pupil_size(~valid_recording) = cfg.pupil.blink;


% exclude samples that are outside mad_cutoff - remove outliers
% -------------------------------------------------------------------------
pupil_size = remove_outliers_mad_v01(pupil_size, cfg.pupil.mad_cutoff, cfg.pupil.blink);


% how many samples have been rejected?
% -------------------------------------------------------------------------
nSamplesRejected = sum(pupil_size == cfg.pupil.blink) ./ length(pupil_size);


% linear interpolate blinks and bad states +- window
% -------------------------------------------------------------------------
[pupil_size, blink_indx] = interpolate_blinks_v01(pupil_size, cfg.pupil.blink, samplingrate, cfg.pupil.blinkwindow);


% band-pass filter to remove slow fluctuations and to smooth
% -------------------------------------------------------------------------
pupil_size = bandpass_filter_v01(pupil_size, samplingrate, cfg.pupil.highpass_filter, cfg.pupil.lowpass_filter);


% linear interpolate blinks and bad states +- window again to remove
% artefacts from filtering
% -------------------------------------------------------------------------
blink_indx(1 : ceil(cfg.pupil.delete_at_begin * samplingrate)) = 1;  % to remove filter artefacts at start
pupil_size(blink_indx) = cfg.pupil.blink;

pupil_size = interpolate_blinks_v01(pupil_size, cfg.pupil.blink, samplingrate, cfg.pupil.blinkwindow);


% downsampling
% -------------------------------------------------------------------------
sampling_factor = samplingrate / cfg.pupil.samplingrate;  % by what factor do we need to reduce?

if sampling_factor > 1.1
    
    % downsamples with low pass filtering, used for measures
    pupil_size = decimate(pupil_size, sampling_factor);
    
    % downsample without low pass filtering, used for markers etc.
    timestamps = downsample(timestamps, sampling_factor);
    
    fprintf('Time series was downsampled from %.2fHz to %.2fHz.\n', samplingrate, cfg.pupil.samplingrate);
    
elseif sampling_factor < 0.9
    
    x          = 1 : length(timestamps);
    xq         = 1 : sampling_factor : length(timestamps) + 1;
    timestamps = interp1(x, timestamps, xq)';
    pupil_size = interp1(x, pupil_size, xq)';
    timestamps = timestamps(1 : end - 2, :);  % remove last to samples because they are likely nan
    pupil_size = pupil_size(1 : end - 2, :);  % remove last to samples because they are likely nan
    
    fprintf('Time series was upsampled from %.2fHz to %.2fHz.\n', samplingrate, cfg.pupil.samplingrate);
    
else
    % if we are in the accuracy range, we do not touch
    sampling_factor = nan;  % just to return a value
end


% z-score pupil time series
% -------------------------------------------------------------------------
pupil_size = zscore(pupil_size);


% give feedback on console
% -------------------------------------------------------------------------
fprintf('Pupil preprocessing done - %.2f%% of samples rejected.\n', sum(nSamplesRejected) * 100);  % done :)


end  % main function
