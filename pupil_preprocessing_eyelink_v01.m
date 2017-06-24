function [] = pupil_preprocessing_eyelink_v01(subject, condition, session)
% function [] = pupil_preprocessing_eyelink_v01(subject, condition, session)
%   Preprocessing of pupil recordings.
%   cfg: configuration structure
%   subject: current subject, ID_INITIALS, e.g. 111_aw
%   condition: condition to be processed.
%   session: session n umber to be processed
%
%   Author: Antonius Wiehler <antonius.wiehler@gmail.com>
%   Original: 2017-01-12
%   Modified: 2017-06-23



%% PARAMETERS
% =========================================================================

% screen
% -------------------------------------------------------------------------
cfg.ptb.ScreenX              = 1024; % screen size X TODO: read from PTB
cfg.ptb.ScreenY              = 768; % screen size Y TODO: read from PTB


% eye tracker
% -------------------------------------------------------------------------
cfg.eye.samplingrate_eyelink = 1000;   % sampling rate we want to have after pre processing
cfg.eye.samplingrate         = 250;   % sampling rate we want to have after pre processing


% preprocessing parameter
% -------------------------------------------------------------------------
cfg.eye.blink                = 0;  % how to mark a blink in the pupil time series
cfg.eye.blinkwindow          = 0.1;  % how many seconds before and after blink do we want to remove?
cfg.eye.std_cutoff           = 3;    % ouliers of how many sd should be rejected?
cfg.eye.high_pass_filter     = 128;  % pupil highpass filter in seconds
cfg.eye.smoothing_samples    = cfg.eye.samplingrate .* 2;  % window size for smoothing
cfg.eye.BorderX              = round(cfg.ptb.ScreenX .* 0.1);  % Screen border for rejection
cfg.eye.BorderY              = round(cfg.ptb.ScreenY .* 0.1);  % Screen border for rejection


% directories
% -------------------------------------------------------------------------
cfg.dir.eye                  = 'outputs/eyelink/';  % where are the original *.asc files stored?
cfg.dir.pupil                = 'outputs/pupil/';   % where do we want to save the preprocessed pupil?
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
files = dir(sprintf('%seyelink_%s_%s_*sess_%03i*.asc', cfg.dir.eye, condition, subject, session));  % list files in directory

