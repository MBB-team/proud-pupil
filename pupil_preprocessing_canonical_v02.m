function [pupil_size, timestamps, sampling_factor] = pupil_preprocessing_canonical_v02(timestamps, pupil_size, valid_recording, do_mad_outlier, do_bandpass_filter, do_interpolation, do_resampling, do_zscore)
% function [pupil_size, timestamps, sampling_factor] = pupil_preprocessing_canonical_v02(timestamps, pupil_size, valid_recording, do_mad_outlier, do_bandpass_filter, do_interpolation, do_resampling, do_zscore)
%
%  Preprocessing of pupil recordings.
%  On a timeseries of pupil diameter, the following preprocessing steps can
%  be performed (call them with input to function):

%  1) Calculate the recorded sampling rate
%  2) 'do_mad_outlier':     Remove outliers outside 3 MAD
%  3) 'do_bandpass_filter': Bandpass filter
%  4) 'do_interpolation':   Linearly interpolate bad states
%  5) 'do_resampling':      Resampling to 60Hz if needed
%  6) 'do_zscore':          Z-score
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
%   Modified: 2018-06-04



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
if nargin < 8
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
if do_mad_outlier
    pupil_size = remove_outliers_mad_v01(pupil_size, cfg.pupil.mad_cutoff, cfg.pupil.blink);
end

% how many samples have been rejected?
% -------------------------------------------------------------------------
nSamplesRejected = sum(pupil_size == cfg.pupil.blink) ./ length(pupil_size);


% linear interpolate blinks and bad states +- window
% -------------------------------------------------------------------------
if do_interpolation
    [pupil_size, blink_indx] = interpolate_blinks_v01(pupil_size, cfg.pupil.blink, samplingrate, cfg.pupil.blinkwindow);
end

% band-pass filter to remove slow fluctuations and to smooth
% -------------------------------------------------------------------------
if do_bandpass_filter
    pupil_size = bandpass_filter_v01(pupil_size, samplingrate, cfg.pupil.highpass_filter, cfg.pupil.lowpass_filter);
    pupil_size(blink_indx) = cfg.pupil.blink;

    % linear interpolate blinks and bad states +- window again to remove
    % artefacts from filtering
    % -------------------------------------------------------------------------
    pupil_size = interpolate_blinks_v01(pupil_size, cfg.pupil.blink, samplingrate, cfg.pupil.blinkwindow);
end

% downsampling
% -------------------------------------------------------------------------
sampling_factor = round(samplingrate / cfg.pupil.samplingrate);  % by what factor do we need to reduce?

if do_resampling
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
end

% z-score pupil time series
% -------------------------------------------------------------------------
if do_zscore
    pupil_size = zscore(pupil_size);
end

% give feedback on console
% -------------------------------------------------------------------------
fprintf('Pupil preprocessing done - %.2f%% of samples rejected.\n', sum(nSamplesRejected) * 100);  % done :)


end  % main function
