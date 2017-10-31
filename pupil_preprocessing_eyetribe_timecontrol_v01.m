function [] = pupil_preprocessing_eyetribe_timecontrol_v01(subject, condition, session)
% function [] = pupil_preprocessing_eyetribe_timecontrol_v01(subject, condition, session)
%   Preprocessing of pupil recordings.
%   cfg: configuration structure
%   subject: current subject, ID_INITIALS, e.g. 111_aw
%   condition: condition to be processed.
%   session: session n umber to be processed
%
%   Author: Antonius Wiehler <antonius.wiehler@gmail.com>
%   Original: 2017-10-30
%   Modified: 2017-10-31



%% PARAMETERS
% =========================================================================

% screen
% -------------------------------------------------------------------------
cfg.ptb.ScreenX              = 1920; % screen size X TODO: read from PTB
cfg.ptb.ScreenY              = 1080; % screen size Y TODO: read from PTB


% eye tracker
% -------------------------------------------------------------------------
cfg.eye.samplingrate         = 60;   % sampling rate we want to have after pre processing


% preprocessing parameter
% -------------------------------------------------------------------------
cfg.eye.blink                = 0;   % how to mark a blink in the pupil time series
cfg.eye.blinkwindow          = 0.1;  % how many seconds before and after blink do we want to remove?
cfg.eye.mad_cutoff           = 3;    % ouliers of how many mad should be rejected? (median deviance)
cfg.eye.highpass_filter      = 1/128;  % pupil highpass filter in Hz.
cfg.eye.lowpass_filter       = 1;    % Filter everything faster than this Hz.

cfg.eye.border_size          = 0.1;  % how many percent of screen should be considered as periphical?


% directories
% -------------------------------------------------------------------------
cfg.dir.eye                  = '~/ownCloud/TIMECONTROL/eye/';  % where are the original *.asc files stored?
cfg.dir.pupil                = 'outputs/pupil/preprocessed/';   % where do we want to save the preprocessed pupil?
cfg.dir.spm                  = '~/matlab_toolboxes/spm12/';  % whre is the SPM installation? Used for high pass filter
cfg.dir.export_fig           = 'export_fig/';

addpath(genpath(cfg.dir.export_fig));  % add export_fig for saving plots
addpath(genpath(cfg.dir.spm));  % add spm for spm_filter function


% figure
% -------------------------------------------------------------------------
cfg.fig.width                = 17.4;  % cm
cfg.fig.height               = 10;  % cm
cfg.fig.fsiz                 = 7;  % font size

cfg.fig.xsubplot             = 3;  % how many collumns of subplots?
cfg.fig.ysubplot             = 3;  % how many rows of subplots?

% open figure
f = figure(1); clf;
set(f, 'color', 'w', 'toolbar', 'none', 'units', 'centimeters', ...
    'position', [0.5 20 cfg.fig.width cfg.fig.height], 'Papertype', 'usletter', ...
    'PaperUnits','centimeters', 'Visible', 'off');


%% LOAD DATA
% =========================================================================

% load data
files = dir(sprintf('%seye*%s*.mat', cfg.dir.eye, subject));  % list files in directory

