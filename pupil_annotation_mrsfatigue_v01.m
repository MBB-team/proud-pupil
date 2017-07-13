function [] = pupil_annotation_mrsfatigue_v01(cfg, subject, condition, session)
% function [] = pupil_annotation_mrsfatigue_v01(cfg, subject, condition, session)
%   Anootation of pupil recordings with task variables.
%   cfg: configuration structure
%   subject: current subject, ID_INITIALS, e.g. 111_aw
%   condition: condition to be processed.
%
% type:
% 1. init
% 2. Instructions
% 3. rating
% 4. n-switch
% 5. choice
% 6. break
% 7. pupil response task
% 8. n-back
%
% mark:
% 1. init
% 2. show stimulus
% 3. response
% 4. show feedback
% 5. show jitter
%
% add collumns for (choice) trials:
% - task
% - trial number
% - trial types (low-mid-high DV)
% - good delay?
% - delay
% - amount
% - choiceSS
%
%   Author: Antonius Wiehler <antonius.wiehler@gmail.com>
%   Original: 2017-03-13
%   Modified: 2017-06-27



%% LOAD DATA
% =========================================================================

% load data
searchstring = sprintf('%seyelink_%s_pupil_preprocessed_%s_session_%02i.mat', cfg.dir.pupil_preprocessed, condition, subject, session);  % construct file name

files = dir(searchstring);  % list files in directory

