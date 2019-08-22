figure(1)
psth(ephys_data(1).conditions(1).spikes(1:32,:,:),0.0001)

for a = 1:32
    
    opto_count(a,:) = spike_rate_by_channel(ephys_data(1).conditions(1).spikes(a,:,:), [0.075 0.08]);
    spont_count(a,:) = spike_rate_by_channel(ephys_data(1).conditions(1).spikes(a,:,:), [0.00 0.05]);
end 

for b = 1:470

tracking_ratio(b,:) = spike_rate_by_channel(ephys_data(1).conditions(1).spikes(:,[b+10],:), [0.06 0.08])./spike_rate_by_channel(ephys_data(1).conditions(1).spikes(:,[1:470],:), [0.06 0.08]);


end

tracking_ratio(tracking_ratio==inf) = nan;

comp_tracker = spike_rate_by_channel(ephys_data(1).conditions(1).spikes(:,[460:480],:), [0.06 0.08])./spike_rate_by_channel(ephys_data(1).conditions(1).spikes(:,[1:10],:), [0.06 0.08]);
comp_tracker(comp_tracker==inf) = nan;
comp_tracker = comp_tracker./spike_rate_by_channel(ephys_data(1).conditions(1).spikes(:,1,:), [0.06 0.08]);

comp_tracker_2 = nanmean(comp_tracker);



tracking_average = nanmean(tracking_ratio, 2);

tracking_average = (tracking_average./tracking_average(1,1))*100;

norm_tracking_average = (tracking_average./median(tracking_average(1:50,1)))*100;
norm_tracking_average(:,2) = [1:470];


opto_count = (opto_count./spont_count);
    
figure (2) 
    
bar(opto_count)

% fitobject = fit(norm_tracking_average(:,2), norm_tracking_average(:,1), 'poly2');
response = norm_tracking_average(:,1);



norm_fit = movmean(response, 50);

figure (3)
% plot(response);

hold on 

% plot(fitobject)
plot(norm_fit)





   