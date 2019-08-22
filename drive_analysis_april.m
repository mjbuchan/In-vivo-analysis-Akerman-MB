


spike_window = squeeze(mean(target_spikes,1));

whisk_spikes = [];

for i = 1:length(spike_window(:,1);

index_min = find(abs(spike_window(i,:)<1.005); 

index_max = find(abs(spike_window(i,:)>1.050); 



spike_window(index_min) = [];

spike_values(index_max) = [];

whisk_spikes(i,:) = rmmissing(spike_values);

end