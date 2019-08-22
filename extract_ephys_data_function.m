function [ephys_data] = extract_ephys_data_function(datafolder,datafilenr,qspike_detection,parameters)

data_prefix             = parameters.data_prefix;           % = '100';
q_digital_events        = parameters.digital_events;        % 1/0% events determined using openephys event detection
q_channelmap            = parameters.channelmap;            % 1/0 have channels been mapped in openephys (1) or do we need to remap ourselves (0)?
spike_smoothwin         = parameters.spike_smoothwin;       % smoothing window for spike detection
spike_thresh            = parameters.spike_thresh;          % spike threshold in SDs
LED_conditions_res      = parameters.LED_conditions_res;    % resolution in ms for automatically extracting conditions from LED delays
whisk_conditions_res    = parameters.whisk_conditions_res;  % resolution in ms for automatically extracting conditions from whisker delays
spontwin                = parameters.spontwin;              % window for spont spikes e.g. [0 200] ms

trial_input_nr          = parameters.trial_channel;         % Which input channel has the trial TTL
stim_input_nr           = parameters.whisk_channel;         % Which input channel has the stim / whisk TTL
opto_input_nr        	= parameters.LED_channel;           % Which input channel has the LED TTL
switch_input_nr         = parameters.stim_switch_channel;  	% Which input channel switches between stimulators?
q_override              = parameters.override_conds;        % Override TTL-based condition structure?
n_conds                 = parameters.n_conds;               % Number of conditions if using override

qmorse                  = parameters.morse;                 % use trial start/end morse code?

expt_type               = parameters.experiment_type;       % what type of experiment is this?

get_channels            = parameters.get_channels;        	% which channels to get in which order?

get_LFP                 = parameters.get_LFP;               % get LFP data?

data_output             = parameters.data_output;           % data output type; new 'ephys_data' or 'channels'-type - 

trials_from_whisk       = parameters.trials_from_whisk;     % discard trial information from ADC channels and determine trials based on whisker instead?
whisk_buffer            = parameters.whisk_buffer;          % if using whisk stim to divide recording into trials (above), trials start whisk_buffer (in seconds) before the whisker stim onset, and end 2*whisk buffer after whisker stim ONSET

% Is this still needed?
morse_start             = [3 1 3 1 3]; % morse code for start of trial; short = 1, long = 3;
morse_stop              = [1 1 1 3 1 3]; % morse code for end of trial; short = 1, long = 3;

%% some file I/O pre-work

n_channels              = length(get_channels);

data_contents           = dir(datafolder); % find what is in the data folder
filefolders             = data_contents([data_contents.isdir]); % get only directories
filefolders             = {filefolders.name}'; % get the names of the folders
filefolders             = filefolders(3:end); % remove '.' and '..' folders

pattern                 = '._\d+$'; % regular expression to search for file numbers below

[startinds, endinds]    = regexp(filefolders, pattern, 'start','end'); % find number pattern in the remaining filefolders
filenumbers             = [];

% generate a vector of file numbers from the files in the data folder
for i = 1:length(startinds)
    filenumbers(i)  = str2num(filefolders{i}(startinds{i}+2:endinds{i}));
end

fileind                 = find(filenumbers == datafilenr); % find index of target data folder
filefolder              = filefolders{fileind}; % this is the folder we're after

%% Start collecting events data

if q_digital_events % do we use digital events recorded by openephys? if so use 'all_channels.events' file
    [events timestamps info] = load_open_ephys_data([datafolder filesep filefolder filesep 'all_channels.events']);
    
    % get events for trial, stim, LED. input nr - 1 because of sensible
    % vs. programmer counting
    trial_starts    = timestamps(events == trial_input_nr - 1 & info.eventId == 1);
    trial_ends      = timestamps(events == trial_input_nr - 1 & info.eventId == 0);
    stim_starts  	= timestamps(events == stim_input_nr - 1 & info.eventId == 1);
    stim_ends       = timestamps(events == stim_input_nr - 1 & info.eventId == 0);
    opto_starts      = timestamps(events == opto_input_nr - 1 & info.eventId == 1);
    opto_ends        = timestamps(events == opto_input_nr - 1 & info.eventId == 0);
    switch_up       = timestamps(events == switch_input_nr - 1 & info.eventId == 1);
    switch_down     = timestamps(events == switch_input_nr - 1 & info.eventId == 0);
    
    % some cleaning up 
    trial_starts(trial_starts > trial_ends(end))   = [];
    trial_ends(trial_ends < trial_starts(1))       = [];
    
