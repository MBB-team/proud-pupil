function [d, blink_indx] = interpolate_blinks_v01(d , blink, samplingrate, blinkWindow)
% function [d, blink_indx] = interpolate_blinks_v01(d , blink, samplingrate, blinkWindow)
%
% Interpolate blinks in 1D pupil size measures.
%
% d: vector of pupil size measures
% blink: how is a blink defined in the data, usually 0
% samplingrate: samplingrate of the eyetracker
% blinkWindow: how many seconds should be removed before and after a blink?
% blink_indx: Where are blinks?
% The function depends on MergeBrackets.m
%
% Author: Antonius Wiehler <antonius.wiehler@gmail.com>
% Original: 2017-01-11
% Modified: 2018-03-02


sampleLength   = 1 ./ samplingrate;  % how long is one sample in seconds?
blink_samples  = ceil(blinkWindow ./ sampleLength);  % how many samples do we have to remove before and after a blink?

blink_indx     = d == blink;
blink_position = [0; blink_indx; 0];  % where is the pupil diameter a blink?

blink_start    = find(diff(blink_position) == 1);  % where do the blinks start?
blink_stop     = find(diff(blink_position) == -1) -1;  % where do blinks end?

blink_start    = blink_start - blink_samples;  % add window at beginning of blink
blink_stop     = blink_stop + blink_samples;  % add window at end of blink

[blink_start, blink_stop] = MergeBrackets(blink_start, blink_stop);  % Merge overlapping blinks (blinks can be overlapping due to the additional window


for i_b = 1 : length(blink_start)  % loop through blinks
    start_repl  = blink_start(i_b) - 1;  % where to start replacement
    start_repl  = max(start_repl, 1);  % minimum start at first element
    
    stop_repl   = blink_stop(i_b) + 1;  % where to end replacement
    stop_repl   = min(stop_repl, length(d));  % maximum end at last element
    
    n_replace   = stop_repl - start_repl + 1;  % how many samples need to be replaced?
    
    if start_repl == 1  % if we want to replace the first value
        start_value = mean(d(d ~= 0));
    else
        start_value = d(start_repl);  % left anchor
    end
    
    if stop_repl == length(d) % if we want to replace the last value
        stop_value = mean(d(d ~= 0));
    else
        stop_value = d(stop_repl);  % right anchor
    end
    
    substitute = linspace(start_value, stop_value, n_replace)';  % linear interpolation
    
    d(start_repl : stop_repl) = substitute;  % replace in original vector
end  % end for loop blinks


end

