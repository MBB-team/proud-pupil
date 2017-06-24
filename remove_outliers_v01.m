function [d] = remove_outliers_v01(d , cutoff, blink)
% function [d] = remove_outliers_v01(d, cutoff, blink)
%
% Remove outliers in 1D pupil size measures.
%
% d: vector of pupil size measures
% cutoff: outside how many standard deviation is it an outlier?
% blink: how is a blink defined in the data? usually 0. We will replace
% outliers by this.
%
% Author: Antonius Wiehler <antonius.wiehler@gmail.com>
% Original: 2017-06-24
% Modified: 2017-06-24


blink_rows = d == blink;  % don't consider rows we marked as blinks before

cutoff_low  = nanmean(d(~blink_rows)) - cutoff * nanstd(d(~blink_rows));
cutoff_high = nanmean(d(~blink_rows)) + cutoff * nanstd(d(~blink_rows));

d(d < cutoff_low)  = blink;  % mark as blink
d(d > cutoff_high) = blink; % mark as blink

end