if ~isempty(files)  % ig there are any files
    
    % check if the block number is divergent from number in file name
    last_filename = files(end).name;
    last_filename = last_filename(1 : end - 8);
    last_filename = strsplit(last_filename, '_');
    last_block    = str2double(last_filename{end});
    
    if last_block ~= size(files, 1)
        warning('Found eyelink files do not match block numbers.');
    end
    
    eyeTrackdata = [];  % pre allocate empty. Data will be added later.
    
    for i_f = 1 : size(files, 1)
        
        fname = files(i_f).name;  % file name of eye recordings
        disp(fname);
        
        asc = readEyelink(fullfile(cfg.dir.eye, fname));  % load file and struct eyeTrackdata
        
        if isempty(asc)
            error('Eye Tracking data is empty.');
        end
        
        
        % remove rows when timing is nan
        % -------------------------------------------------------------------------
        nanrows = find(isnan(asc.Numeric_events(:, 1)));  % find rows where time stamp is nan
        
        if any(diff(nanrows) > 10 & diff(nanrows) < 1000)
            error('Nan timing during measurement detected.');  % nan timing at begin and end of measurement is normal
        end
        
        asc.Numeric_events(nanrows, :) = [];  % delete nan rows
        
        
        % check distance between blocks from time stamp. Add spacing, so
        % filters work correctly
        % -------------------------------------------------------------------------
        
        if i_f > 1
            missing_samples    = asc.Numeric_events(1, 1) - eyeTrackdata(end, 1) - 1;  % how many samples are missing between the begin of the current block and the end of the previous one?
            missing            = nan(missing_samples, size(asc.Numeric_events, 2));  % pre allocate as nan
            missing(:, 1)      = (eyeTrackdata(end, 1) + 1) :  (asc.Numeric_events(1, 1) - 1);  % add missing time stamps
            asc.Numeric_events = [missing; asc.Numeric_events];  % add at begin of new data
        end
        
        
        % add session number as collumn
        % -------------------------------------------------------------------------
        asc.Numeric_events(:, end + 1) = session;
        
        
        % add block number (from file names) as collumn
        % -------------------------------------------------------------------------
        fname = fname(1 : end - 8);
        fname = strsplit(fname, '_');
        block = str2double(fname{end});
        asc.Numeric_events(:, end + 1) = block;
        
        
        % add block to data
        % -------------------------------------------------------------------------
        eyeTrackdata = [eyeTrackdata; asc.Numeric_events];
        
    end % for loop files
    
    
    
    % save row names for later
    % -------------------------------------------------------------------------
    eyeTrackdata_names = asc.Numeric_row_names;
    eyeTrackdata_names(end +1) = {'SESSION'};
    eyeTrackdata_names(end +1) = {'BLOCK'};
    
    % plot screen fixations
    subplot(cfg.fig.ysubplot, cfg.fig.xsubplot, 1);
    plot(eyeTrackdata(:, strcmp(eyeTrackdata_names, 'XP')), -eyeTrackdata(:, strcmp(eyeTrackdata_names, 'YP')), '.');  % plot fixations. Careful, Y axis is inverted in data!
    title('Screen fixations');
    set(gca, 'FontSize', cfg.fig.fsiz);
    
    
    
    %% PREPROCESSING
    % =========================================================================
    
    % remove bad states
    % -------------------------------------------------------------------------
    blink_rows = eyeTrackdata(:, strcmp(eyeTrackdata_names, 'BLINK')) == 1;  % where are blinks detected by the eyetracker?
    eyeTrackdata(blink_rows, strcmp(eyeTrackdata_names, 'PS')) = cfg.eye.blink;
    
    blink_rows = isnan(eyeTrackdata(:, strcmp(eyeTrackdata_names, 'PS')));  % where was no recording?
    eyeTrackdata(blink_rows, strcmp(eyeTrackdata_names, 'PS')) = cfg.eye.blink;
    
    
    % remove fixations outside screen
    % -------------------------------------------------------------------------
    border_rows1 = eyeTrackdata(:, strcmp(eyeTrackdata_names, 'XP')) < cfg.eye.BorderX;
    border_rows2 = eyeTrackdata(:, strcmp(eyeTrackdata_names, 'XP')) > cfg.ptb.ScreenX - cfg.eye.BorderX;
    
    border_rows3 = eyeTrackdata(:, strcmp(eyeTrackdata_names, 'YP')) < cfg.eye.BorderY;
    border_rows4 = eyeTrackdata(:, strcmp(eyeTrackdata_names, 'YP')) > cfg.ptb.ScreenY - cfg.eye.BorderY;
    
    eyeTrackdata(border_rows1 | border_rows2 | border_rows3 | border_rows4, strcmp(eyeTrackdata_names, 'PS')) = cfg.eye.blink;
    
    
    % TODO correct for gaze position
    % -------------------------------------------------------------------------
    
    % For the eyetracker, the pupil appears to be smaller when looking at
    % the screen border (ellipse cut of the pupil).
    
    
    % exclude samples that are outside std_cutoff - remove outliers
    % -------------------------------------------------------------------------
    eyeTrackdata(:, strcmp(eyeTrackdata_names, 'PS')) = ...
        remove_outliers_v01(eyeTrackdata(:, strcmp(eyeTrackdata_names, 'PS')), ...
        cfg.eye.std_cutoff, cfg.eye.blink);
    
    
    % how many samples have been rejected?
    % -------------------------------------------------------------------------
    
    nSamplesRejected = sum(eyeTrackdata(:, strcmp(eyeTrackdata_names, 'PS')) == ...
        cfg.eye.blink) ./ length(eyeTrackdata(:, strcmp(eyeTrackdata_names, 'PS')));
    
    
    % plot time series after artifact removal
    % -------------------------------------------------------------------------
    subplot(cfg.fig.ysubplot, cfg.fig.xsubplot, 4 : 6);
    tmp_plot = eyeTrackdata(:, strcmp(eyeTrackdata_names, 'PS'));
    tmp_plot(tmp_plot == cfg.eye.blink) = nan;  % for plot replace blinks with nan
    plot(tmp_plot);
    tmp_plot = [];  % delete tmp_plot again
    title('pupil after artifact removal'); % plot before high pass filter
    set(gca, 'FontSize', cfg.fig.fsiz);
    
    
    % plot frequency spectrum
    % -------------------------------------------------------------------------
    subplot(cfg.fig.ysubplot, cfg.fig.xsubplot, 2);
    frequency_spectrum_plot(eyeTrackdata(:, strcmp(eyeTrackdata_names, 'PS')), ...
        cfg.eye.samplingrate_eyelink); % frequency spectrum plot before high pass filter
    title('Before high-pass filter');
    set(gca, 'FontSize', cfg.fig.fsiz);
    
    
    % linear interpolate blinks and bad states +- window
    % -------------------------------------------------------------------------
    eyeTrackdata(:, strcmp(eyeTrackdata_names, 'PS')) = interpolate_blinks_v01(eyeTrackdata(:, ...
        strcmp(eyeTrackdata_names, 'PS')), cfg.eye.blink, cfg.eye.samplingrate, cfg.eye.blinkwindow);
    
    
    % high-pass filter
    % -------------------------------------------------------------------------
    % set up parameters for spm filter
    K.RT     = 1 ./ cfg.eye.samplingrate;
    K.row    = 1 : length(eyeTrackdata(:, strcmp(eyeTrackdata_names, 'PS'))); % corresponds to the length of convreg
    K.HParam = cfg.eye.high_pass_filter;  % cut-off time in seconds
    nK       = spm_filter(K);  % generate filter parameters
    
    eyeTrackdata(:, strcmp(eyeTrackdata_names, 'PS')) = spm_filter(nK, eyeTrackdata(:, strcmp(eyeTrackdata_names, 'PS')));  % apply filter
    
    
    % downsampling
    % -------------------------------------------------------------------------
    sampling_factor = round(cfg.eye.samplingrate_eyelink ./ cfg.eye.samplingrate);  % by what factor do we need to reduce?
    
    % downsamples with low pass filtering, used for measures
    EYEDATA.PS       = decimate(eyeTrackdata(:, strcmp(eyeTrackdata_names, 'PS')), sampling_factor);
    EYEDATA.XP       = decimate(eyeTrackdata(:, strcmp(eyeTrackdata_names, 'XP')), sampling_factor);
    EYEDATA.YP       = decimate(eyeTrackdata(:, strcmp(eyeTrackdata_names, 'YP')), sampling_factor);
    
    % downsample without low pass filtering, for markers etc.
    EYEDATA.TIME     = downsample(eyeTrackdata(:, strcmp(eyeTrackdata_names, 'TIME')), sampling_factor);
    EYEDATA.INPUT    = downsample(eyeTrackdata(:, strcmp(eyeTrackdata_names, 'INPUT')), sampling_factor);
    EYEDATA.BUTTON   = downsample(eyeTrackdata(:, strcmp(eyeTrackdata_names, 'BUTTON')), sampling_factor);
    EYEDATA.BLINK    = downsample(eyeTrackdata(:, strcmp(eyeTrackdata_names, 'BLINK')), sampling_factor);
    EYEDATA.SACCADE  = downsample(eyeTrackdata(:, strcmp(eyeTrackdata_names, 'SACCADE')), sampling_factor);
    EYEDATA.FIXATION = downsample(eyeTrackdata(:, strcmp(eyeTrackdata_names, 'FIXATION')), sampling_factor);
    EYEDATA.SESSION  = downsample(eyeTrackdata(:, strcmp(eyeTrackdata_names, 'SESSION')), sampling_factor);
    EYEDATA.BLOCK    = downsample(eyeTrackdata(:, strcmp(eyeTrackdata_names, 'BLOCK')), sampling_factor);
    
    
    % z-score pupil time series
    % -------------------------------------------------------------------------
    EYEDATA.PsizeZ = zscore(EYEDATA.PS);
    
    
    % temporal smoothing
    % -------------------------------------------------------------------------
    
    var_kernel_temporal = floor(cfg.eye.smoothing_samples/100);  % width of the smoothing
    autocorrelation_kernel_temporal = exp(-0.5 .* ((1 : cfg.eye.smoothing_samples) - cfg.eye.smoothing_samples / 2) .^ 2 / var_kernel_temporal);
    autocorrelation_kernel_temporal = autocorrelation_kernel_temporal / sum(autocorrelation_kernel_temporal);
    
    EYEDATA.PsizeZ = conv2(EYEDATA.PsizeZ, autocorrelation_kernel_temporal, 'same');
    
    
    
    % plot after filter and smoothing
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
    EYEDATA = struct2table(EYEDATA); % convert to table, EYEDATA is loaded before
    
    % add subject id
    subject_id      = cell(size(EYEDATA, 1), 1);  % create cell array of subject id
    subject_id(:)   = cellstr(subject);  % fill with subject id
    EYEDATA.subject_id = subject_id; % save to table
    
    savewhere = sprintf('%seyelink_%s_pupil_preprocessed_%s_session_%02i', cfg.dir.pupil, condition, subject, session);  % construct file name
    
    save([savewhere '.mat'], 'EYEDATA', 'nSamplesRejected', 'fname');  % save processed pupil
    
    export_fig([savewhere '.png'], '-r300', '-nocrop');  % save figure
    close(f);  % close figure
    
    fprintf('Pupil preprocessing done - %.2f%% of samples rejected.\n', sum(nSamplesRejected) * 100);  % done :)
    
    clear EYEDATA eyeTrackdata
    
else
    disp('No files found.');
end   % if any files exist
end  % main function

