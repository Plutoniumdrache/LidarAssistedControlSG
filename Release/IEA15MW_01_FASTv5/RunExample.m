% IEA15MW_01: IEA 15 MW monopile + perfect wind preview from a single point 
% lidar system.
% Origin and changes in files: see ChangeLog.txt.
% Purpose:
% Here, we use a perfect wind preview to demonstrate that the collective
% pitch feedforward controller (designed with SLOW) is able to reduce
% significantly the rotor speed variation when OpenFAST is disturbed by an
% Extreme Operating Gust. Here, only the rotor motion and tower motion 
% (GenDOF and TwFADOF1) are enabled.  
% Result:
% Cost for Summer Games 2024 ("30 s sprint"):  0.849094

%% Setup
clearvars;close all;clc;
addpath(genpath('..\WetiMatlabFunctions'))

% Copy the adequate OpenFAST version to the example folder
FASTexeFile     = 'OpenFASTv5.exe';
SimulationName  = 'IEA-15-240-RWT-Monopile';
copyfile(['..\OpenFAST\',FASTexeFile],FASTexeFile)

%% Run FB
ManipulateTXTFile('ROSCO_v2d6.IN','1 ! FlagLAC','0 ! FlagLAC');     % disable LAC
dos([FASTexeFile,' ',SimulationName,'.fst']);                       % run OpenFAST
movefile([SimulationName,'.outb'],[SimulationName,'_FB.outb'])      % store results
%% Run FBFF  
ManipulateTXTFile('ROSCO_v2d6.IN','0 ! FlagLAC','1 ! FlagLAC');     % enable LAC
dos([FASTexeFile,' ',SimulationName,'.fst']);                       % run OpenFAST
movefile([SimulationName,'.outb'],[SimulationName,'_FBFF.outb'])    % store results
%% Clean up
delete(FASTexeFile)
%% read in data
FB              = ReadFASTbinaryIntoStruct([SimulationName,'_FB.outb']);
FBFF            = ReadFASTbinaryIntoStruct([SimulationName,'_FBFF.outb']);
save("results/FASTv5LidarSignalProvider_FB","FB");
save("results/FASTv5LidarSignalProvider_FBFF","FBFF");
swapContents = readmatrix("TestBench_SwapLog.txt");
movefile("IEA-15-240-RWT-Monopile.RO.dbg","IEA-15-240-RWT-Monopile.txt");
roscoLog = readmatrix("IEA-15-240-RWT-Monopile.txt");

%% additinoal plots
figure('Name','Simulation results')

subplot(4,1,1);
hold on; grid on; box on
plot(roscoLog(:,1),roscoLog(:,26)) % rosco FF rate
ylabel('[rad/s]');
legend('rosco FF rate')

subplot(4,1,2);
hold on; grid on; box on
plot(FBFF.Time,     FBFF.BldPitch1);
ylabel({'BldPitch1'; '[deg]'});
legend('feedback-feedforward')

subplot(4,1,3);
hold on; grid on; box on
% plot(FB.Time,       FB.RotSpeed);
% plot(FBFF.Time,     FBFF.RotSpeed);
ylabel({'RotSpeed';'[rpm]'});

subplot(4,1,4);
hold on; grid on; box on
% plot(FB.Time,       FB.TwrBsMyt/1e3);
% plot(FBFF.Time,     FBFF.TwrBsMyt/1e3);
ylabel({'TwrBsMyt';'[MNm]'});

xlabel('time [s]')
linkaxes(findobj(gcf, 'Type', 'Axes'),'x');
xlim([0 30])

%% Comparison
% Plot
figure('Name','Simulation results')

subplot(4,1,1);
hold on; grid on; box on
plot(FB.Time,       FB.Wind1VelX);
plot(swapContents(1:end-1,1),swapContents(1:end-1,2)) % lidar preview
% plot(FBFF.Time,     FBFF.VLOS01LI);
% legend('Hub height wind speed','Vlos')
ylabel('[m/s]');
legend('Wind1VelX','swapContents (VLOS01LI)')

subplot(4,1,2);
hold on; grid on; box on
plot(FB.Time,       FB.BldPitch1);
plot(FBFF.Time,     FBFF.BldPitch1);
ylabel({'BldPitch1'; '[deg]'});
legend('feedback only','feedback-feedforward')

subplot(4,1,3);
hold on; grid on; box on
plot(FB.Time,       FB.RotSpeed);
plot(FBFF.Time,     FBFF.RotSpeed);
ylabel({'RotSpeed';'[rpm]'});

subplot(4,1,4);
hold on; grid on; box on
plot(FB.Time,       FB.TwrBsMyt/1e3);
plot(FBFF.Time,     FBFF.TwrBsMyt/1e3);
ylabel({'TwrBsMyt';'[MNm]'});

xlabel('time [s]')
linkaxes(findobj(gcf, 'Type', 'Axes'),'x');
xlim([0 30])

% display results
RotSpeed_0  = 7.56;     % [rpm]
TwrBsMyt_0  = 158.3e3;  % [kNm]
t_Start     = 0;        % [s]

Cost = (max(abs(FBFF.RotSpeed(FBFF.Time>=t_Start)-RotSpeed_0))) / RotSpeed_0 ...
     + (max(abs(FBFF.TwrBsMyt(FBFF.Time>=t_Start)-TwrBsMyt_0))) / TwrBsMyt_0;

fprintf('Cost for Summer Games 2024 ("30 s sprint"):  %f \n',Cost);
%% InAndOut interpolation test
% doInAndOutInterpolationTest = false;
% if doInAndOutInterpolationTest
%     % x = 0:pi/4:2*pi;
%     x = 0:0.1:30;
%     v = sin(x);
%     xq = 0:0.0125:30;
%     figure
%     vq1 = interp1(x,v,xq);
%     plot(x,v,'o',xq,vq1,':.');
%     hold on
%     plot(xq,sin(xq))
%     % xlim([0 2*pi]);
%     title('(Default) Linear Interpolation');
%     legend("sample points","sample values","query points")
%     
%     % write to csv file
%     m = [x;v]';
%     writematrix(m,"interp1Test.csv");
%     
%     DLL = readmatrix("TestBench_SwapLog.txt");
%     MATLAB = readmatrix("interp1Test.csv");
%     vq2 = interp1(MATLAB(:,1),MATLAB(:,2),xq);
%     
%     figure("Name","ComparisonPlot")
%     subplot(211)
%     hold on
%     plot(DLL(1:end-1,1),DLL(1:end-1,2))
%     plot(xq,vq2,'-.')
%     legend("DLL", "MATLAB")
%     subplot(212)
%     plot(DLL(1:length(vq2),1),vq2'-DLL(1:length(vq2),2))
%     legend("delta MATLAB-DLL")
% end
%% plot contents of TestBench_SwapLog.txt


figure("Name","avrSWAPcontents")
hold on
plot(swapContents(1:end-1,1),swapContents(1:end-1,2))
plot(roscoLog(:,1),roscoLog(:,27),".")
% plot(FBFF.Time,     FBFF.VLOS01LI);
plot(FB.Time,       FB.Wind1VelX);
legend("swapAVR contents", "roscoLog REWS", "FAST (Wind1VelX)")
grid; box;


figure("Name","subPlotComp")
subplot(411)
    plot(swapContents(1:end-1,1),swapContents(1:end-1,2))
    legend("swapAVR contents")
    grid; box;
subplot(412)
    plot(roscoLog(:,1),roscoLog(:,27))
    legend("roscoLog REWS")
    grid; box;
subplot(413)
%     plot(FBFF.Time,FBFF.VLOS01LI);
%     legend("FAST (VLOS01LI)")
    grid; box;
subplot(414)
    plot(FB.Time, FB.Wind1VelX);
    legend("FAST (Wind1VelX)")
    grid; box;

%% comparison to summergames base cost
SgBaseCost = 0.849093636670583;
delta = (Cost - SgBaseCost);
deltaPercent = (delta / ((Cost+SgBaseCost)/2))*100;
fprintf("--------------------------------------------------\n");
fprintf("Current cost                        : %f\n", Cost);
fprintf("Delta in %% to base cost  (0.849094) : %f %%\n", deltaPercent);
fprintf("Delta abs. to base cost   (0.849094): %f\n", abs(delta));

%% compare to FAST v3 to v5
FB_v3SP = load("results/FASTv3LidarSignalProvider_FB.mat");
FBFF_v3SP = load("results/FASTv3LidarSignalProvider_FBFF.mat");

% Plot
figure('Name','Feedback FAST v3 vs. v5')

subplot(4,1,1);
hold on; grid on; box on
plot(FB_v3SP.FB.Time,   FB_v3SP.FB.Wind1VelX);
plot(FB.Time,           FB.Wind1VelX);
ylabel({'Wind1VelX';'[m/s]'});
legend('FAST v3','FAST v5')

subplot(4,1,2);
hold on; grid on; box on
plot(FB_v3SP.FB.Time,       FB_v3SP.FB.BldPitch1);
plot(FB.Time,     FB.BldPitch1);
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