else % events need to be extracted manually from the analog input signal. 
    
    if switch_input_nr ~= 0
        trial_threshold     = 0.25; % For trial, signal goes up to 2.5V or less
        stim_threshold      = 2.7; % For whisking (always during trial), signal goes up to 2.75 - 5V
        opto_threshold   	= 0.25; % normal TTL logic - 0 to 5V
        switch_threshold    = 2.5; % normal TTL logic - 0 to 5V
    else
        trial_threshold     = 0.25; % normal TTL logic - 0 to 5V
        stim_threshold      = 2.5; % normal TTL logic - 0 to 5V
        opto_threshold    	= 0.25; % LED is no longer TTL, voltage varies with power (with 5V representing max); 0.05V thresh will detect events above ~1% max power
        switch_threshold    = 2.5; % normal TTL logic - 0 to 5V
    end
    
    adc_channel_nrs        	= [trial_input_nr stim_input_nr opto_input_nr switch_input_nr];
    adc_channel_thresholds 	= [trial_threshold stim_threshold opto_threshold switch_threshold];
    
    for a = 1:4 % loop through the analog input channels
        
        if a == 1 || adc_channel_nrs(a) ~= adc_channel_nrs(a-1) % Don't reload data if trace is already loaded
            disp(['Loading ADC input channel ' num2str(adc_channel_nrs(a))])
            disp(['File ' datafolder filesep filefolder filesep data_prefix '_ADC' num2str(adc_channel_nrs(a)) '.continuous'])
            [thisTTL timestamps info] = load_open_ephys_data([datafolder filesep filefolder filesep data_prefix '_ADC' num2str(adc_channel_nrs(a)) '.continuous']);
            
            % thisTTL         = thisTTL - min(thisTTL(:));
            
            starttime       = min(timestamps); % find start time
            endtime         = max(timestamps); % find end time
            timestamps      = (1:length(thisTTL)) / 30000; % manually create new timestamps at 30kHz, openephys sometimes suffers from timestamp wobble even though data acquisition is spot on
            timestamps      = timestamps + starttime; % add start time to the newly created set of timestamps
        end
        
        thisTTL_bool   	= thisTTL > adc_channel_thresholds(a); % find where the TTL signal is 'high'
        
        start_inds      = find(diff(thisTTL_bool) > 0.5); % find instances where the TTL goes from low to high
        end_inds        = find(diff(thisTTL_bool) < -0.5); % find instances where the TTL goes from high to low
        
        if length(start_inds)>length(end_inds)
            end_inds = [end_inds length(thisTTL)];
        end
        
        start_times 	= timestamps(start_inds); % find the timestamps of start events
        end_times    	= timestamps(end_inds); % find the timestamps of end events
        
        if ~isempty(start_times) & ~isempty(end_times)  % Some channels may not have events (e.g. stim switch channel if only 1 stimulator used)
            end_times(end_times < start_times(1))       = []; % discard potential initial end without start
            start_times(start_times > end_times(end))   = []; % discard potential final start without end
        end
        
        switch a % this determines what the start and end timestamps should be assigned to: trial/trial, LED/opto stim or stim/whisk stim.
            case 1
                trial_starts    = start_times(:);
                trial_ends      = end_times(:);
            case 2
                stim_starts 	= start_times(:);
                stim_ends     	= end_times(:);
                
                % Determine stimulus amplitude from signal 
                stim_amps       = NaN(size(start_inds));
                for i = 1:length(start_inds)
                    stim_segment    = thisTTL(start_inds(i):end_inds(i));
                    stim_amps(i)   	= ((median(stim_segment) - 2.5) / 2.5) * 100; % Stimulus amplitude in % of max
                end
            case 3
                opto_starts      = start_times(:);
                opto_ends        = end_times(:);
                
                opto_powers      = NaN(size(start_inds));

                for i = 1:length(start_inds)
                    stim_segment    = thisTTL(start_inds(i):end_inds(i));
                    opto_powers(i) 	= median(stim_segment) / 5 * 100; % Stimulus amplitude in % of max
                end
            case 4
                switch_up       = start_times(:);
                switch_down     = end_times(:);
        end
    end
