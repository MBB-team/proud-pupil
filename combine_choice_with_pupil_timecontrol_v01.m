function combine_choice_with_pupil_timecontrol_v01(cfg)
% function combine_choice_with_pupil_timecontrol_v01(cfg)
%
%   Combine choice data of all subjects with trial wise pupil into one table.
%
%   Author: Antonius Wiehler <antonius.wiehler@gmail.com>
%   Original: 2018-03-07
%   Modified: 2018-03-07

max_length_choice = cfg.eye.samplingrate * 5;  % maximum length of choice trials

savewhere = strcat(cfg.dir.group, cfg.studyname, '_group_choice_pupil_data.mat');  % whre to save the final table?

if ~exist(savewhere, 'file')  % only run when output does not exist
    
    % load choice data
    loadwhere = strcat(cfg.dir.analyze_choice, cfg.studyname, '_group_choice_rating_data.mat');  % whre to save the final table?
    load(loadwhere, 'choice_data_rating');
    
    choice_data_pupil = choice_data_rating;  % copy table
    choice_data_pupil.pupil = cell(size(choice_data_pupil, 1), 1);  % create empty collum for pupil data
    
    
    % for loop subjects
    % ---------------------------------------------------------------------
    
    subjects = unique(choice_data_pupil.subject_id);
    for i_s = 1 : length(subjects)
        
        idx_sub = strcmp(choice_data_pupil.subject_id, subjects{i_s});
        
        fprintf('Working on combining pupil with choice for subject %s...\n', subjects{i_s});
        
        % load sub pupil data here
        loadwhere_pupil = sprintf('%seye_pupil_preprocessed_%s.mat', cfg.dir.pupil_preprocessed, subjects{i_s});  % construct file name
        fnames = dir(loadwhere_pupil);
        
        if ~isempty(fnames)  % if we have a preprocessed file
            load(fullfile(cfg.dir.pupil_preprocessed, fnames.name), 'eyeTrackdata');
            
            
            
            % for loop conditions
            % ---------------------------------------------------------------------
            conditions = unique(choice_data_rating.condition);  % hard coded to match marks in eyetribe
            
            
            for i_c = 1 : length(conditions)
                
                idx_condition = strcmp(choice_data_pupil.condition, conditions{i_c});
                
                % for loop blocks
                % ---------------------------------------------------------------------
                
                blocks = unique(choice_data_pupil.block(idx_sub & idx_condition));
                
                for i_b = 1 : length(blocks)
                    
                    idx_block = choice_data_pupil.block == blocks(i_b);
                    
                    %  FIND PUPIL DATA FOR THIS BLOCK
                    
                    scene = 10000000 * 5 + 1000000 * i_c + 10000 * 1 + 100 * blocks(i_b) + 10 * 0 + 1 * 0;
                    
                    idx_block_pupil = (eyeTrackdata.scene >= scene) &  (eyeTrackdata.scene <= scene+42);
                    
                    eyeTrackdata_block = eyeTrackdata(idx_block_pupil, :);
                    
                    
                    if ~isempty(eyeTrackdata_block)
                        
                        
                        % for loop trials
                        % ---------------------------------------------------------------------
                        
                        within_block = unique(choice_data_pupil.within_block(idx_sub & idx_condition & idx_block));
                        
                        for i_t = 1 : length(within_block)
                            
                            idx_trial = choice_data_pupil.within_block == within_block(i_t);
                            
                            test = choice_data_pupil(idx_sub & idx_condition & idx_block & idx_trial, :);
                            
                            trial_mark_01 = eyeTrackdata.mark == 1000000 * 5 + 100 * test.trial_number + 1 * 2;
                            trial_mark_02 = eyeTrackdata.mark == 1000000 * 5 + 100 * test.trial_number + 1 * 3;
                            trial_mark_03 = eyeTrackdata.mark == 1000000 * 5 + 100 * test.trial_number + 1 * 4;
                            trial_mark_04 = eyeTrackdata.mark == 1000000 * 5 + 100 * test.trial_number + 1 * 5;
                            
                            [i1, i2] = find(strcmp(cfg.choice.task_list, test.task));  % find task and subtask
                            trial_mark_05 = eyeTrackdata.scene == 10000000 * 5 + 1000000 * i_c + 10000 * 1 + 100 * i_b + 10 * i1 + 1 * i2;
                            
                            
                            idx_trial_pupil = (trial_mark_01 | trial_mark_02 | trial_mark_03 | trial_mark_04) & trial_mark_05;
                            
                            if any(idx_trial_pupil) % if we have pupil data for this trial
                                
                                idx_trial_pupil = find(idx_block_pupil & idx_trial_pupil);
                                
                                wired_idx = [0;diff(idx_trial_pupil)>10];  % indx that are by accident from other trials
                                
                                if any(wired_idx)
                                    idx_trial_pupil = idx_trial_pupil(~wired_idx);
                                    warning('Wired pupil markers removed for subject %s, condition %s, block %i.', subjects{i_s}, conditions{i_c}, blocks(i_b));
                                end
                                
                                % add baseline before
                                pupil_trial = eyeTrackdata.PsizeZ(idx_trial_pupil(1)-cfg.eye.pre_stim : idx_trial_pupil(end));
                                
                                % substract baseline
                                pupil_trial = pupil_trial - mean(pupil_trial(1 : cfg.eye.pre_stim));  % substract mean pre stimulus baseline
                                
                                % store in table
                                choice_data_pupil.pupil{idx_sub & idx_condition & idx_block & idx_trial} = pupil_trial';
                                
                            end  % if we have pupil data for this trial
                            
                        end  % trials
                        
                        
                    else  % if we dont have usable data
                        warning('No usable eyetracking data for subject %s, condition %s, block %i.', subjects{i_s}, conditions{i_c}, blocks(i_b));
                    end  % if we have data for this block
                    
                end  % blocks
            end  % conditions
        end  % if we have a file for this sub
    end  % loop subjects
    
    
    
    % compute maxlength
    % ---------------------------------------------------------------------
    
    pupil_length = cellfun(@(x) size(x, 2), choice_data_pupil.pupil);
    max_length   = max(pupil_length);
    max_length   = min(max_length, max_length_choice);
    
    
    % bring all cells to same length
    % ---------------------------------------------------------------------
    fprintf('Bringing all trials to the same length (%i samples)...\n', max_length);

    za = nan(1, max_length);
    for idx = 1 : length(choice_data_pupil.pupil)
        cellVal = choice_data_pupil.pupil{idx};
        if length(cellVal) < max_length
            choice_data_pupil.pupil{idx} = za;
            choice_data_pupil.pupil{idx}(1 : length(cellVal)) = cellVal;
        elseif length(cellVal) > max_length
            choice_data_pupil.pupil{idx} = za;
            choice_data_pupil.pupil{idx} = cellVal(1 : max_length);
        end
    end
    
    
    % save
    % ---------------------------------------------------------------------
    save(savewhere, 'choice_data_pupil', '-v7.3');
    
    fprintf('done.\n');
    
end  % if not exists


end

