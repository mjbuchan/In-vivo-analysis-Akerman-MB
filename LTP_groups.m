% LTP_groups

data_dir = '/Users/matthewbuchan/Desktop/Work/Scripts/Extracted data/Plasticity';

target_groups       = { 'July_Test'};

pre_name            = 'Test_1_pre_1';
post_name           = 'Test_1_post_1';
stim_name           = 'RWS_1';

n_pre_files         = 2;
n_post_files        = 3;

channels            = 1:6;

LFP_res             = 1000; % Resolution of LFP data in Hz

resp_win            = [0.006 0.030]; % Whisk response window;

spont_win           = [-1 -0.1];

burst_thresh        = 2; % how many spikes in burst window to count as a burst
burst_chan_thresh   = 5;
burst_win           = [-0.025 0];

spont_avg_win       = 9; % moving average window for spont activity

n_per_point         = [1];

induction_interval  = 300;

%% 
win_ratio           = spont_win / resp_win;

%%
group_pre_spike_means	= {};
group_post_spike_means	= {};

group_pre_spike_points	= {};
group_post_spike_points	= {};
for a = 1:length(target_groups)
    this_group          = target_groups{a};
    
    group_folder        = fullfile(data_dir,this_group);
    
    pre_folder          = fullfile(group_folder,pre_name);
    post_folder         = fullfile(group_folder,post_name);
    RWS_folder          = fullfile(group_folder,post_name);
    
    %% pre data
    pre_expts           = dir([pre_folder]);
    pre_expts           = {pre_expts.name};
    qkill               = ismember(pre_expts,{'.','..','.DS_Store'});
    pre_expts(qkill)    = [];
    
    %% PRE
    expt_pre_spike_means    = [];
    expt_pre_spike_points   = [];
    for b = 1:length(pre_expts)
        expt_folder     = fullfile(pre_folder,pre_expts{b});
        expt_files      = dir([expt_folder filesep '*.mat']);
        
        pre_spike_means         = [];
        pre_spike_point_means   = [];
        for c = 1:length(expt_files)
            
            %% Load experiment file
            this_expt_file          = fullfile(expt_folder,expt_files(c).name);
            disp(['Loading ' this_expt_file '...']);
            load(this_expt_file);
            
            
            %% Unpack experiment file
            spikes                  = ephys_data.conditions(1).spikes(channels,:,:);
            LFPs                    = ephys_data.conditions(1).LFP_trace(channels,:,:);
            n_trials                = ephys_data.conditions(1).n_trials;
            LFP_timevect            = 1:length(LFPs)/LFP_res;
            
            whisk_onset             = ephys_data.conditions(1).whisk_onset;
            spikes                  = spikes - whisk_onset;
            
            %% Burst control
            q_burst                 = burst_control(spikes,burst_win,burst_thresh,burst_chan_thresh,0);
            burst_perc              = sum(q_burst) / length(q_burst) * 100;
            spikes(:,q_burst,:)     = NaN;
            disp(['Percentage of bursty trials: ' num2str(round(burst_perc))])
            
            %% Response calculation
            
            % spontaneous
            spont_spikes            = spikes > spont_win(1) & spikes <= spont_win(2);
            n_spont_spikes          = sum(spont_spikes,3) / win_ratio; 
            mean_spont_per_trial 	= mean(n_spont_spikes,1); % mean over channels
            moving_avg_spont        = smooth(mean_spont_per_trial,spont_avg_win);
            
            % Whisker-evoked
            resp_spikes             = spikes > resp_win(1) & spikes <= resp_win(2);
            n_spikes                = sum(resp_spikes,3);
            mean_spikes_per_trial   = mean(n_spikes,1); % mean over channels
            corr_spikes_per_trial   = mean_spikes_per_trial(:) - moving_avg_spont(:);
            mean_spikes             = sum(corr_spikes_per_trial) / sum(~q_burst); % Mean while discounting burst trials
            

            %% Average responses over n points
            n_points                = n_trials / n_per_point;
            
            point_mean              = NaN(n_points,1);
            point_serr              = NaN(n_points,1);
            for d = 1:n_points

                resp_inds           = ((d-1) * n_per_point) + [1:n_per_point];
                these_resps         = corr_spikes_per_trial(resp_inds);
                
                point_mean(d)       = nanmedian(these_resps);
                point_serr(d)       = serr(these_resps);
                
            end
            
            %% !!! what gets passed on
            pre_spike_means         = [pre_spike_means; mean_spikes];
            pre_spike_point_means   = [pre_spike_point_means; point_mean(:)];
            
            
        end
        
        expt_pre_spike_means(b)     = mean(pre_spike_means);
        expt_pre_spike_points(1:length(pre_spike_point_means),b)    = pre_spike_point_means; %
    end
    
    %% POST
        %% post data
    post_expts           = dir([post_folder]);
    post_expts           = {post_expts.name};
    qkill               = ismember(post_expts,{'.','..','.DS_Store'});
    post_expts(qkill)    = [];
    
    %% post
    expt_post_spike_means    = [];
    expt_post_spike_points   = [];
    for b = 1:length(post_expts)
        expt_folder     = fullfile(post_folder,post_expts{b});
        expt_files      = dir([expt_folder filesep '*.mat']);
        
        post_spike_means         = [];
        post_spike_point_means   = [];
        for c = 1:length(expt_files)
            
            %% Load experiment file
            this_expt_file          = fullfile(expt_folder,expt_files(c).name);
            disp(['Loading ' this_expt_file '...']);
            load(this_expt_file);
            
            
            %% Unpack experiment file
            spikes                  = ephys_data.conditions(1).spikes(channels,:,:);
            LFPs                    = ephys_data.conditions(1).LFP_trace(channels,:,:);
            n_trials                = ephys_data.conditions(1).n_trials;
            LFP_timevect            = 1:length(LFPs)/LFP_res;
            
            whisk_onset             = ephys_data.conditions(1).whisk_onset;
            spikes                  = spikes - whisk_onset;
            
            %% Burst control
            q_burst                 = burst_control(spikes,burst_win,burst_thresh,burst_chan_thresh,0);
            burst_perc              = sum(q_burst) / length(q_burst) * 100;
            spikes(:,q_burst,:)     = NaN;
            disp(['Percentage of bursty trials: ' num2str(round(burst_perc))])
            
            %% Response calculation
            
            % spontaneous
            spont_spikes            = spikes > spont_win(1) & spikes <= spont_win(2);
            n_spont_spikes          = sum(spont_spikes,3) / win_ratio; 
            mean_spont_per_trial 	= mean(n_spont_spikes,1); % mean over channels
            moving_avg_spont        = smooth(mean_spont_per_trial,spont_avg_win);
            
            % Whisker-evoked
            resp_spikes             = spikes > resp_win(1) & spikes <= resp_win(2);
            n_spikes                = sum(resp_spikes,3);
            mean_spikes_per_trial   = mean(n_spikes,1); % mean over channels
            corr_spikes_per_trial   = mean_spikes_per_trial(:) - moving_avg_spont(:);
            mean_spikes             = sum(corr_spikes_per_trial) / sum(~q_burst); % Mean while discounting burst trials
            

            %% Average responses over n points
            n_points                = floor(n_trials / n_per_point);
            
            point_mean              = NaN(n_points,1);
            point_serr              = NaN(n_points,1);
            for d = 1:n_points

                resp_inds           = ((d-1) * n_per_point) + [1:n_per_point];
                these_resps         = corr_spikes_per_trial(resp_inds);
                
                point_mean(d)       = nanmedian(these_resps);
                point_serr(d)       = serr(these_resps);
                
            end
            
            %% !!! what gets passed on
            post_spike_means       	= [post_spike_means; mean_spikes];
            post_spike_point_means	= [post_spike_point_means; point_mean(:)];
            
            
        end
        
        expt_post_spike_means(b)    = mean(post_spike_means);
        expt_post_spike_points(1:length(post_spike_point_means),b)  = post_spike_point_means; %
    end
    
    group_pre_spike_means{a}    = expt_pre_spike_means;
    group_post_spike_means{a}   = expt_post_spike_means;
    
    group_pre_spike_points{a}   = expt_pre_spike_points;
    group_post_spike_points{a}  = expt_post_spike_points;
    
