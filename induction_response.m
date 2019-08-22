
% '/Volumes/Akermanlab/Joram/Preprocessed data/Induction/RWS_1/2019_03_27/2019_03_27-3-RWS_1.mat'
% '/Volumes/Akermanlab/Joram/Preprocessed data/Induction/RWS_1/2019_03_28/2019_03_28-3-RWS_1.mat'
% '/Volumes/Akermanlab/Joram/Preprocessed data/Induction/RWS_1/2019_04_09/2019_04_09-4-RWS_1.mat'


% Enter files in the following format:
RWS_100Hz_files = {'/Volumes/Akermanlab/Joram/Preprocessed data/RWS_100Hz/2019_01_08/2019_01_08-2-RWS_1.mat'};

RWS_8Hz_files = {'/Users/matthewbuchan/Desktop/Work/Scripts/Extracted data/RWS_1/2019_04_04/2019_04_04-5-RWS_1.mat'};


psth_offset_8Hz     = 0.0625; % Offset of 8Hz stimulus within trial
psth_offset_100Hz   = 1.5; % Offset of 100Hz stimulus within trial
resp_win            = [0.005 0.030]; % Window for assessing responses
spacing             = 0.125; % spacing between trials in 8Hz protocol; used for generating fake trials within 1s window of 100Hz stim
n_trials            = 8; % number of fake trial windows in the 1s window of 100Hz stim

trial_number_100Hz  = 1:20; % which trials of the induction to incorporate

trials              = 1:8; % number of trials for the 8Hz
x_lims              = [0 10]; % x axis limits
y_lims              = [0 1.2];

channels            = 1:32; % which channels to incorporate

%%
close all


trial_spike_count_8Hz = [];
for a = 1:length(RWS_8Hz_files)
    % Load file
    this_RWS_file           = RWS_8Hz_files{a};
    load(this_RWS_file)
    
    % Get spikes and subtract stimulus offset so all spikes are relative to stimulus
    spikes                  = ephys_data.conditions.spikes(channels,trials,:);
    spikes                  = spikes - psth_offset_8Hz;
    
    % select spikes that fall within response window
    is_resp_spike           = spikes > resp_win(1) & spikes < resp_win(2);
    
    % Count all spikes, resulting in a count per channel, per trial
    n_resp_spikes           = squeeze(sum(is_resp_spike,3));
    
    % Take mean over channels, resulting in a mean per trial
    mean_n_resp_spikes      = mean(n_resp_spikes, 1); 

    % Normalise by the response to the first stimulus and add to an array that stores these data for all files we are looking at
    trial_spike_count_8Hz   = [trial_spike_count_8Hz; mean_n_resp_spikes / mean_n_resp_spikes(1)];
end

% Plot the normalised response data per stimulus, with an error bar across RWS files
figure
errorbar(median(trial_spike_count_8Hz(:,trials),1),serr(trial_spike_count_8Hz(:,trials),1),'LineWidth',2,'Color',[0 0 0])
xlim(x_lims)
ylim(y_lims)
fixplot
xlabel('Trial number')
ylabel('Normalised spiking response')
title('8Hz RWS tracking')


trial_spike_count_100Hz = [];
for a = 1:length(RWS_100Hz_files)
    % Load file
    this_RWS_file           = RWS_100Hz_files{a};
    load(this_RWS_file)
    
    % Get spikes and subtract stimulus offset so all spikes are relative to stimulus
    spikes                  = ephys_data.conditions.spikes(channels,trial_number_100Hz,:);
    spikes                  = spikes - psth_offset_100Hz;
    
    % Break up the 100Hz window into a number of fake 'trials' and collect similar resp windows as for 8 Hz stimulation
    trial_resp_spikes       = [];
    for b = 1:n_trials
        this_resp_win           = resp_win + (b-1) * spacing;
        is_resp_spike           = (spikes > this_resp_win(1) & spikes < this_resp_win(2));
        n_resp_spikes           = squeeze(sum(is_resp_spike,3));
        trial_resp_spikes(b)    = mean(mean(n_resp_spikes, 1));
    end
    
    % Normalise by the response in the first trial window
    trial_resp_spikes           = trial_resp_spikes / trial_resp_spikes(1);
    
    % Add data to array that accumulates data from all target files
    trial_spike_count_100Hz     = [trial_spike_count_100Hz; trial_resp_spikes];
    
end

% Plot the normalised response data per stimulus, with an error bar across RWS files
figure
errorbar(median(trial_spike_count_100Hz(:,1:8),1),serr(trial_spike_count_100Hz(:,1:8)),'LineWidth',2,'Color',[0 0 0])
xlim(x_lims)
ylim(y_lims)
fixplot
xlabel('Trial number')
ylabel('Spike count')
title('100Hz RWS tracking')


