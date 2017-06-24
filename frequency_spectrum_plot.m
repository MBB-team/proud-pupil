function [] = frequency_spectrum_plot(d, Fs)
    % function [] = frequency_spectrum_plot(d, Fs)
    %   Plot the frequency spectrum of the 1D time series d.
    %   Fs: Sampling rate in Hz.
    %
    % Author: Antonius Wiehler <antonius.wiehler@gmail.com>
    % Original: 2017-01-12
    
    % Time specifications
    dt = 1/Fs;                        % seconds per sample
    N  = size(d, 1);                  % number of samples
    
    % Fourier Transform
    D  = fftshift(fft(d));
    
    % Frequency specifications
    dF = Fs / N;                      % hertz
    f  = -Fs / 2 : dF : Fs /2 - dF;   % hertz
    
    % Plot the spectrum
    plot(f, abs(D) / N);
    xlabel('Frequency (in hertz)');
    title('Magnitude Response');
    
end

