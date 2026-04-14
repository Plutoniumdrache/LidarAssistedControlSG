%% Compare FAST v3 vs v4.2

% load FAST v3 results
Fast4d2SinglePoint_ROSCO2d6 = load("results\Fast4d2SinglePoint_ROSCO2d6.mat");
Fast4d2SinglePoint_ROSCO2d10d1 = load("results\Fast4d2SinglePoint_ROSCO2d10d1.mat");

% Plot 
figure('Name','Comparison ROSCO 2.6 vs. 2.10.1')

subplot(4,1,1);
hold on; grid on; box on
plot(Fast4d2SinglePoint_ROSCO2d6.FB.Time, Fast4d2SinglePoint_ROSCO2d6.FB.Wind1VelX);
plot(Fast4d2SinglePoint_ROSCO2d10d1.FB.Time,       Fast4d2SinglePoint_ROSCO2d10d1.FB.Wind1VelX);
% plot(FBFF_R.Time,   FBFF_R.REWS_b);
ylabel({'[m/s]';'Wind1VelX'});
legend('R 2.6','R 2.10.1','Interpreter','none','Location','best')

subplot(4,1,2);
hold on; grid on; box on
plot(Fast4d2SinglePoint_ROSCO2d6.FB.Time, Fast4d2SinglePoint_ROSCO2d6.FB.BldPitch1);
plot(Fast4d2SinglePoint_ROSCO2d10d1.FB.Time,       Fast4d2SinglePoint_ROSCO2d10d1.FB.BldPitch1);
% plot(FBFF.Time,     FBFF.BldPitch1);
ylabel({'BldPitch1'; '[deg]'});
legend('R 2.6','R 2.10.1','Interpreter','none','Location','best')

subplot(4,1,3);
hold on; grid on; box on
plot(Fast4d2SinglePoint_ROSCO2d6.FB.Time, Fast4d2SinglePoint_ROSCO2d6.FB.RotSpeed);
plot(Fast4d2SinglePoint_ROSCO2d10d1.FB.Time,       Fast4d2SinglePoint_ROSCO2d10d1.FB.RotSpeed);
% plot(FBFF.Time,     FBFF.RotSpeed);
ylabel({'RotSpeed';'[rpm]'});
legend('R 2.6','R 2.10.1','Interpreter','none','Location','best')

subplot(4,1,4);
hold on; grid on; box on
plot(Fast4d2SinglePoint_ROSCO2d6.FB.Time, Fast4d2SinglePoint_ROSCO2d6.FB.TwrBsMyt/1e3);
plot(Fast4d2SinglePoint_ROSCO2d10d1.FB.Time,       Fast4d2SinglePoint_ROSCO2d10d1.FB.TwrBsMyt/1e3);
% plot(FBFF.Time,     FBFF.TwrBsMyt/1e3);
ylabel({'TwrBsMyt';'[MNm]'});
legend('R 2.6','R 2.10.1','Interpreter','none','Location','best')

xlabel('time [s]')
linkaxes(findobj(gcf, 'Type', 'Axes'),'x');
% xlim([0 50])