end

% if we're using a morse signal to detect start and end of the protocol,
% detect morse code for start and end of trials
if qmorse
    trial_lengths 	= trial_ends - trial_starts;
    morse_lengths   = round(trial_lengths * 10);
    
    start_ind       = strfind(morse_lengths(:)',morse_start) + length(morse_start);
    end_ind         = strfind(morse_lengths(:)',morse_stop) - 1;
    
    trial_starts    = trial_starts(start_ind:end_ind);
    trial_ends      = trial_ends(start_ind:end_ind);
end

%% A lot of cleanup and repair from here

if trials_from_whisk
    % We are setting trial starts and ends based on the whisker stimulus;
    % discard previous trial data
    trial_starts    = [];
    trial_counter   = 1;
    for a = 1:length(stim_starts)
        this_stim_start = stim_starts(a);
        if a == 1
            % first stimulus, so this will set the first trial start (= this_stim_start - whisk_buffer)
            trial_starts(trial_counter) = this_stim_start - whisk_buffer;
            trial_counter   = trial_counter + 1; % keep track of which trial we are on
            continue
        elseif (stim_starts(a) - whisk_buffer) <= stim_starts(a-1)
            % the interval between this stim start and the previous one is
            % too small for them to have happened in different trials;
            % don't increment trial number, and investigate next stim start
            % time
            continue
        elseif (stim_starts(a) - whisk_buffer) > stim_starts(a-1)
            % interval between this stim start and the previous one is
            % large and so this stimulus is happening in a new trial;
            % set new trial start, and increment trial counter
            trial_starts(trial_counter) = this_stim_start - whisk_buffer;
            trial_counter = trial_counter + 1;
        end
    end
    trial_ends = trial_starts + 2 * whisk_buffer;
end

% determine median trial length
trial_times     = trial_ends - trial_starts;
trial_length    = round(median(trial_times),1);

% all trials should have the same length; trials with anomalous
% length are likely arduino startup floating voltage artefacts; get rid
% of anomalies
qtrial          = round(trial_times,1) == trial_length;

trial_starts    = trial_starts(qtrial);
trial_ends      = trial_ends(qtrial);

total_length 	= round(median(diff(trial_starts)),3);
trial_gap       = median(trial_ends - trial_starts);

%% At the end, simply chuck trials with no events in them?
%% Allwhisks??

if isempty(stim_starts)
    stim_starts = [0 0.02];
    stim_ends   = [0.01 00.03]; % set some fake whisk stimuli outside of the trials
    stim_amps   = [1 1];
end


%% 

allwhisks                   = stim_starts; % ?
allwhisk_ends               = stim_ends;
%% dealing with bursts of whisker stimuli

first_stim_inds             = find(diff(allwhisks) > total_length/2)+1;

if ~isempty(first_stim_inds)
    % Find which whisking onsets are the first of a trial, and which onsets
    % are the last of a trial
    allwhisk_firstvect          = allwhisks(first_stim_inds);
    allwhisk_lastvect           = allwhisks(first_stim_inds-1);% Stimulus amplitude
    
    whisk_ends               	= allwhisk_ends(first_stim_inds);
    whisk_ends                	= [allwhisk_ends(1); whisk_ends(:)];
    
    stim_amps                   = stim_amps(first_stim_inds);
    stim_amps                   = [stim_amps(1); stim_amps(:)];
else
    allwhisk_firstvect          = [];
    allwhisk_lastvect           = [];
    
    whisk_ends                  = allwhisk_ends;
end

whisk_starts            	= [allwhisks(1); allwhisk_firstvect(:)];
whisk_lasts              	= [allwhisk_lastvect(:); allwhisks(end)];


% Stimulus length and repeat frequency
whisk_lengths              	= whisk_ends - whisk_starts;
whisk_freqs              	= NaN(size(whisk_starts));

for a = 1:length(whisk_starts)
    this_whisk_start    = whisk_starts(a);
    this_whisk_end      = whisk_lasts(a);
    q_whisks            = allwhisks > this_whisk_start & allwhisks < this_whisk_end;

    this_whisk_freq   	= mean(round(1./diff(allwhisks(q_whisks))));
    if isempty(this_whisk_freq)
        this_whisk_freq = 99;
    elseif isnan(this_whisk_freq)
        this_whisk_freq = 99;
    end
    whisk_freqs(a)      = this_whisk_freq;
end

allwhisks             	= whisk_starts;

%% opto burst 
if isempty(opto_starts)
    opto_starts = [0 0.02];
    opto_ends   = [0.01 00.03]; % set some fake opto stimuli outside of the trials
    opto_powers = [1 1];
end


first_opto_inds             = find(diff(opto_starts) > total_length/2)+1;

if ~isempty(first_opto_inds)
    opto_firsts                 = opto_starts(first_opto_inds);
    opto_lasts                  = opto_starts(first_opto_inds-1);
    
    opto_burst_ends          	= opto_ends(first_opto_inds);
    opto_burst_ends          	= [opto_burst_ends(1); opto_burst_ends(:)];
    
    opto_amps                   = opto_powers(first_opto_inds);
    opto_amps                   = [opto_amps(1); opto_amps(:)];
    
else
    opto_firsts                 = [];
    opto_lasts                  = [];
    
    opto_burst_ends             = opto_ends;
end

opto_firsts                 = [opto_starts(1); opto_firsts(:)];
opto_lasts                  = [opto_lasts(:); opto_starts(end)];

opto_lengths              	= opto_ends - opto_starts;
opto_freqs              	= NaN(size(opto_starts));

for a = 1:length(opto_firsts)
    this_opto_first     = opto_firsts(a);
    this_opto_last   	= opto_lasts(a);
    
    q_opto_burst        = opto_starts > this_opto_first & opto_starts < this_opto_last;
    
    this_opto_freq   	= mean(round(1./diff(opto_starts(q_opto_burst))));
    if isempty(this_opto_freq)
        this_opto_freq  = 99;
    elseif isnan(this_opto_freq)
        this_opto_freq  = 99;
    end
    
    opto_freqs(a)      = this_opto_freq;
    
end

%% Match events to trials
ntrials                 = length(trial_starts);

whisk_stim_onsets       = NaN(size(trial_starts));
whisk_stim_lengths      = NaN(size(trial_starts));
whisk_stim_freqs        = NaN(size(trial_starts));
whisk_stim_relay        = NaN(size(trial_starts));
whisk_stim_amplitudes   = NaN(size(trial_starts));

opto_onsets             = NaN(size(trial_starts));
opto_offsets            = NaN(size(trial_starts));
opto_current_levels     = NaN(size(trial_starts));
opto_freq               = NaN(size(trial_starts));

for a = 1:ntrials
    this_trial_start    = trial_starts(a);
    this_trial_end      = trial_ends(a);
    
    % see whether there was a whisker stimulus
	select_whisk_start 	= whisk_starts >= this_trial_start & whisk_starts <= this_trial_end;
    
    select_opto_start   = opto_firsts >= this_trial_start & opto_firsts <= this_trial_end;
    
    if sum(select_whisk_start) == 1
        whisk_stim_onsets(a)        = allwhisks(select_whisk_start);
        whisk_stim_lengths(a)       = whisk_lengths(select_whisk_start);
        whisk_stim_freqs(a)         = whisk_freqs(select_whisk_start);
        whisk_stim_amplitudes(a)    = stim_amps(select_whisk_start);
        
        % Determine which stimulator is being used (relay up = stim 2, relay down = stim 1)
        stim_start_mat_temp         = repmat(whisk_stim_onsets(a),size(switch_up));
        is_switch_up               	= stim_start_mat_temp > switch_up & stim_start_mat_temp < switch_down;
        
        if any(is_switch_up)
            whisk_stim_relay(a)     = 2;
        else
            whisk_stim_relay(a)     = 1;
        end
    elseif sum(select_whisk_start) > 1
        error('Multiple whisker stimulus values found for this trial')
    end
    
    % see whether there was an LED on / offset here
    select_opto_start       = opto_firsts >= this_trial_start & opto_firsts <= this_trial_end;
    select_opto_end         = opto_lasts >= this_trial_start & opto_lasts <= this_trial_end;
    
    if sum(select_opto_start) == 1 && sum(select_opto_end) == 1
        opto_onsets(a)           = opto_starts(select_opto_start);
        opto_offsets(a)          = opto_ends(select_opto_end);
        opto_current_levels(a)   = opto_powers(select_opto_start);
        opto_freq(a)             = opto_freqs(select_opto_start);
    elseif sum(select_opto_start) > 1 || sum(select_opto_end) > 1
        error('Multiple LED stimulus values found for this trial')
    elseif sum(select_opto_start) ~= sum(select_opto_end)
        error('Mismatch in number of detected LED onsets and offsets for this trial')
    end
    
end

opto_starts     = opto_onsets;
opto_ends       = opto_offsets;
allwhisks       = whisk_stim_onsets;
whisk_freqs     = whisk_stim_freqs;
whisk_lengths   = whisk_stim_lengths;
stim_amps       = whisk_stim_amplitudes;
opto_powers     = opto_current_levels;

%% 

switch expt_type % for each experiment, make sure not to split conditions by other conditions - NEEDS WORK
    case 'Velocity'
        binvec                  = [0:0.0001:2];
        [pks, locs]             = findpeaks(smooth(histc(whisk_lengths,binvec),3),'MinPeakHeight',3);
        length_vals             = binvec(locs);
        whisk_lengths           = interp1(length_vals,length_vals,whisk_lengths,'nearest','extrap');
    otherwise
        median_whisk_length     = nanmedian(whisk_lengths);
        whisk_lengths         	= repmat(median_whisk_length,size(whisk_lengths));
end

stim_amps   = round(stim_amps / 5) * 5; % round to nearest 5%
opto_powers  = round(opto_powers / 5) * 5; % round to nearest 5%

%% Done with clean-up and event extraction; now determine the different conditions

% recover LED delays
LED_delays                  = round((opto_starts(:) - trial_starts(:)) / LED_conditions_res,3) * LED_conditions_res;

% recover whisking delays
whisk_delays                = round((allwhisks(:) - trial_starts(:)) / whisk_conditions_res,3) * whisk_conditions_res;

% recover LED durations
LED_ontimes                 = opto_ends - opto_starts;
LED_durations               = round(LED_ontimes(:) / 5,3) * 5;

% reconstruct trial matrix
trial_conditions         	= [LED_delays(:) whisk_delays(:) LED_durations(:) whisk_freqs(:) round(1./whisk_lengths(:)) whisk_stim_relay(:) stim_amps(:) opto_powers(:) opto_freq(:)];

condition_headers           = {'LED start time' 'Whisk start time' 'LED duration' 'Whisk frequency' 'Whisk velocity' 'Whisk stim number' 'Whisk amplitude' 'LED Power' 'Opto_frequency'};

trial_conditions(isnan(trial_conditions)) = 999; % pass numerical flag for missing values / absent stimuli, 'unique' doesn't work well with NaNs (NaN ~= NaN)

% extract different conditions from trial matrix
[conditions, cond_inds, cond_vect]  = unique(trial_conditions,'rows');

conditions(conditions == 999)       = NaN; % replace flag with NaN again so it is clear which stimuli are absent for certain conditions

if q_override
    conditions  = zeros(n_conds,5);
    cond_vect   = repmat([1:n_conds]',length(cond_vect)/n_conds,1);
end

cond_nrs        = 1:size(conditions,1);

%% Get trace data (filter for spikes using 300 - 6000 Hz bandpass; can get LFP filtering e.g. with a 1-300Hz pass)
% initialise butterworth bandpass filter
samplefreq = 30000;

[filt_b,filt_a]           = butter(2, [500 6000]/(samplefreq/2));

[LFPfilt_b, LFPfilt_a]    = butter(2, [1 300]/(samplefreq/2));
LFPtraces       = [];
LFPtimestamps  	= [];

if qspike_detection || get_LFP % 'manual' spike detection in matlab

%     if q_common_average_ref
%         CAR_trace   = 0;
%         for a = 1:n_channels
%             disp(['Loading channel ' num2str(a)]);
%             [thistrace timestamps info] = load_open_ephys_data([datafolder filesep filefolder filesep data_prefix '_CH' num2str(get_channels(a)) '.continuous']);
%             
%             CAR_trace = CAR_trace + (1/n_channels) * thistrace;
%         end
%     end
%     
    for a = 1:n_channels
        disp(['Loading channel ' num2str(a)]);
        [thistrace timestamps info] = load_open_ephys_data([datafolder filesep filefolder filesep data_prefix '_CH' num2str(get_channels(a)) '.continuous']);
        
        starttime          	= min(timestamps); % get original offset
        
        timestamps          = ((1:length(thistrace)) / 30000); % generate timestamps (openephys output t)
        
        % Do simple homebrew spike detection by 1) filtering with bandpass, 2) smoothing and 3) thresholding
        spiketrace        	= filter(filt_b,filt_a,thistrace); % filter data with butterworth bandpass filter to get spike traces
        spiketrace        	= smooth(spiketrace, spike_smoothwin); % smooth data with
        
        q_threshold         = (-spiketrace) > (spike_thresh * std(spiketrace)); % determine standard deviation to determine threshold, detect threshold crossings (negative)
        spike_bool          = diff(q_threshold) == 1; % Determine instances of threshold being crossed 
        these_spike_times 	= timestamps(spike_bool); % Get the timestamps of these instances
        
        spikes(a).times     = these_spike_times + starttime; % put original offset back
        spikes(a).waveforms = [];
        spikes(a).info      = [];
        
        if get_LFP
            LFPtrace        = filter(LFPfilt_b,LFPfilt_a,thistrace);
            LFPtrace        = LFPtrace(1:30:end); % resample at 1000Hz
            LFPtimestamps   = timestamps(1:30:end)+ starttime; % resample to 1000Hz
            
            LFPtraces       = [LFPtraces LFPtrace(:)];
        end
    end
