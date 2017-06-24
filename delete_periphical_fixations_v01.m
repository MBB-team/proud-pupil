function [d] = delete_periphical_fixations_v01(d, x, y, ScreenX, ScreenY, border_size, blink)
% function [d] = delete_periphical_fixations_v01(d, x, y, ScreenX, ScreenY, border_size, blink)
%
% Delete pupil recording when fixation is at the perepheric of the screen.
%
% d: vector of pupil size measures
% x: vector of gaze position on x axis
% y: vector of gaze position on y axis
% ScreenX: x size of screen in pixel
% ScreenY: y size of screen in pixel
% border_size: How many percent of the screen should be considered as
% periphical? How wide should the border be?
% blink: How is a blink defined? Pupil will be replaced by this.
% samplingrate: samplingrate of the eyetracker
%
% Author: Antonius Wiehler <antonius.wiehler@gmail.com>
% Original: 2017-06-24
% Modified: 2017-06-24

% compute borders
BorderX      = round(ScreenX .* border_size);  % Screen border for rejection
BorderY      = round(ScreenY .* border_size);  % Screen border for rejection

% reject on x axis
border_rows1 = x < BorderX;
border_rows2 = x > ScreenX - BorderX;

% reject on y axis
border_rows3 = y < BorderY;
border_rows4 = y > ScreenY - BorderY;

% replace with blink marker
d(border_rows1 | border_rows2 | border_rows3 | border_rows4) = blink;

end