end


%% Plotting begins here
point_delta_t   = ephys_data.trial_interval * n_per_point;
for a = 1:length(target_groups)
    figure
    set(gcf,'Units','Normalized','Position',[.1 .3 .8 .3],'PaperPositionMode','auto');
    pre_spike_means     = group_pre_spike_means{a};
    
    %% PRE
    pre_point_resps     = group_pre_spike_points{a};
    
    pre_spike_mean_mat  = repmat(pre_spike_means,size(pre_point_resps,1),1);
    pre_point_resps     = pre_point_resps ./ pre_spike_mean_mat; % divide all responses by pre mean
    
    pre_point_means     = mean(pre_point_resps,2);
%     pre_point_serrs     = serr(pre_point_resps,2);
    
    pre_time_vect       = [1:length(pre_point_means)] * point_delta_t;
    
    % plot
    plot(pre_time_vect,pre_point_resps,'.','MarkerSize',20);
    hold on
%     errorbar(pre_time_vect,pre_point_means, pre_point_serrs,'k.','LineWidth',2,'MarkerSize',20);
    
    %% POST
    post_point_resps    = group_post_spike_points{a};
    pre_spike_mean_mat  = repmat(pre_spike_means,size(post_point_resps,1),1);
    post_point_resps  	= post_point_resps ./ pre_spike_mean_mat;  % divide by pre mean
    
    post_point_means    = mean(post_point_resps,2);
%     post_point_serrs    = serr(post_point_resps,2);
    
    post_time_vect   	= max(pre_time_vect) + induction_interval + [1:length(post_point_means)] * point_delta_t;
    
    % plot
    plot(post_time_vect,post_point_resps,'.','MarkerSize',20);
    hold on
%     errorbar(post_time_vect,post_point_means, post_point_serrs,'k.','LineWidth',2,'MarkerSize',20);
    
    fixplot
    yzero
    
    title(target_groups{a})
    
end


average_pre = median(pre_point_resps(1:60,:),1); 
average_post = median(post_point_resps(1:119,:),1); 

deltas = average_post./average_pre;