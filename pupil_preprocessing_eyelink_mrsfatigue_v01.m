function [] = pupil_preprocessing_eyelink_mrsfatigue_v01(subject, condition, session)
% function [] = pupil_preprocessing_eyelink_mrsfatigue_v01(subject, condition, session)
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
cfg.eye.blink                = 0;   % how to mark a blink in the pupil time series
cfg.eye.blinkwindow          = 0.1;  % how many seconds before and after blink do we want to remove?
cfg.eye.std_cutoff           = 3;    % ouliers of how many sd should be rejected?
cfg.eye.highpass_filter      = 1/128;  % pupil highpass filter in Hz.
cfg.eye.lowpass_filter       = 1;    % Filter everything faster than this Hz.

cfg.eye.border_size          = 0.1;  % how many percent of screen should be considered as periphical?
% directories
% -------------------------------------------------------------------------
cfg.dir.eye                  = 'outputs/eyelink/';  % where are the original *.asc files stored?
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
    
    eyelinkdata = [];  % pre allocate empty. Data will be added later.
    
    for i_f = 1 : size(files, 1)
        
        fname = files(i_f).name;  % file name of eye recordings
        disp(fname);
        
        asc = readEyelink(fullfile(cfg.dir.eye, fname));  % load file and struct eyelinkdata
        
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
            missing_samples    = asc.Numeric_events(1, 1) - eyelinkdata(end, 1) - 1;  % how many samples are missing between the begin of the current block and the end of the previous one?
            missing            = nan(missing_samples, size(asc.Numeric_events, 2));  % pre allocate as nan
            missing(:, 1)      = (eyelinkdata(end, 1) + 1) :  (asc.Numeric_events(1, 1) - 1);  % add missing time stamps
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
        eyelinkdata = [eyelinkdata; asc.Numeric_events];
        
    end % for loop files
    
    
    % save row names for later
    % -------------------------------------------------------------------------
    eyelinkdata_names = asc.Numeric_row_names;
    eyelinkdata_names(end +1) = {'SESSION'};
    eyelinkdata_names(end +1) = {'BLOCK'};
    
    clear asc  % save memory
    
    
    % plot screen fixations
    subplot(cfg.fig.ysubplot, cfg.fig.xsubplot, 1);
    plot(eyelinkdata(:, strcmp(eyelinkdata_names, 'XP')), -eyelinkdata(:, strcmp(eyelinkdata_names, 'YP')), '.');  % plot fixations. Careful, Y axis is inverted in data!
    title('Screen fixations');
    set(gca, 'FontSize', cfg.fig.fsiz);
    
    
    
    %% PREPROCESSING
    % =========================================================================
    
    % remove bad states
    % -------------------------------------------------------------------------
    blink_rows = eyelinkdata(:, strcmp(eyelinkdata_names, 'BLINK')) == 1;  % where are blinks detected by the eyetracker?
    eyelinkdata(blink_rows, strcmp(eyelinkdata_names, 'PS')) = cfg.eye.blink;
    
    blink_rows = isnan(eyelinkdata(:, strcmp(eyelinkdata_names, 'PS')));  % where was no recording?
    eyelinkdata(blink_rows, strcmp(eyelinkdata_names, 'PS')) = cfg.eye.blink;
    
    clear blink_rows
    
    
    % remove fixations outside screen borders
    % -------------------------------------------------------------------------
    eyelinkdata(:, strcmp(eyelinkdata_names, 'XP')) = delete_periphical_fixations_v01(eyelinkdata(:, strcmp(eyelinkdata_names, 'XP')),...
        eyelinkdata(:, strcmp(eyelinkdata_names, 'XP')), ...
        eyelinkdata(:, strcmp(eyelinkdata_names, 'YP')), ...
        cfg.ptb.ScreenX, cfg.ptb.ScreenY, cfg.eye.border_size, cfg.eye.blink);
    
    
    % TODO correct for gaze position
    % -------------------------------------------------------------------------
    
    % For the eyetracker, the pupil appears to be smaller when looking at
    % the screen border (ellipse cut of the pupil).
    
    
    % exclude samples that are outside std_cutoff - remove outliers
    % -------------------------------------------------------------------------
    eyelinkdata(:, strcmp(eyelinkdata_names, 'PS')) = ...
        remove_outliers_v01(eyelinkdata(:, strcmp(eyelinkdata_names, 'PS')), ...
        cfg.eye.std_cutoff, cfg.eye.blink);
    
    
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