if ~isempty(files)  % ig there are any files
    
    %% LOADING DATA
    % =========================================================================
    for i_f = 1 : length(files)
        fprintf('Loading file %s...\n', files(i_f).name);
        data{i_f} = load(fullfile(cfg.dir.eye, files(i_f).name));
        fprintf('done.\n');
    end
    
    if size(data, 2) > 1  % if we have more than one file
        if data{1}.eyeTrackdata(1).time ~= data{2}.eyeTrackdata(1).time  % if we are not accidentially recorded in one file
            if data{1}.eyeTrackdata(1).time < data{2}.eyeTrackdata(1).time  % if we started recording with file 1
                eyeTrackdata = [struct2table(data{1}.eyeTrackdata); struct2table(data{2}.eyeTrackdata)];
            else  % if we started recording with file 2
                eyeTrackdata = [struct2table(data{2}.eyeTrackdata); struct2table(data{1}.eyeTrackdata)];
            end
        else % if we are accenetially recorded in one file
            % find longer file and use that one
            if length(data{2}.eyeTrackdata) > length(data{1}.eyeTrackdata)
                eyeTrackdata = struct2table(data{2}.eyeTrackdata);
            else
                eyeTrackdata = struct2table(data{1}.eyeTrackdata);
            end
        end  % if starting time is not the same
    else  % if we have only one file
        eyeTrackdata = struct2table(data{1}.eyeTrackdata);
    end % size
    
            clear data
        
  % add subject id
    subject_id      = cell(size(eyeTrackdata, 1), 1);  % create cell array of subject id
    subject_id(:)   = cellstr(subject);  % fill with subject id
    eyeTrackdata.subject_id = subject_id; % save to table
    
        % plot screen fixations
    subplot(ysubplot, xsubplot, 1);
    plot(eyeTrackdata.LEyeAvgX, -eyeTrackdata.LEyeAvgY, '.');  % plot fixations. Careful, Y axis is inverted in data!
    title('Screen fixations');
    set(gca, 'FontSize', cfg.fig.fsiz);
    
    
    
    %% PREPROCESSING
    % =========================================================================
    
  
      % remove bad states
    % -------------------------------------------------------------------------
    eyeTrackdata.LEyePsize(eyeTrackdata.state ~= good_state) = blink;
    eyeTrackdata.REyePsize(eyeTrackdata.state ~= good_state) = blink;
    
    
    
    % remove fixations outside screen borders
    % -------------------------------------------------------------------------
    eyeTrackdata.LEyePsize(eyeTrackdata.LEyeAvgX < cfg.eye.BorderX) = blink;
    eyeTrackdata.LEyePsize(eyeTrackdata.LEyeAvgY < cfg.eye.BorderY) = blink;
    eyeTrackdata.LEyePsize(eyeTrackdata.LEyeAvgX > cfg.ptb.ScreenX - cfg.eye.BorderX) = blink;
    eyeTrackdata.LEyePsize(eyeTrackdata.LEyeAvgY > cfg.ptb.ScreenY - cfg.eye.BorderY) = blink;
    
    eyeTrackdata.REyePsize(eyeTrackdata.REyeAvgX < cfg.eye.BorderX) = blink;
    eyeTrackdata.REyePsize(eyeTrackdata.REyeAvgY < cfg.eye.BorderY) = blink;
    eyeTrackdata.REyePsize(eyeTrackdata.REyeAvgX > cfg.ptb.ScreenX - cfg.eye.BorderX) = blink;
    eyeTrackdata.REyePsize(eyeTrackdata.REyeAvgY > cfg.ptb.ScreenY - cfg.eye.BorderY) = blink;
    
    
    % TODO correct for gaze position
    % -------------------------------------------------------------------------
    
    % For the eyetracker, the pupil appears to be smaller when looking at
    % the screen border (ellipse cut of the pupil).
    
    
    % exclude samples that are outside mad_cutoff - remove outliers
    % -------------------------------------------------------------------------
    eyeTrackdata.L = ...
        remove_outliers_mad_v01(eyelinkdata(:, strcmp(eyelinkdata_names, 'PS')), ...
        cfg.eye.mad_cutoff, cfg.eye.blink);
    
    
    % how many samples have been rejected?
    % -------------------------------------------------------------------------
    nSamplesRejected = sum(eyelinkdata(:, strcmp(eyelinkdata_names, 'PS')) == ...
        cfg.eye.blink) ./ length(eyelinkdata(:, strcmp(eyelinkdata_names, 'PS')));
    
    
    % plot time series after artifact removal
    % -------------------------------------------------------------------------
    subplot(cfg.fig.ysubplot, cfg.fig.xsubplot, 4 : 6);
    tmp_plot = eyelinkdata(:, strcmp(eyelinkdata_names, 'PS'));
    tmp_plot(tmp_plot == cfg.eye.blink) = nan;  % for plot replace blinks with nan
    plot(tmp_plot);
    tmp_plot = [];  % delete tmp_plot again
    title('pupil after artifact removal'); % plot before high pass filter
    set(gca, 'FontSize', cfg.fig.fsiz);
    
    
    % plot frequency spectrum
    % -------------------------------------------------------------------------
    subplot(cfg.fig.ysubplot, cfg.fig.xsubplot, 2);
    frequency_spectrum_plot(eyelinkdata(:, strcmp(eyelinkdata_names, 'PS')), ...
        cfg.eye.samplingrate_eyelink); % frequency spectrum plot before high pass filter
    title('Before high-pass filter');
    set(gca, 'FontSize', cfg.fig.fsiz);
    
    
    % linear interpolate blinks and bad states +- window
    % -------------------------------------------------------------------------
    eyelinkdata(:, strcmp(eyelinkdata_names, 'PS')) = interpolate_blinks_v01(eyelinkdata(:, ...
        strcmp(eyelinkdata_names, 'PS')), cfg.eye.blink, cfg.eye.samplingrate, cfg.eye.blinkwindow);
    
    
    % band-pass filter to remove slow fluctuations and to smooth
    % -------------------------------------------------------------------------
    eyelinkdata(:, strcmp(eyelinkdata_names, 'PS')) = bandpass_filter_v01(eyelinkdata(:, strcmp(eyelinkdata_names, 'PS')),...
        cfg.eye.samplingrate, cfg.eye.highpass_filter, cfg.eye.lowpass_filter);
    
    
    % downsampling
    % -------------------------------------------------------------------------
    sampling_factor = round(cfg.eye.samplingrate_eyelink ./ cfg.eye.samplingrate);  % by what factor do we need to reduce?
    
    % downsamples with low pass filtering, used for measures
    EYEDATA.PS       = decimate(eyelinkdata(:, strcmp(eyelinkdata_names, 'PS')), sampling_factor);
    %EYEDATA.XP       = decimate(eyelinkdata(:, strcmp(eyelinkdata_names, 'XP')), sampling_factor);
    %EYEDATA.YP       = decimate(eyelinkdata(:, strcmp(eyelinkdata_names, 'YP')), sampling_factor);
    
    % downsample without low pass filtering, used for markers etc.
    EYEDATA.TIME     = downsample(eyelinkdata(:, strcmp(eyelinkdata_names, 'TIME')), sampling_factor);
    EYEDATA.INPUT    = downsample(eyelinkdata(:, strcmp(eyelinkdata_names, 'INPUT')), sampling_factor);
    EYEDATA.SESSION  = downsample(eyelinkdata(:, strcmp(eyelinkdata_names, 'SESSION')), sampling_factor);
    EYEDATA.BLOCK    = downsample(eyelinkdata(:, strcmp(eyelinkdata_names, 'BLOCK')), sampling_factor);
    
    % only include the next variables if you really need them later
    % EYEDATA.BUTTON   = downsample(eyelinkdata(:, strcmp(eyelinkdata_names, 'BUTTON')), sampling_factor);
    % EYEDATA.BLINK    = downsample(eyelinkdata(:, strcmp(eyelinkdata_names, 'BLINK')), sampling_factor);
    % EYEDATA.SACCADE  = downsample(eyelinkdata(:, strcmp(eyelinkdata_names, 'SACCADE')), sampling_factor);
    % EYEDATA.FIXATION = downsample(eyelinkdata(:, strcmp(eyelinkdata_names, 'FIXATION')), sampling_factor);
    
    % clear big arrays to save memory
    clear eyelinkdata
    
    % replace single nan values in INPUT
    % -------------------------------------------------------------------------
    if any(isnan(EYEDATA.INPUT))
        
        nansamples = find(isnan(EYEDATA.INPUT));
        nansamples(nansamples == 1) = [];
        EYEDATA.INPUT(nansamples) = EYEDATA.INPUT(nansamples - 1);
        fprintf('Removed NaN in EYEDATA.INPUT.\n');
    end
    
    
    % z-score pupil time series
    % -------------------------------------------------------------------------
    EYEDATA.PsizeZ = zscore(EYEDATA.PS);
    EYEDATA = removefields(EYEDATA, 'PS');
    
    % plot after filter and smoothing
    % -------------------------------------------------------------------------
    subplot(cfg.fig.ysubplot, cfg.fig.xsubplot, 7 : 9);
    plot(EYEDATA.PsizeZ);
    title('Pupil after high-pass filter and smoothing');
    set(gca, 'FontSize', cfg.fig.fsiz);
    
    subplot(cfg.fig.ysubplot, cfg.fig.xsubplot, 3);
    frequency_spectrum_plot(EYEDATA.PsizeZ, cfg.eye.samplingrate);
    title('After high-pass filter');
    set(gca, 'FontSize', cfg.fig.fsiz);
    
    
    % save data
    % -------------------------------------------------------------------------
    
    % convert to table
    EYEDATA = struct2table(EYEDATA);
    
    % add subject id
    subject_id      = cell(size(EYEDATA, 1), 1);  % create cell array of subject id
    subject_id(:)   = cellstr(subject);  % fill with subject id
    EYEDATA.subject_id = subject_id; % save to table
    
    % filename
    savewhere = sprintf('%seyelink_%s_pupil_preprocessed_%s_session_%02i', cfg.dir.pupil, condition, subject, session);  % construct file name
    
    % save EYEDATA as *.mat file
    save([savewhere '.mat'], 'EYEDATA', 'nSamplesRejected', 'fname');  % save processed pupil
    
    % save control figure
    export_fig([savewhere '.png'], '-r300', '-nocrop');  % save figure
    close(f);  % close figure
    
    % give feedback on console
    fprintf('Pupil preprocessing done - %.2f%% of samples rejected.\n', sum(nSamplesRejected) * 100);  % done :)
    
    % clear big arrays to save memory
    clear EYEDATA
    
else
    disp('No files found.');
end   % if any files exist
end  % main function

