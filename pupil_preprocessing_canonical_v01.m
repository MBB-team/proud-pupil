function [pupil_size, timestamps] = pupil_preprocessing_canonical_v01(timestamps, pupil_size, valid_recording, gaze_pos)
% function [pupil_size, timestamps] = pupil_preprocessing_canonical_v01(timestamps, pupil_size, valid_recording, gaze_pos)
%
%  Preprocessing of pupil recordings.
%  On a timeseries of pupil diameter, the following preprocessing steps are
%  performed:
%  1) Calculate the measured sampling rate
%  2) Remove samples when fixation was at the border of the screen
%  3) Remove outliers outside 3 MAD
%  4) Bandpass filter
%  5) Linearly interpolate bad states
%  6) Downsampling to 60Hz if needed
%  7) Z-score
%
%  If you have recordings form both eyes, please preprocess each eye
%  separately, and averadge them afterwards.
%
%   Inputs
%   timestamps:     Vector of time stamps, in ms resolution, size: nx1
%   pupil_size:      Vector of pupil diameter, size: nx1
%   valid_recording: Vector, that indicates 0 when there is a blink etc.,
%                    as reported by the eyetracker and 1 if there is no
%                    problem with then signal. 0 parts will be interpolated
%                    in pupil_size later. size: nx1
%   gaze_pos:        Matrix of x and y gaze coordinates, in range of 0 to
%                    1 (normalized to your screen size). size: nx2
%
%   Outputs
%   pupil_size:      preprocessed pupil_size.
%   timestamps:     timestamps after interpolation, downsampling etc.
%
%   Author: Antonius Wiehler <antonius.wiehler@gmail.com>
%   Original: 2018-03-16
%   Modified: 2018-03-16



%% PARAMETERS - DO NOT TOUCH :)
% =========================================================================
cfg.pupil.blink           = 0;  % bad data in the pupil vector will be replaced by this
cfg.pupil.samplingrate    = 60;  % sampling rate we want to have after preprocessing
cfg.pupil.blinkwindow     = 0.125;  % how many seconds before and after blink do we want to remove?
cfg.pupil.mad_cutoff      = 3;  % ouliers of how many mad should be rejected? (median deviance)
cfg.pupil.highpass_filter = 1/128;  % pupil highpass filter in Hz.
cfg.pupil.lowpass_filter  = 1;  % Filter everything faster than this Hz.
cfg.pupil.delete_at_begin = 3;  % how many seconds at the beginning should be deleted to remove filter artifacts?
cfg.pupil.border_size     = 0.1;  % how many percent of screen should be considered as periphical?

% TODO CHECK FOR SPM FOLDER
cfg.dir.spm                  = '~/matlab_toolboxes/spm12/';  % whre is the SPM installation? Used for high pass filter
addpath(genpath(cfg.dir.spm));  % add spm for spm_filter function



%% CHECKS
% =========================================================================
% TODO CHECK IF WE HAVE ENOUGH INPUTS

% TODO CHECK IF ALL VARIABLES HAVE THE SAME LENGTH

%% PREPROCESSING
% =========================================================================

% calculate sampling rate
% -------------------------------------------------------------------------
samplingrate = eyetribe_estimate_samplingrate_v01(timestamps);

% TODO CHECK IF AROUND 60 OR NOT

% remove bad states
% -------------------------------------------------------------------------
pupil_size(~valid_recording) = cfg.pupil.blink;


% remove fixations outside screen borders
% -------------------------------------------------------------------------
pupil_size = delete_periphical_fixations_v01(pupil_size, gaze_pos(:, 1) * 1000, gaze_pos(:, 2) * 1000, ...
    1000, 1000, cfg.pupil.border_size, cfg.pupil.blink);


% TODO correct for gaze position
% -------------------------------------------------------------------------
% For the eyetracker, the pupil appears to be smaller when looking at
% the screen border (ellipse cut of the pupil).


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
sampling_factor = round(samplingrate ./ cfg.pupil.samplingrate);  % by what factor do we need to reduce?

if sampling_factor > 1
    % downsamples with low pass filtering, used for measures
    pupil_size       = decimate(pupil_size, sampling_factor);
    
    % downsample without low pass filtering, used for markers etc.
    timestamps     = downsample(timestamps, sampling_factor);
    
elseif sampling_factor < 1
    % TODO IF WE NEED TO UPSAMPLE
else
    %  TODO
end


% z-score pupil time series
% -------------------------------------------------------------------------
pupil_size = zscore(pupil_size);


% give feedback on console
% -------------------------------------------------------------------------
fprintf('Pupil preprocessing done - %.2f%% of samples rejected.\n', sum(nSamplesRejected) * 100);  % done :)

end  % main function

