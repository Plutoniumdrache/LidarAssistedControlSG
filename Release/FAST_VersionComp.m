%% Compare FAST Versions

% Run FAST 3.0
run("IEA15MW_01\RunExample.m")
% run FAST 5.0
run("IEA15MW_01_FASTv5\RunExample.m")

%% compare to FAST v3 to v5
FB_v3SP = load("IEA15MW_01/results/FASTv3LidarSignalProvider_FB.mat");
FBFF_v3SP = load("IEA15MW_01/results/FASTv3LidarSignalProvider_FBFF.mat");

FB_v5SP = load("IEA15MW_01_FASTv5/results/FASTv5LidarSignalProvider_FB.mat");
FBFF_v5SP = load("IEA15MW_01_FASTv5/results/FASTv5LidarSignalProvider_FBFF.mat");

% Plot
figure('Name','Feedback FAST v3 vs. v5')

subplot(4,1,1);
hold on; grid on; box on
plot(FB_v3SP.FB.Time,   FB_v3SP.FB.Wind1VelX);
plot(FB_v3SP.FB.Time,   FB_v3SP.FB.Wind1VelX);
ylabel({'Wind1VelX';'[m/s]'});
legend('FAST v3','FAST v5')

subplot(4,1,2);
hold on; grid on; box on
plot(FB_v3SP.FB.Time,       FB_v3SP.FB.BldPitch1);
plot(FB_v3SP.FB.Time,       FB_v3SP.FB.BldPitch1);
ylabel({'BldPitch1'; '[deg]'});
legend('FAST v3','FAST v5')

subplot(4,1,3);
hold on; grid on; box on
plot(FB_v3SP.FB.Time,       FB_v3SP.FB.RotSpeed);
plot(FB.Time,     FB.RotSpeed);
ylabel({'RotSpeed';'[rpm]'});

subplot(4,1,4);
hold on; grid on; box on
plot(FB_v3SP.FB.Time,       FB_v3SP.FB.TwrBsMyt/1e3);
plot(FB.Time,     FB.TwrBsMyt/1e3);
ylabel({'TwrBsMyt';'[MNm]'});

xlabel('time [s]')
linkaxes(findobj(gcf, 'Type', 'Axes'),'x');
xlim([0 30])

% Plot compare feedback-feedforward
figure('Name','feedback-feedforward FAST v3 vs. v5')

subplot(4,1,1);
hold on; grid on; box on
plot(FBFF_v3SP.FBFF.Time,   FBFF_v3SP.FBFF.Wind1VelX);
plot(FBFF.Time,           FBFF.Wind1VelX);
ylabel({'Wind1VelX';'[m/s]'});
legend('FAST v3','FAST v5')

subplot(4,1,2);
hold on; grid on; box on
plot(FBFF_v3SP.FBFF.Time,       FBFF_v3SP.FBFF.BldPitch1);
plot(FBFF.Time,     FBFF.BldPitch1);
ylabel({'BldPitch1'; '[deg]'});
legend('FAST v3','FAST v5')

subplot(4,1,3);
hold on; grid on; box on
plot(FBFF_v3SP.FBFF.Time,       FBFF_v3SP.FBFF.RotSpeed);
plot(FBFF.Time,     FBFF.RotSpeed);
ylabel({'RotSpeed';'[rpm]'});

subplot(4,1,4);
hold on; grid on; box on
plot(FBFF_v3SP.FBFF.Time,       FBFF_v3SP.FBFF.TwrBsMyt/1e3);
plot(FBFF.Time,     FBFF.TwrBsMyt/1e3);
ylabel({'TwrBsMyt';'[MNm]'});

xlabel('time [s]')
linkaxes(findobj(gcf, 'Type', 'Axes'),'x');
xlim([0 30])