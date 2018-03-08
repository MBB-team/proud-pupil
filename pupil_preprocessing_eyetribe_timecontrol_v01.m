function [] = pupil_preprocessing_eyetribe_timecontrol_v01(subject)
% function [] = pupil_preprocessing_eyetribe_timecontrol_v01(subject)
%   Preprocessing of pupil recordings.
%   cfg: configuration structure
%   subject: current subject, ID_INITIALS, e.g. 111_aw
%   condition: condition to be processed.
%   session: session n umber to be processed
%
%   Author: Antonius Wiehler <antonius.wiehler@gmail.com>
%   Original: 2017-10-30
%   Modified: 2018-03-02



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
cfg.eye.goodstate            = 7;    % good state of eye tracker. / for eye tribe
cfg.eye.blink                = 0;   % how to mark a blink in the pupil time series
cfg.eye.blinkwindow          = 0.125;  % how many seconds before and after blink do we want to remove?
cfg.eye.mad_cutoff           = 3;    % ouliers of how many mad should be rejected? (median deviance)
cfg.eye.highpass_filter      = 1/128;  % pupil highpass filter in Hz.
cfg.eye.lowpass_filter       = 1;    % Filter everything faster than this Hz.
cfg.eye.border_size          = 0.1;  % how many percent of screen should be considered as periphical?
cfg.eye.delete_at_begin      = 2000;  % how many samples at the beginning should be deleted to remove filter artifacts?


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
    subplot(cfg.fig.ysubplot, cfg.fig.xsubplot, 1);
    plot(eyeTrackdata.LEyeAvgX, -eyeTrackdata.LEyeAvgY, '.');  % plot fixations. Careful, Y axis is inverted in data!
    title('Screen fixations');
    set(gca, 'FontSize', cfg.fig.fsiz);
    
    
    
    %% PREPROCESSING
    % =========================================================================
    
    
    % remove bad states -  based on eyetribe state bits (see manual)/
    % -------------------------------------------------------------------------
    eyeTrackdata.LEyePsize(eyeTrackdata.state > cfg.eye.goodstate) = cfg.eye.blink;
    eyeTrackdata.REyePsize(eyeTrackdata.state > cfg.eye.goodstate) = cfg.eye.blink;
    
    
    
    % remove fixations outside screen borders
    % -------------------------------------------------------------------------
    
    % TODO delete_periphical_fixations_v01 is commented right now, because
    % we have a pupil signal, although x and y could be 0 (and would be
    % filtered otherwise)
    
    eyeTrackdata.LEyePsize = delete_periphical_fixations_v01(eyeTrackdata.LEyePsize, eyeTrackdata.LEyeAvgX, eyeTrackdata.LEyeAvgY, ...
        cfg.ptb.ScreenX, cfg.ptb.ScreenY, cfg.eye.border_size, cfg.eye.blink);
    
    eyeTrackdata.REyePsize = delete_periphical_fixations_v01(eyeTrackdata.REyePsize, eyeTrackdata.REyeAvgX, eyeTrackdata.REyeAvgY, ...
        cfg.ptb.ScreenX, cfg.ptb.ScreenY, cfg.eye.border_size, cfg.eye.blink);
    
    
    % TODO correct for gaze position
    % -------------------------------------------------------------------------
    
    % For the eyetracker, the pupil appears to be smaller when looking at
    % the screen border (ellipse cut of the pupil).
    
    
    % exclude samples that are outside mad_cutoff - remove outliers
    % -------------------------------------------------------------------------
    eyeTrackdata.LEyePsize = ...
        remove_outliers_mad_v01(eyeTrackdata.LEyePsize, ...
        cfg.eye.mad_cutoff, cfg.eye.blink);
    
    eyeTrackdata.REyePsize = ...
        remove_outliers_mad_v01(eyeTrackdata.REyePsize, ...
        cfg.eye.mad_cutoff, cfg.eye.blink);
    
    % how many samples have been rejected?
    % -------------------------------------------------------------------------
    nSamplesRejected = (sum(eyeTrackdata.LEyePsize == cfg.eye.blink) + sum(eyeTrackdata.REyePsize == cfg.eye.blink))...
        ./ (length(eyeTrackdata.LEyePsize) + length(eyeTrackdata.REyePsize));
    
    
    % plot time series after artifact removal
    % -------------------------------------------------------------------------
    subplot(cfg.fig.ysubplot, cfg.fig.xsubplot, 4 : 6);
    tmp_plot = eyeTrackdata.LEyePsize;
    tmp_plot(tmp_plot == cfg.eye.blink) = nan;  % for plot replace blinks with nan
    plot(tmp_plot);
    tmp_plot = [];
    title('L pupil after artifact removal'); % plot before high pass filter
    set(gca, 'FontSize', cfg.fig.fsiz);
    
    
    % determine measured sampling rate
    % -------------------------------------------------------------------------
    samplingrate = eyetribe_estimate_samplingrate_v01(eyeTrackdata.time);
    samplingrate = round(samplingrate);
    
    fprintf('The estimated samplingrate is %02.2f Hz.\n', samplingrate);
    
    % plot frequency spectrum
    % -------------------------------------------------------------------------
    subplot(cfg.fig.ysubplot, cfg.fig.xsubplot, 2);
    frequency_spectrum_plot(eyeTrackdata.LEyePsize, ...
        samplingrate); % frequency spectrum plot before high pass filter
    title('Before high-pass filter');
    set(gca, 'FontSize', cfg.fig.fsiz);
    
    
    % linear interpolate blinks and bad states +- window
    % -------------------------------------------------------------------------
    [eyeTrackdata.LEyePsize, blink_indxL] = interpolate_blinks_v01(eyeTrackdata.LEyePsize, cfg.eye.blink, samplingrate, cfg.eye.blinkwindow);
    [eyeTrackdata.REyePsize, blink_indxR] = interpolate_blinks_v01(eyeTrackdata.REyePsize, cfg.eye.blink, samplingrate, cfg.eye.blinkwindow);
    
    
    % band-pass filter to remove slow fluctuations and to smooth
    % -------------------------------------------------------------------------
    eyeTrackdata.LEyePsize = bandpass_filter_v01(eyeTrackdata.LEyePsize,...
        samplingrate, cfg.eye.highpass_filter, cfg.eye.lowpass_filter);
    
    eyeTrackdata.REyePsize = bandpass_filter_v01(eyeTrackdata.REyePsize,...
        samplingrate, cfg.eye.highpass_filter, cfg.eye.lowpass_filter);
    
    
    % linear interpolate blinks and bad states +- window again to avoid
    % bandpass filter artefacts
    % -------------------------------------------------------------------------
    blink_indxL(1 : cfg.eye.delete_at_begin) = 1;  % to remove filter artefacts at start
    blink_indxR(1 : cfg.eye.delete_at_begin) = 1;  % to remove filter artefacts at start
    
    eyeTrackdata.LEyePsize(blink_indxL) = cfg.eye.blink;
    eyeTrackdata.REyePsize(blink_indxR) = cfg.eye.blink;
    
    eyeTrackdata.LEyePsize = interpolate_blinks_v01(eyeTrackdata.LEyePsize, cfg.eye.blink, samplingrate, cfg.eye.blinkwindow);
    eyeTrackdata.REyePsize = interpolate_blinks_v01(eyeTrackdata.REyePsize, cfg.eye.blink, samplingrate, cfg.eye.blinkwindow);
    
    
    % interpolate to target sampling rate
    % -------------------------------------------------------------------------
    if samplingrate == 30
        
        x = 1 : size(eyeTrackdata.time);
        xq = 1 : 0.5 : size(eyeTrackdata.time) + 1;
        eyeTrackdata_upsampled = table();
        eyeTrackdata_upsampled.time = interp1(x, eyeTrackdata.time, xq)';
        eyeTrackdata_upsampled.REyePsize = interp1(x, eyeTrackdata.REyePsize, xq)';
        eyeTrackdata_upsampled.LEyePsize = interp1(x, eyeTrackdata.LEyePsize, xq)';
        eyeTrackdata_upsampled.scene = interp1(x, eyeTrackdata.scene, xq)';
        eyeTrackdata_upsampled.mark = interp1(x, eyeTrackdata.mark, xq)';
        
        eyeTrackdata_upsampled = eyeTrackdata_upsampled(1:end-2, :);  % remove last to samples because they are likely nan
        eyeTrackdata = eyeTrackdata_upsampled;
    end  % if measured sampling rate is not the right one
    
    % average eyes
    % -------------------------------------------------------------------------
    eyeTrackdata.Psize = nanmean([eyeTrackdata.REyePsize eyeTrackdata.LEyePsize], 2); % mean of both eyes
    
    % z-score
    % -------------------------------------------------------------------------
    eyeTrackdata.PsizeZ = zscore(eyeTrackdata.Psize);
    
    
    
    % plot after filter and smoothing
    % -------------------------------------------------------------------------
    subplot(cfg.fig.ysubplot, cfg.fig.xsubplot, 7 : 9);
    plot(eyeTrackdata.PsizeZ);
    title('Pupil after high-pass filter and smoothing');
    set(gca, 'FontSize', cfg.fig.fsiz);
    
    subplot(cfg.fig.ysubplot, cfg.fig.xsubplot, 3);
    frequency_spectrum_plot(eyeTrackdata.PsizeZ, cfg.eye.samplingrate);
    title('After high-pass filter');
    set(gca, 'FontSize', cfg.fig.fsiz);
    
    
    
    % save data
    % -------------------------------------------------------------------------
    
    % add subject id
    subject_id      = cell(size(eyeTrackdata, 1), 1);  % create cell array of subject id
    subject_id(:)   = cellstr(subject);  % fill with subject id
    eyeTrackdata.subject_id = subject_id; % save to table
    
    eyeTrackdata = eyeTrackdata(:, {'subject_id', 'time', 'scene', 'mark' 'PsizeZ'});  % select only timing and preprocessed pupil
    
    savewhere = sprintf('%seye_pupil_preprocessed_%s', cfg.dir.pupil, subject);  % construct file name
    
    save([savewhere '.mat'], 'eyeTrackdata', 'nSamplesRejected');  % save processed pupil
    
    export_fig([savewhere '.png'], '-r300', '-nocrop');  % save figure
    close(f);  % close figure
    
    fprintf('Pupil preprocessing done - %.2f%% of samples rejected.\n', sum(nSamplesRejected) * 100);  % done :)
    
    
else
    disp('No files found.');
end   % if any files exist
end  % main function

