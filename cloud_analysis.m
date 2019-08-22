






meancount1 = [];
meancount3 = [];

 for i = 1:30
    
    spikes1 = squeeze(ephys_data.conditions(:,1).spikes(:,i,:));
    
    spikes1 = spikes1 - 1;
    
    count1 = sum(spikes1 >= 0 ,2);
    
    count_1 = sum(spikes1 <=0 ,2); 
    
    count__1 = sum(spikes1 <=0.2 ,2) - count_1; 
    
    count1 = count1 - count__1;
    
    spikes3 = squeeze(ephys_data.conditions(:,3).spikes(:,i,:));
 
    spikes3 = spikes3 - 1;
    
    count3 = sum(spikes3 >= 0 ,2);
    
    count_3 = sum(spikes3 <=0 ,2); 
    
    count__3 = sum(spikes3 <=0.2 ,2) - count_3; 
    
    count3 = count3 - count__3;
    figure(1)
    
    meanc1(i) = mean(count1);
    
    meancount1(1,:) = meanc1(i);
    
    meanc3(i) = mean(count3);
    
    meancount1(1,:) = meanc3(i);


scatter(count1, count3)
axis([0 250 0 250])
c = polyfit(count1, count3, 1); 
y_est = polyval(c, count1); 
disp(['Equation is y = ' num2str(c(1)) '*x + ' num2str(c(2))])

hold on 

% x = (1:250);
% y = 1*x; 
% 
% plot(y, 'color', [0 0 0], 'linewidth', 3)


 end

 meancount3 = mean(count3); 
 
 meancount1 = mean(count1); 
 
 plot(meancount3, meancount1, 'color', [0 0 0], 'linewidth', 3)
 
 hold off
 
 
 for i = 1:30
    
    spikes2 = squeeze(ephys_data.conditions(:,2).spikes(:,i,:));
    
    spikes2 = spikes2 - 1;
    
    count2 = sum(spikes2 >= 0 ,2);
    
    count_2 = sum(spikes2 <=0 ,2); 
    
    count__2 = sum(spikes2 <=0.2 ,2) - count_2; 
    
    count2 = count2 - count__2;
    
    spikes4 = squeeze(ephys_data.conditions(:,4).spikes(:,i,:));
 
    spikes4 = spikes4 - 1;
    
    count4 = sum(spikes4 >= 0 ,2);
    
    count_4 = sum(spikes4 <=0 ,2); 
    
    count__4 = sum(spikes4 <=0.2 ,2) - count_3; 
    
    count4 = count4 - count__4;
    figure(2)

scatter(count2, count4)
axis([0 250 0 250])
c = polyfit(count2, count4, 1); 
y_est = polyval(c, count2); 
disp(['Equation is y = ' num2str(c(1)) '*x + ' num2str(c(2))])
hold on 
%plot(count2,y_est, 'linewidth', 3)
% plot(y, 'color', [0 0 0], 'linewidth', 3)
   
 end
 
 hold off
 