else  % use spikes detected from openephys .spikes file instead
    spikes  = []; % initialise spikes. Will become a 1xmaxchannelnr struct
    for a = 1:n_channels
        if q_channelmap
            [spike_waves these_spike_times info] = load_open_ephys_data([datafolder filesep filefolder filesep 'SE' num2str(a-1) '.spikes']);
        else
            [spike_waves these_spike_times info] = load_open_ephys_data([datafolder filesep filefolder filesep 'SE' num2str(get_channels(a)-1) '.spikes']);
        end
        
        spikes(a).times     = these_spike_times;
        spikes(a).waveforms = spike_waves;
        spikes(a).info      = info;
    end
end


%% Sort spikes by trial and condition

cond_counters   = zeros(size(conditions,1),n_channels);
channels        = struct;   % initialise output variable

for a = 1:n_channels
    for b = 1:max(cond_nrs)
        channels(a).conditions(b).timings = conditions(b,:);
    end
end


if strcmpi(data_output,'old')
    for a = 1:n_channels
        chan_spike_times    = [];
        for b = 1:length(trial_starts)
            qspiketimes                 = spikes(a).times >= trial_starts(b) & spikes(a).times < trial_ends(b);
            thesespiketimes             = spikes(a).times(qspiketimes);
            thesespiketimes             = thesespiketimes - trial_starts(b);
            
            thiscond                    = cond_vect(b);
            cond_counters(thiscond,a)   = cond_counters(thiscond,a) + 1;
            
            channels(a).conditions(thiscond).episodes(cond_counters(thiscond,a)).spikes         = thesespiketimes(:);
            channels(a).conditions(thiscond).episodes(cond_counters(thiscond,a)).trial_start    = trial_starts(b);
            channels(a).conditions(thiscond).episodes(cond_counters(thiscond,a)).trial_end      = trial_ends(b);
            
            chan_spike_times            = [chan_spike_times; thesespiketimes(:)];
            
            % LFP processing. Is it better to simply do this by condition, and
            % then have a matrix of data x episodes x data length?
            if get_LFP
                qLFPtimestamps          = LFPtimestamps >= trial_starts(b) & LFPtimestamps < trial_ends(b);
                channels(a).conditions(thiscond).episodes(cond_counters(thiscond,a)).LFP_trace = LFPtraces(qLFPtimestamps,a);
            end
        end
        
        %% spont spike rate
        spontspikes     = chan_spike_times(chan_spike_times >= (spontwin(1) / 1000) & chan_spike_times < (spontwin(2) / 1000));
        spontwinsize    = (spontwin(2) - spontwin(1)) / 1000;           % size of window in seconds
        channels(a).spontspikerate   = length(spontspikes) / spontwinsize / ntrials; % spontaneous spike rate by channel
        
    end
    ephys_data = channels;
