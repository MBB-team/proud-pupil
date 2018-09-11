function [] = pupil_preprocessing_eyetribe_timecontrol_v02(subject)
% function [] = pupil_preprocessing_eyetribe_timecontrol_v02(subject)
%   Preprocessing of pupil recordings.
%   cfg: configuration structure
%   subject: current subject, ID_INITIALS, e.g. 111_aw
%   condition: condition to be processed.
%   session: session number to be processed
%
%   Author: Antonius Wiehler <antonius.wiehler@gmail.com>
%   Original: 2018-04-11
%   Modified: 2018-07-24



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
        
        if isempty(data{i_f}.eyeTrackdata)  % if there is no data in it delete file
            data(i_f) = [];
        end
        
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
    ndhist(eyeTrackdata.LEyeAvgX, -eyeTrackdata.LEyeAvgY, 'filter', 15);  % plot heat map of fixations. Careful, Y axis is inverted in data!
    
    title('Screen fixations');
    set(gca, 'FontSize', cfg.fig.fsiz);
    
    
    
    %% PREPROCESSING
    % =========================================================================
    
    % create vector of valid recordings
    % -------------------------------------------------------------------------
    valid_recording = ones(size(eyeTrackdata, 1), 1);
    
    
    % remove bad states -  based on eyetribe state bits (see manual)/
    % -------------------------------------------------------------------------
    valid_recording(eyeTrackdata.state > cfg.eye.goodstate) = 0;
    
    
    % remove fixations outside screen borders
    % -------------------------------------------------------------------------
%     [~, outside_samples_L] = delete_periphical_fixations_v01(eyeTrackdata.LEyePsize, eyeTrackdata.LEyeAvgX, eyeTrackdata.LEyeAvgY, ...
%         cfg.ptb.ScreenX, cfg.ptb.ScreenY, cfg.eye.border_size, cfg.eye.blink);
%     
%     [~, outside_samples_R] = delete_periphical_fixations_v01(eyeTrackdata.REyePsize, eyeTrackdata.REyeAvgX, eyeTrackdata.REyeAvgY, ...
%         cfg.ptb.ScreenX, cfg.ptb.ScreenY, cfg.eye.border_size, cfg.eye.blink);
%     
%     
%     valid_recording(outside_samples_L) = 0;
%     valid_recording(outside_samples_R) = 0;
    
    
    % interpolate to target sampling rate
    % -------------------------------------------------------------------------
    
    samplingrate = eyetribe_estimate_samplingrate_v01(eyeTrackdata.time);
    samplingrate = round(samplingrate);
    
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
        
        valid_recording = interp1(x, valid_recording, xq)';
        valid_recording = valid_recording(1:end-2);
    end  % if measured sampling rate is not the right one
    
    valid_recording = valid_recording == 1;  % fix interpolation problems
    
    
    
    % plot time series before artifact removal
    % -------------------------------------------------------------------------
    subplot(cfg.fig.ysubplot, cfg.fig.xsubplot, 4 : 6);
    tmp_plot = eyeTrackdata.LEyePsize;
    tmp_plot(~valid_recording) = nan;  % for plot replace blinks with nan
    plot(tmp_plot);
    tmp_plot = [];
    title('L pupil before artifact removal'); % plot before high pass filter
    set(gca, 'FontSize', cfg.fig.fsiz);
    
    
    
    % plot frequency spectrum
    % -------------------------------------------------------------------------
    subplot(cfg.fig.ysubplot, cfg.fig.xsubplot, 2);
    frequency_spectrum_plot(eyeTrackdata.LEyePsize, ...
        samplingrate); % frequency spectrum plot before high pass filter
    title('Before high-pass filter');
    set(gca, 'FontSize', cfg.fig.fsiz);
    
    
    
    % MAIN PREPROCESSING
    % -------------------------------------------------------------------------
    [eyeTrackdata.LEyePsize, eyeTrackdata.time, sampling_factor, pSamplesRejected] = pupil_preprocessing_canonical_v03(eyeTrackdata.time, eyeTrackdata.LEyePsize, valid_recording, 1, 1, 1, 1, 1);
    [eyeTrackdata.REyePsize, eyeTrackdata.time] = pupil_preprocessing_canonical_v03(eyeTrackdata.time, eyeTrackdata.REyePsize, valid_recording, 1, 1, 1, 1, 1);
    
    
    % average eyes
    % -------------------------------------------------------------------------
    eyeTrackdata.PsizeZ = nanmean([eyeTrackdata.REyePsize eyeTrackdata.LEyePsize], 2); % mean of both eyes
    
    
    
    
    % plot after filter and smoothing
    % -------------------------------------------------------------------------
    subplot(cfg.fig.ysubplot, cfg.fig.xsubplot, 7 : 9);
    plot(eyeTrackdata.PsizeZ);
    title(sprintf('Pupil after high-pass filter and smoothing - %.2f%% of samples rejected', sum(pSamplesRejected) * 100));
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
    
    save([savewhere '.mat'], 'eyeTrackdata', 'valid_recording');  % save processed pupil
    
    export_fig([savewhere '.png'], '-r300', '-nocrop');  % save figure
    close(f);  % close figure
    
    
    
else
    disp('No files found.');
end   % if any files exist
end  % main function

