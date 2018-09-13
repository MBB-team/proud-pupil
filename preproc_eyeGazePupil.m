function [eyeTime, X_eyeCoord, Y_eyeCoord, pupil_diam, z_pupil_diam, nanEpisodes] = preproc_eyeGazePupil(asc, x_screen, y_screen, samplingRate, disp_gr)
%preproc_eyeGazePupil function to make the preprocessing of the eye gaze
%and pupil data before using analytical scripts to check any correlation
%with the variables of interest.
%
% INPUTS
% asc: raw eye signal structure containing:
% asc.button: TTL info
% asc.dat(1,:): time (in s) calibrated to the first TTL (or to any other
% signal signifying the start of your experiment) before using this script
% asc.dat(2,:): x position of the eye on the screen
% asc.dat(3,:): y position of the eye on the screen
% asc.dat(4,:): pupil diameter (in mm)
%
% x_screen: screen size in x coordinate
%
% y_screen: screen size in y coordinate
%
% samplingRate: sampling rate of the eye-tracker used in Hz
%
% disp_gr: display graph of the signal at each timestep (1) or not (0)?
%
% OUTPUTS
% eyeTime: time info corresponding to each time point
%
% X_eyeCoord: X position of the eye on the screen
%
% Y_eyeCoord: Y position of the eye on the screen
%
% pupil_diam: preprocessed pupil diameter
%
% z_pupil_diam: zscored preprocessed pupil diameter
%
% nanEpisodes: structure containing info about blink/loss-of-eye episodes
% nanEpisodes.blink_episodes : binary vector of when the signal was lost (because of a
% blink or just a loss) to keep track of these episodes and eventually
% exclude them from further analysis if one of these episodes was too long
% nanEpisodes.blink_start: index for blink start
% nanEpisodes.blink_stop: index for blink stop
%
%
% See also read_eyelink_1_asc_kk.m, butter, filter.
% Initially developed by Nicolas Clairis <nicolas.clairis@protonmail.com> based on
% Antonius Wiehler scripts <antonius.wiehler@gmail.com>
% October 2017