if ~isempty(files)
    fname = files(end).name;  % file name of eye recordings
    
    pupil = load(fullfile(cfg.dir.pupil_preprocessed, fname));  % load file and struct
    
    EYEDATA = pupil.EYEDATA;
    clear pupil;
    
    
    % 1. init
    % 2. Instructions
    % 3. rating
    % 4. n-switch
    % 5. choice
    % 6. break
    % 7. pupil response task
    % 8. n-back
    
    EYEDATA(EYEDATA.INPUT == 0, 'task') = cellstr(repmat('no_task', sum(EYEDATA.INPUT == 0), 1));
    
    EYEDATA(EYEDATA.INPUT == 42, 'task') = cellstr(repmat('nswitch', sum(EYEDATA.INPUT == 42), 1));
    EYEDATA(EYEDATA.INPUT == 43, 'task') = cellstr(repmat('nswitch', sum(EYEDATA.INPUT == 43), 1));
    EYEDATA(EYEDATA.INPUT == 45, 'task') = cellstr(repmat('nswitch', sum(EYEDATA.INPUT == 45), 1));
    
    EYEDATA(EYEDATA.INPUT == 82, 'task') = cellstr(repmat('nback', sum(EYEDATA.INPUT == 82), 1));
    EYEDATA(EYEDATA.INPUT == 83, 'task') = cellstr(repmat('nback', sum(EYEDATA.INPUT == 83), 1));
    EYEDATA(EYEDATA.INPUT == 85, 'task') = cellstr(repmat('nback', sum(EYEDATA.INPUT == 85), 1));
    
    
    
    %% fill annotation collumns trialwise
    % =========================================================================
    
    EYEDATA.trial_type = nan(size(EYEDATA, 1), 1);
    EYEDATA.good_delay = nan(size(EYEDATA, 1), 1);
    EYEDATA.rewardSS   = nan(size(EYEDATA, 1), 1);
    EYEDATA.costSS     = nan(size(EYEDATA, 1), 1);
    EYEDATA.rewardLL   = nan(size(EYEDATA, 1), 1);
    EYEDATA.costLL     = nan(size(EYEDATA, 1), 1);
    EYEDATA.choiceSS   = nan(size(EYEDATA, 1), 1);
    
    
    EYEDATA.switches     = nan(size(EYEDATA, 1), 1);
    EYEDATA.performance  = nan(size(EYEDATA, 1), 1);
    EYEDATA.trial_number = nan(size(EYEDATA, 1), 1);
    
    
    % load group nswitch data
    group_nswitch = load(sprintf('%s%s_%s_group_data.mat', cfg.dir.analyze_ntask, 'nswitch', condition));
    
    % select only the current subject
    nswitch_data = group_nswitch.nswitch_data(strcmp(group_nswitch.nswitch_data.subject_id, subject), :);
    
    % select only current session
    nswitch_data = nswitch_data(nswitch_data.session == session, :);
    
    
    choice_data = [];
    
    for i_t = 1 : size(cfg.choice.task_list, 1)  % loop task domain
        
        task_name  = cfg.choice.task_list{i_t};  % which task do we want to do
        
        % load group choice data
        group_choice = load(sprintf('%s%s_%s_group_choice_data.mat', cfg.dir.analyze_choice, task_name, condition));
        
        % select only current session
        group_choice.choice_data = group_choice.choice_data(group_choice.choice_data.session == session, :);
        
        % select only the current subject
        choice_data_task = group_choice.choice_data(strcmp(group_choice.choice_data.subject_id, subject), :);
        
        choice_data = [choice_data; choice_data_task];
        
    end  % for loop choice tasks
    
    
    
    blocks = unique(EYEDATA.BLOCK);  % for which blocks do we have pupil recordings?
    
    
    for i_b = 1 : length(blocks) - 1  % minus 1 because the last block is always interrupted
        
        
        % select all data points of this task and this trial period
        indx = EYEDATA.BLOCK == blocks(i_b);
        
        
        
        
        %% fill annotation collumns trialwise NSWITCH
        % =========================================================================
        
        if any(EYEDATA(indx, :).INPUT == 45)  % if we have any choice trial on this block
            
            matching_samples1 = EYEDATA.INPUT == 42;  % find all matching eye samples
            matching_samples4 = EYEDATA.INPUT == 45;  % find all matching eye samples
            
            matching_samples1 = find(matching_samples1 & indx);  % index vector
            matching_samples4 = find(matching_samples4 & indx);  % index vector
            
            changes1 = find(diff(matching_samples1) > 10);  % find changes in index vector
            changes4 = find(diff(matching_samples4) > 10);  % find changes in index vector
            
            indx_begin_of_section = [matching_samples1(1); matching_samples1(changes1 + 1)];  % find the begin of a matching block, index in EYEDATA space
            
            % if there is a problem with responses that are too fast and we have
            % not recorded a sample with 52
            if size(indx_begin_of_section, 1) < 24
                
                % test if we find something with a start of 43
                matching_samples2 = EYEDATA.INPUT(1:end-1)==0 & EYEDATA.INPUT(2:end) == 43;
                matching_samples2 = find([0; matching_samples2] & indx);  % index vector
                indx_begin_of_section = sort([indx_begin_of_section; matching_samples2]);
            end
            
            indx_end_of_section = [matching_samples4(changes4); matching_samples4(end)];  % find the end of a matching block, index in EYEDATA space
            
            if (size(indx_begin_of_section, 1) ~= size(indx_end_of_section, 1)) | size(indx_begin_of_section, 1) ~= 24
                error('n-switch task markers do not match for %s, %s, session %03i, block %03i.', subject, condition, session, i_b);
            end
            
            nswitch_tmp = nswitch_data(nswitch_data.block == blocks(i_b), :);  % only choice data of this block
            
            
            % loop trials
            for i_tr = 1 : size(indx_begin_of_section, 1)
                
                
                eye_index = indx_begin_of_section(i_tr) : indx_end_of_section(i_tr);
                
                % copy variables
                EYEDATA(eye_index, 'switches')= {nswitch_data.switches(i_tr)};
                EYEDATA(eye_index, 'performance')= {nswitch_data.performance(i_tr)};
                EYEDATA(eye_index, 'trial_number')    = {i_tr};
                
                
            end % trials
            
        end % inf there is nswitch in this block
        
        
        %% fill annotation collumns trialwise CHOICE
        % =========================================================================
        
        
        if any(EYEDATA(indx, :).INPUT == 55)  % if we have any choice trial on this block
            
            matching_samples1 = EYEDATA.INPUT == 52;  % find all matching eye samples
            matching_samples4 = EYEDATA.INPUT == 55;  % find all matching eye samples
            
            matching_samples1 = find(matching_samples1 & indx);  % index vector
            matching_samples4 = find(matching_samples4 & indx);  % index vector
            
            changes1 = find(diff(matching_samples1) > 10);  % find changes in index vector
            changes4 = find(diff(matching_samples4) > 10);  % find changes in index vector
            
            indx_begin_of_section = [matching_samples1(1); matching_samples1(changes1 + 1)];  % find the begin of a matching block, index in EYEDATA space
            
            % if there is a problem with responses that are too fast and we have
            % not recorded a sample with 52
            if size(indx_begin_of_section, 1) < 4
                % test if we find something with a start of 53
                matching_samples2 = EYEDATA.INPUT(1:end-1)==0 & EYEDATA.INPUT(2:end) == 53;
                matching_samples2 = find([0; matching_samples2] & indx);  % index vector
                indx_begin_of_section = sort([indx_begin_of_section; matching_samples2]);
            end
            
            indx_end_of_section   = [matching_samples4(changes4); matching_samples4(end)];  % find the end of a matching block, index in EYEDATA space
            
            if (size(indx_begin_of_section, 1) ~= size(indx_end_of_section, 1))
                error('Choice task markers do not match for %s, %s, session %03i, block %03i.', subject, condition, session, i_b);
            end
            if (size(indx_begin_of_section, 1) == size(indx_end_of_section, 1)) | size(indx_begin_of_section, 1) > 4
                indx_begin_of_section = indx_begin_of_section(1 : 4);
                indx_end_of_section = indx_end_of_section(1 : 4);
            end
            
            choice_tmp = choice_data(choice_data.block == blocks(i_b), :);  % only choice data of this block
            
            % loop trials
            for i_tr = 1 : size(indx_begin_of_section, 1)
                
                choice_index = choice_tmp.withinblock == i_tr;       % index of choice trial to match presentation order
                
                eye_index = indx_begin_of_section(i_tr) : indx_end_of_section(i_tr);
                
                if all(choice_index == 0)  % for missing trials etc. When we dont have choice data for this pupil recording
                    
                    % set variables to {nan}
                    EYEDATA(eye_index, 'two_dimensions')= {nan};
                    EYEDATA(eye_index, 'trial_type')    = {nan};
                    EYEDATA(eye_index, 'empirical_DV')  = {nan};
                    EYEDATA(eye_index, 'good_delay')    = {nan};
                    EYEDATA(eye_index, 'rewardSS')      = {nan};
                    EYEDATA(eye_index, 'costSS')        = {nan};
                    EYEDATA(eye_index, 'rewardLL')      = {nan};
                    EYEDATA(eye_index, 'costLL')        = {nan};
                    EYEDATA(eye_index, 'choiceSS')      = {nan};
                    EYEDATA(eye_index, 'response_time') = {nan};
                    
                else
                    
                    % copy variables
                    EYEDATA(eye_index, 'task')= {choice_tmp.task(choice_index)};
                    EYEDATA(eye_index, 'two_dimensions')= {choice_tmp.two_dimensions(choice_index)};
                    EYEDATA(eye_index, 'trial_type')    = {choice_tmp.trial_type(choice_index)};
                    EYEDATA(eye_index, 'empirical_DV')  = {choice_tmp.empirical_DV(choice_index)};
                    EYEDATA(eye_index, 'good_delay')    = {choice_tmp.good_delay(choice_index)};
                    EYEDATA(eye_index, 'rewardSS')      = {choice_tmp.rewardSS(choice_index)};
                    EYEDATA(eye_index, 'costSS')        = {choice_tmp.costSS(choice_index)};
                    EYEDATA(eye_index, 'rewardLL')      = {choice_tmp.rewardLL(choice_index)};
                    EYEDATA(eye_index, 'costLL')        = {choice_tmp.costLL(choice_index)};
                    EYEDATA(eye_index, 'choiceSS')      = {choice_tmp.choiceSS(choice_index)};
                    EYEDATA(eye_index, 'response_time') = {choice_tmp.response_time(choice_index)};
                    
                end % choice index not zero
                
            end % trials
            
        end % if choice trials on this block
        
    end  % blocks
    
    
    
    %% SAVE DATA
    % =========================================================================
    
    savewhere = sprintf('%seyelink_%s_pupil_preprocessed_annotated_%s_session_%02i', cfg.dir.pupil_annotated, condition, subject, session);  % construct file name
    
    save([savewhere '.mat'], 'EYEDATA');  % save annotated pupil
    
else
   warning('%seyelink_%s_pupil_preprocessed_%s_session_%02i.mat is empty.', cfg.dir.pupil_preprocessed, condition, subject, session);  % construct file name
end  % if pupil preprocessed is not empty

end