elseif strcmpi(data_output,'new')
    for a = 1:n_channels
        for b = 1:length(trial_starts)
            qspiketimes                 = spikes(a).times >= trial_starts(b) & spikes(a).times < trial_ends(b);
            thesespiketimes             = spikes(a).times(qspiketimes);
            thesespiketimes             = thesespiketimes - trial_starts(b);
            
            thiscond                    = cond_vect(b);
            cond_counters(thiscond,a)   = cond_counters(thiscond,a) + 1;
            
            ephys_data.conditions(thiscond).spikes(a,cond_counters(thiscond,a),1:length(thesespiketimes(:)))  = thesespiketimes(:);
            
            % add trial time data
            if a == 1
                ephys_data.conditions(thiscond).trial_starts_timestamps(cond_counters(thiscond,a))	= trial_starts(b);
                ephys_data.conditions(thiscond).trial_ends_timestamps(cond_counters(thiscond,a))   	= trial_ends(b);
                ephys_data.conditions(thiscond).trial_starts(cond_counters(thiscond,a))             = trial_starts(b) - starttime;
                ephys_data.conditions(thiscond).trial_ends(cond_counters(thiscond,a))               = trial_ends(b) - starttime;
            end
            
            % LFP processing. Is it better to simply do this by condition, and
            % then have a matrix of data x episodes x data length?
            if get_LFP
                qLFPtimestamps              = LFPtimestamps >= trial_starts(b) & LFPtimestamps < trial_ends(b);
                ephys_data.conditions(thiscond).LFP_trace(a,cond_counters(thiscond,a),1:length(LFPtraces(qLFPtimestamps,a))) = LFPtraces(qLFPtimestamps,a);
                ephys_data.LFP_timestamps   = 1:sum(qLFPtimestamps) / 30000;
            end
        end
    end
    
    for i = 1:length(ephys_data.conditions)
        ephys_data.conditions(i).values             = conditions(i,:);
        ephys_data.conditions(i).n_trials           = size(ephys_data.conditions(i).spikes,2);
        ephys_data.conditions(i).whisk_onset        = conditions(i,2);
        ephys_data.conditions(i).whisk_stimulator 	= conditions(i,6);
        ephys_data.conditions(i).whisk_amplitude    = conditions(i,7);
        ephys_data.conditions(i).whisk_velocity     = conditions(i,5);
        ephys_data.conditions(i).whisk_frequency    = conditions(i,4);
        ephys_data.conditions(i).LED_onset          = conditions(i,1);
        ephys_data.conditions(i).LED_power          = conditions(i,8);
        ephys_data.conditions(i).LED_duration       = conditions(i,3);
        ephys_data.conditions(i).opto_freq          = conditions(i,9);
        ephys_data.conditions(i).spikes(ephys_data.conditions(i).spikes == 0) = NaN; % replace empty values for spike matrix (default to 0) with NaN
    end
    
    ephys_data.condition_values     = conditions;
    ephys_data.condition_names      = condition_headers;
    ephys_data.trial_length         = trial_length;
    ephys_data.trial_interval       = total_length;
    ephys_data.block_length         = total_length * length(ephys_data.conditions);
    ephys_data.protocol_duration    = total_length * length(trial_starts);
    ephys_data.parameters           = parameters;
    ephys_data.data_folder          = filefolder;
    ephys_data.channelmap           = get_channels;
    ephys_data.start_time           = starttime;
    ephys_data.end_time             = endtime;
    ephys_data.rec_length           = endtime - starttime;
else
    error('Unrecognised ''data_output'' requested, available options are ''old'' and ''new''')
end