%% preprocessing steps (select whether you want to keep or remove them)
highSD_exclusion = 0; % remove the signal when it's higher than 3*SD of the signal? (if yes, replaces it by an interpolation)
bandpass_filter = 1; % band pass filter the signal(?)
% define the frequencies for which to filter the signal
% (Note that an alternative way of doing is
if bandpass_filter == 1
    fHighPass   = 1/128;         % high-pass filter in Hz (keeps all frequencies above this value)
    fLowPass    = 1;               % low-pass filter in Hz (keeps all frequencies under this value)
end

%% extract raw signal of eyes
eyeTime      = asc.dat(1,:); % asc.dat(1,:) = time (in s) aligned to the first TTL
X_eyeCoord   = asc.dat(2,:); % asc.dat(2,:) = X coordinate
Y_eyeCoord   = asc.dat(3,:); % asc.dat(3,:) = Y coordinate
pupil_diam   = asc.dat(4,:); % asc.dat(4,:) = pupil size
eyeSignalOk  = asc.dat(5,:); % asc.dat(5,:) = 0 when the eye is lost

%% plot the signal at the different timesteps to see how it evolves
% plot pupil diameter and blinks before any preprocessing to observe the raw signal
if disp_gr == 1
    fontSize = 16;
    figure;
    subplot(3, 2, 1);
    PDcurve = plot(eyeTime, pupil_diam, 'b'); % pupil diameter = f(time)
    hold on;
    scalingFactor = max(pupil_diam)/2;
    blink_episodes = (eyeSignalOk == 0).*scalingFactor; % logical: 1 when blink/signal loss, 0 otherwise
    % blinkCurve = plot(eyeTime_T0, nanEpisodes.blink_episodes.*scalingFactor, 'r'); % blink episodes
    blinkCurve = plot(eyeTime, blink_episodes, 'r'); % blink episodes
    xlim([0, max(eyeTime)+50]);
    legend([PDcurve, blinkCurve], 'pupil diameter','blink episodes');
    legend('boxoff')
    title('Pupil before preprocessing');
    xlabel('Time (s)')
    ylabel('Pupil diameter')
    set(gca, 'FontSize', fontSize);
    
    % plot frequencies to get an idea of the frequencies and magnitude of the
    % signal to be filtered
    subplot(3, 2, 2);
    % dt = 1/samplingRate;          % seconds per sample
    Nsize  = length(pupil_diam); % number of samples
    % Fourier Transform
    D  = fftshift(fft(pupil_diam));
    % Frequency specifications
    dF = samplingRate / Nsize;                      % hertz
    f  = -samplingRate / 2 : dF : samplingRate /2 - dF;   % hertz
    % Plot the spectrum
    plot(f, abs(D) / Nsize);
    xlabel('Frequency (in hertz)');
    ylabel('Magnitude Response');
    title('Pupil diameter before preprocessing');
    set(gca, 'FontSize', fontSize);
    
end

%% preprocess
%% exclude eye outside of screen/signal loss

% extract timings when eye outside screen
eye_outside_screen = (X_eyeCoord >= x_screen) + (X_eyeCoord <= 0) +...
    (Y_eyeCoord >= y_screen) + (Y_eyeCoord <= 0);
% delete these timepoints from the data (gaze position and
% pupil size)
X_eyeCoord(eye_outside_screen ~= 0) = NaN;
Y_eyeCoord(eye_outside_screen ~= 0) = NaN;
pupil_diam(eye_outside_screen ~= 0) = 0;
eyeSignalOk(eye_outside_screen ~= 0) = 0; % signal that this part should also be interpolated

% use also info in eyeSignalOk
pupil_diam(eyeSignalOk == 0) = 0;


%% exclude samples with more than 3*SD for pupil diameter
if highSD_exclusion == 1
    
    % extract pupil SD for the whole signal
    SDpupilDiam = std(pupil_diam,'omitnan'); % Rem: should NaN values be included?
    eye_SD_tooHigh = (pupil_diam >= 3*SDpupilDiam);
    % exclude samples where pupil value higher than 3*SD
    % (potential error from measurement)
    X_eyeCoord(eye_SD_tooHigh) = NaN;
    Y_eyeCoord(eye_SD_tooHigh) = NaN;
    pupil_diam(eye_SD_tooHigh) = 0;
    eyeSignalOk(eye_SD_tooHigh) = 0; % signal that this part should also be interpolated
    
end

%% interpolation for blinks
% problem of how to define blinks... (check how to
% recover eyeLink blink identification
blinkWindow = 0.1; % remove [blinkWindow] milliseconds before start of blink/loss-of-signal and [blinkWindow] milliseconds after end of a blink/loss-of-signal episode
pupil_functions_path = fullfile('C:','Users','nicolas.clairis','Documents','GitHub','proud-pupil');
addpath( pupil_functions_path ); % add path containing interpolation function
pupil_diam_when_blink = 0;
[pupil_diam, nanEpisodes] = interpolate_blinks_nonlinear_v01(pupil_diam', pupil_diam_when_blink, samplingRate, blinkWindow);
rmpath( pupil_functions_path ); % remove path containing interpolation function

% plot after interpolating
if disp_gr == 1
    fontSize = 16;
    subplot(3, 2, 3);
    PDcurve = plot(eyeTime, pupil_diam, 'b'); % pupil diameter = f(time)
    hold on;
    scalingFactor = max(pupil_diam)/2;
    blink_episodes = (eyeSignalOk == 0).*scalingFactor; % logical: 1 when blink/signal loss, 0 otherwise
    % blinkCurve = plot(eyeTime_T0, nanEpisodes.blink_episodes.*scalingFactor, 'r'); % blink episodes
    blinkCurve = plot(eyeTime, blink_episodes, 'r'); % blink episodes
    xlim([0, max(eyeTime)+50]);
    legend([PDcurve, blinkCurve], 'pupil diameter','blink episodes');
    legend('boxoff')
    title('Pupil after interpolation');
    xlabel('Time (s)')
    ylabel('Pupil diameter')
    set(gca, 'FontSize', fontSize);
    
    subplot(3, 2, 4);
    % dt = 1/samplingRate;          % seconds per sample
    Nsize  = length(pupil_diam); % number of samples
    % Fourier Transform
    D  = fftshift(fft(pupil_diam));
    % Frequency specifications
    dF = samplingRate / Nsize;                      % hertz
    f  = -samplingRate / 2 : dF : samplingRate /2 - dF;   % hertz
    % Plot the spectrum
    plot(f, abs(D) / Nsize);
    xlabel('Frequency (in hertz)');
    ylabel('Magnitude Response');
    title('Pupil diameter after interpolation');
    set(gca, 'FontSize', fontSize);
end


%% band-pass filtering of the pupil diameter
% low- and high-pass filtering allows to use the Random Field Theory
% afterwards without need to smooth the data because already smoothed as
% very fast and very slow oscillations are removed
% (based on Antonius Wiehler script)
if bandpass_filter == 1
    
    % mirror signal to avoid border artefacts
    pupil_diam  = [flipud(pupil_diam); pupil_diam; flipud(pupil_diam)];
    
    % set up parameters for filter
    order       = 1;
    [b, a] = butter(order, [fHighPass, fLowPass] / (samplingRate / 2), 'bandpass');
    % filter the pupil diameter
    pupil_diam      = filter(b, a, pupil_diam);  % filtered signal
    
    % unmirror the signal again
    L_pupil_diam     = length(pupil_diam);
    third            = ceil(L_pupil_diam./3); %for odd number of bit-stream length
    pupil_diam      = pupil_diam( (third + 1):(third*2) );
    
    % plot after filtering
    if disp_gr == 1
        fontSize = 16;
        subplot(3, 2, 5);
        PDcurve = plot(eyeTime, pupil_diam, 'b'); % pupil diameter = f(time)
        hold on;
        scalingFactor = max(pupil_diam)/2;
        blink_episodes = (eyeSignalOk == 0).*scalingFactor; % logical: 1 when blink/signal loss, 0 otherwise
        % blinkCurve = plot(eyeTime_T0, nanEpisodes.blink_episodes.*scalingFactor, 'r'); % blink episodes
        blinkCurve = plot(eyeTime, blink_episodes, 'r'); % blink episodes
        xlim([0, max(eyeTime)+50]);
        legend([PDcurve, blinkCurve], 'pupil diameter','blink episodes');
        legend('boxoff')
        title('Pupil after band-pass filter');
        xlabel('Time (s)')
        ylabel('Pupil diameter')
        set(gca, 'FontSize', fontSize);
        
        subplot(3, 2, 6);
        % dt = 1/samplingRate;          % seconds per sample
        Nsize  = length(pupil_diam); % number of samples
        % Fourier Transform
        D  = fftshift(fft(pupil_diam));
        % Frequency specifications
        dF = samplingRate / Nsize;                      % hertz
        f  = -samplingRate / 2 : dF : samplingRate /2 - dF;   % hertz
        % Plot the spectrum
        plot(f, abs(D) / Nsize);
        xlabel('Frequency (in hertz)');
        ylabel('Magnitude Response');
        title('Pupil diameter after band-pass filter');
        set(gca, 'FontSize', fontSize);
    end
end

%% zscore pupil signal (not mandatory))
z_pupil_diam = nanzscore(pupil_diam);

% plot zscore data after filtering
if disp_gr == 1
    figure
    fontSize = 16;
    PDcurve = plot(eyeTime, z_pupil_diam, 'b'); % pupil diameter = f(time)
    hold on;
    scalingFactor = 1;
    blink_episodes = (eyeSignalOk == 0).*scalingFactor; % logical: 1 when blink/signal loss, 0 otherwise
    % blinkCurve = plot(eyeTime_T0, nanEpisodes.blink_episodes.*scalingFactor, 'r'); % blink episodes
    blinkCurve = plot(eyeTime, blink_episodes, 'r'); % blink episodes
    xlim([0, max(eyeTime)+50]);
    legend([PDcurve, blinkCurve], 'pupil diameter','blink episodes');
    legend('boxoff')
    title('Pupil after band-pass filter');
    xlabel('Time (s)')
    ylabel('Pupil diameter')
    set(gca, 'FontSize', fontSize);
end

end

