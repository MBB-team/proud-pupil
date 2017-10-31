function [d, nanEpisodes] = interpolate_blinks_v03(d , blink, samplingrate, blinkWindow)
% function [d] = interpolate_blinks_v01(d , blink, samplingrate, blinkWindow)
%
% Interpolate blinks in 1D pupil size measures.
%
% INPUTS
% d: vector of pupil size measures
% blink: how is a blink defined in the data, usually 0
% samplingrate: samplingrate of the eyetracker
% blinkWindow: how many seconds should be removed before and after a blink?
%
% OUPUT
% d: vector of pupil size measures (after interpolation)
% nanEpisodes: structure containing info about blink/loss-of-eye episodes
% nanEpisodes.blink_episodes : binary vector of when the signal was lost (because of a
% blink or just a loss) to keep track of these episodes and eventually
% exclude them from further analysis if one of these episodes was too long
% nanEpisodes.blink_start: index for blink start
% nanEpisodes.blink_stop: index for blink stop
%
%
% The function depends on MergeBrackets.m
%
% Author: Antonius Wiehler <antonius.wiehler@gmail.com>
% Modifications by Nicolas Clairis <nicolas.clairis@protonmail.com> in
% 30/10/2017
% Original: 2017-01-11
% Modified: 2017-06-22


sampleLength   = 1 ./ samplingrate;  % how long is one sample in seconds?
blink_samples  = ceil(blinkWindow ./ sampleLength);  % how many samples do we have to remove before and after a blink?

  % where is the pupil diameter a
% blink? adding one zero at first and one at last so that the diff (for
% blink_start and blink_stop) may work properly
if size(d,2) == 1
    blink_position = [0; d == blink; 0];
elseif size(d,1) == 1
    blink_position = [0, d == blink, 0];
end

blink_start    = find(diff(blink_position) == 1);  % where do the blinks start?
blink_stop     = find(diff(blink_position) == -1) -1;  % where do blinks end?

blink_start    = blink_start - blink_samples;  % add window at beginning of blink
blink_stop     = blink_stop + blink_samples;  % add window at end of blink

[blink_start, blink_stop] = MergeBrackets(blink_start, blink_stop);  % Merge overlapping blinks (blinks can be overlapping due to the additional window

% store blink info inside nanEpisodes structure
nanEpisodes.blink_episodes  = blink_position;
nanEpisodes.blink_start     = blink_start;
nanEpisodes.blink_stop      = blink_stop;


for i_b = 1 : length(blink_start)  % loop through blinks
    start_repl  = blink_start(i_b) - 1;  % where to start replacement
    start_repl  = max(start_repl, 1);  % minimum start at first element
    
    stop_repl   = blink_stop(i_b) + 1;  % where to end replacement
    stop_repl   = min(stop_repl, length(d));  % maximum end at last element
    
    n_replace   = stop_repl - start_repl + 1;  % how many samples need to be replaced?
    
    % if first values = loss of signal/blink, use the average of all the
    % signal for the interpolation
    if start_repl == 1  % if we want to replace the first value
        start_value = mean(d(d ~= 0));
    else
        start_value = d(start_repl);  % left anchor
    end
    
    % if last values = loss of signal/blink, use the average of all the
    % signal for the interpolation
    if stop_repl == length(d) % if we want to replace the last value
        stop_value = mean(d(d ~= 0));
    else
        stop_value = d(stop_repl);  % right anchor
    end
    
    substitute = linspace(start_value, stop_value, n_replace)';  % linear interpolation
    
    d(start_repl : stop_repl) = substitute;  % replace in original vector
end  % end for loop blinks


end

