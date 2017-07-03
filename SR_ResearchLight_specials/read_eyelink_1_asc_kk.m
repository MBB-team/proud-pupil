function asc = read_eyelink_1_asc_kk(filename)

% Edits by Kepkee
% Outputs pulse events (buttons), saccades(esacc), pupil measure type and fixations(efix) in datafilestruct.
%
% READ_EYELINK_ASC reads the header information, input triggers, messages
% and all data points from an Eyelink *.asc file
% 
% Use as
%   asc = read_eyelink_asc(filename)
%
% Copyright (C) 2010, Robert Oostenveld
%
% This file is part of FieldTrip, see http://www.ru.nl/neuroimaging/fieldtrip
% for the documentation and details.
%
%    FieldTrip is free software: you can redistribute it and/or modify
%    it under the terms of the GNU General Public License as published by
%    the Free Software Foundation, either version 3 of the License, or
%    (at your option) any later version.
%
%    FieldTrip is distributed in the hope that it will be useful,
%    but WITHOUT ANY WARRANTY; without even the implied warranty of
%    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%    GNU General Public License for more details.
%
%    You should have received a copy of the GNU General Public License
%    along with FieldTrip. If not, see <http://www.gnu.org/licenses/>.
%
% $Id: read_eyelink_asc.m 7123 2012-12-06 21:21:38Z roboos $
%
% See also: read_eyelink_2.m, eye_choice_one_dim, eye_position

fid = fopen(filename, 'rt');

asc.header  = {};
asc.msg     = {};
asc.input   = [];
% asc.sfix    = {};
asc.efix    = {};
asc.pupil    = {};
% asc.ssacc   = {};
asc.esacc   = {};
asc.button   = {};
asc.dat     = [];
current   = 0;

while ~feof(fid)
    tline = fgetl(fid);
    
    if regexp(tline, '^[0-9]');
        tmp   = sscanf(tline, '%f');
        nchan = numel(tmp);
        current = current + 1;
        
        if size(asc.dat,1)<nchan
            % increase the allocated number of channels
            asc.dat(nchan,:) = 0;
        end
        
        if size(asc.dat, 2)<current
            % increase the allocated number of samples
            asc.dat(:,end+10000) = 0;
        end
        
        % add the current sample to the data matrix
        asc.dat(1:nchan, current) = tmp;
        
        
    elseif regexp(tline, '^INPUT')
        [val, num] = sscanf(tline, 'INPUT %d %d');
        this.timestamp = val(1);
        this.value     = val(2);
        if isempty(asc.input)
            asc.input = this;
        else
            asc.input = cat(1, asc.input, this);
        end
        
    elseif regexp(tline, '^BUTTON')
        [val, num] = sscanf(tline, 'BUTTON %d %d %d');
        that.timestamp = val(1);
        that.value     = val(2);
        that.on     = val(3);
        
        if isempty(asc.button)
            asc.button = that;
        else
            asc.button = cat(1, asc.button, that);
        end
        
    elseif regexp(tline, '\*\*.*')
        asc.header = cat(1, asc.header, {tline});
        
        
    elseif regexp(tline, '^MSG')
        asc.msg = cat(1, asc.msg, {tline});
        
    elseif regexp(tline, '^PUPIL')
        asc.pupil = cat(1, asc.pupil, {tline});
        
        
        %     elseif regexp(tline, '^SFIX')
        %         asc.sfix = cat(1, asc.sfix, {tline});
        
%     elseif regexp(tline, '^SFIX')
%         [val, num] = sscanf(tline, 'SFIX %s %d');
%         
%         sfixthis.eye = val(1);
%         sfixthis.timestamp = val(2);
%         
%         if isempty(asc.sfix)
%             asc.sfix = sfixthis;
%         else
%             asc.sfix = cat(1, asc.sfix, sfixthis);
%         end
        
        
%     elseif regexp(tline, '^EFIX')
%         asc.efix = cat(1, asc.efix, {tline});
        
    elseif regexp(tline, '^EFIX')
        [val, num] = sscanf(tline, 'EFIX %s %d %d');
        
        efixthis.eye = val(1);
        efixthis.start = val(2);
        efixthis.end = val(3);
        
        if isempty(asc.efix)
            asc.efix = efixthis;
        else
            asc.efix = cat(1, asc.efix, efixthis);
        end
        
        
%     elseif regexp(tline, '^SSACC')
%         asc.ssacc = cat(1, asc.ssacc, {tline});
%         
%     elseif regexp(tline, '^SSACC')
%         [val, num] = sscanf(tline, 'SSACC %s %d');
%         
%         ssaccthis.eye = val(1);
%         ssaccthis.timestamp = val(2);
%         
%         if isempty(asc.ssacc)
%             asc.ssacc = ssaccthis;
%         else
%             asc.ssacc = cat(1, asc.ssacc, ssaccthis);
%         end
        
%     elseif regexp(tline, '^ESACC')
%         asc.esacc = cat(1, asc.esacc, {tline});

    elseif regexp(tline, '^ESACC')
        [val, num] = sscanf(tline, 'ESACC %s %d %d');
        
        esaccthis.eye = val(1);
        esaccthis.start = val(2);
        esaccthis.end = val(3);
        
        if isempty(asc.esacc)
            asc.esacc = esaccthis;
        else
            asc.esacc = cat(1, asc.esacc, esaccthis);
        end
        
    else
        % all other lines are not parsed
    end
    
end

% close the file?
fclose(fid);

% remove the samples that were not filled with real data
asc.dat = asc.dat(:,1:current);
