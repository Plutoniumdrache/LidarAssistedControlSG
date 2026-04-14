% Sprint: DLC 1.4 for IEA 15 MW monopile with and without LAC. 
% Purpose:
% We want to learn how to simulate a DLC 1.4 with an "Extreme coherent gust 
% with direction change (ECD)" with lidar-assisted control (LAC) and how
% LAC can reduce the ultimate tower loads. 
% Here, only the rotor motion and tower motion (GenDOF, TwFADOF1, TwSSDOF1) 
% are enabled for simplicity.
% Result:       
% Cost for Summer Games 2025 ("30 s sprint"):  0.739948 (4BeamPulsed)
% Cost for Summer Games 2025 ("30 s sprint"):  1.219835 (CircularCW)
tic
%% Setup
clearvars;close all;clc;
addpath(genpath('..\WetiMatlabFunctions'))

% select simulated lidar
LidarType       = 'SinglePoint'; % [4BeamPulsed/CircularCW/SinglePoint]

% define FAST input file
SimulationName  = 'IEA-15-240-RWT-Monopile';

%% Run FB and FF simulation
dos(['openfast_x64_v4d2.exe ',SimulationName,'_FB.fst']); 
dos(['openfast_x64_v4d2.exe ',SimulationName,'_FBFF_',LidarType,'.fst']);

%% Comparison
% read in data
FB                  = ReadFASTbinaryIntoStruct([SimulationName,'_FB.outb']);
FBFF                = ReadFASTbinaryIntoStruct([SimulationName,'_FBFF_',LidarType,'.outb']);
% FBFF_R              = ReadROSCOtextIntoStruct(
% [SimulationName,'_FBFF_',LidarType,'.RO.dbg']); % extremly slow, takes like 80 seconds to read the file
FBFF_R = importROdbg_withUnits([SimulationName,'_FBFF_',LidarType,'.RO.dbg']); % created a new function, way faster (<1 sec)

% save("results/Fast4d2SinglePoint_ROSCO2d6_InflowWt4","FB", "FBFF", "FBFF_R");
% save("results/Fast4d2SinglePoint_ROSCO2d6_InflowWt2","FB", "FBFF", "FBFF_R");
% save("results/Fast4d2SinglePoint_ROSCO2d10d1","FB");
% save("results/Fast4d2_WndT4","FB");

%% Plot 
figure('Name','Simulation results')

subplot(4,1,1);
hold on; grid on; box on
plot(FB.Time,       FB.Wind1VelX);
plot(FBFF_R.Time,   FBFF_R.REWS_b);
plot(FBFF_R.Time, FBFF_R.REWS);
ylabel('[m/s]');
legend('Wind1VelX','REWS_b','REWS (rosco)','Interpreter','none','Location','best')

subplot(4,1,2);
hold on; grid on; box on
plot(FB.Time,       FB.BldPitch1);
plot(FBFF.Time,     FBFF.BldPitch1);
ylabel({'BldPitch1'; '[deg]'});
legend('feedback only','feedback-feedforward','Location','best')

subplot(4,1,3);
hold on; grid on; box on
plot(FB.Time,       FB.RotSpeed);
plot(FBFF.Time,     FBFF.RotSpeed);
ylabel({'RotSpeed';'[rpm]'});

subplot(4,1,4);
hold on; grid on; box on
plot(FB.Time,       FB.TTDspFA);
plot(FBFF.Time,       FBFF.TTDspFA);
% plot(FB.Time,       FB.TwrBsMyt/1e3);
% plot(FBFF.Time,     FBFF.TwrBsMyt/1e3);
ylabel({'TTDspFA';'[m]'});
% ylabel({'TwrBsMyt';'[MNm]'});


xlabel('time [s]')
linkaxes(findobj(gcf, 'Type', 'Axes'),'x');
% xlim([0 30])

% display results
RotSpeed_0  = 7.56;     % [rpm]
TwrBsMyt_0  = 158.3e3;  % [kNm]
t_Start     = 0;        % [s]

Cost = (max(abs(FBFF.RotSpeed(FBFF.Time>=t_Start)-RotSpeed_0))) / RotSpeed_0 ...
     + (max(abs(FBFF.TwrBsMyt(FBFF.Time>=t_Start)-TwrBsMyt_0))) / TwrBsMyt_0;

fprintf('Cost for Summer Games 2025 ("30 s sprint"):  %f \n',Cost);
%% Plot swap array contents
swapContents = readmatrix("TestBench_SwapLog.txt");
figure("Name","avrSWAPcontents")
hold on
plot(FBFF_R.Time,   FBFF_R.REWS_b);
plot(FB.Time,       FB.Wind1VelX);
plot(swapContents(1:end-1,1),swapContents(1:end-1,2))
legend("roscoLog REWS_b", "FAST (Wind1VelX)", "swapAVR contents")
grid; box;

figure("Name","ROSCO log REWS comparison")
subplot(311)
    plot(FBFF_R.REWS)
    legend("REWS")
subplot(312)
    plot(FBFF_R.REWS_b)
    legend("REWS b")
subplot(313)
    plot(FBFF_R.REWS_f)
legend("REWS f")
%% Compare FAST v3 vs v4.2

% % load FAST v3 results
% Fast3d0LidarSim = load("..\Sprint\results\Fast3d0LidarSim.mat");
% 
% % Plot 
% figure('Name','Comparison FAST v3 vs. v4.2')
% 
% subplot(4,1,1);
% hold on; grid on; box on
% plot(Fast3d0LidarSim.FB.Time, Fast3d0LidarSim.FB.Wind1VelX);
% plot(FB.Time,       FB.Wind1VelX);
% % plot(FBFF_R.Time,   FBFF_R.REWS_b);
% ylabel({'[m/s]';'Wind1VelX'});
% legend('FAST v3','FAST v4.2','Interpreter','none','Location','best')
% 
% subplot(4,1,2);
% hold on; grid on; box on
% plot(Fast3d0LidarSim.FB.Time, Fast3d0LidarSim.FB.BldPitch1);
% plot(FB.Time,       FB.BldPitch1);
% % plot(FBFF.Time,     FBFF.BldPitch1);
% ylabel({'BldPitch1'; '[deg]'});
% legend('FAST v3','FAST v4.2','Location','best')
% 
% subplot(4,1,3);
% hold on; grid on; box on
% plot(Fast3d0LidarSim.FB.Time, Fast3d0LidarSim.FB.RotSpeed);
% plot(FB.Time,       FB.RotSpeed);
% % plot(FBFF.Time,     FBFF.RotSpeed);
% ylabel({'RotSpeed';'[rpm]'});
% legend('FAST v3','FAST v4.2','Location','best')
% 
% subplot(4,1,4);
% hold on; grid on; box on
% plot(Fast3d0LidarSim.FB.Time, Fast3d0LidarSim.FB.TwrBsMyt/1e3);
% plot(FB.Time,       FB.TwrBsMyt/1e3);
% % plot(FBFF.Time,     FBFF.TwrBsMyt/1e3);
% ylabel({'TwrBsMyt';'[MNm]'});
% legend('FAST v3','FAST v4.2','Location','best')
% 
% xlabel('time [s]')
% linkaxes(findobj(gcf, 'Type', 'Axes'),'x');
% xlim([20 50])

%% Compare FAST v4.2 EOG WT 4 vs 2 (Bin. vs Ascii)

% % load FAST v3 results
% Fast4d2_WndT4 = load("results\Fast4d2_WndT4.mat");
% Fast4d2_WndT2 = load("results\Fast4d2_WndT2.mat");
% 
% % Plot 
% figure('Name','Comparison FAST WT 4 vs 2')
% 
% subplot(4,1,1);
% hold on; grid on; box on
% plot(Fast4d2_WndT4.FB.Time, Fast4d2_WndT4.FB.Wind1VelX);
% plot(Fast4d2_WndT2.FB.Time, Fast4d2_WndT2.FB.Wind1VelX);
% % plot(FBFF_R.Time,   FBFF_R.REWS_b);
% ylabel({'[m/s]';'Wind1VelX'});
% legend('WT 4 (binary)','WT 2 (ascii)','Interpreter','none','Location','best')
% 
% subplot(4,1,2);
% hold on; grid on; box on
% plot(Fast4d2_WndT4.FB.Time, Fast4d2_WndT4.FB.BldPitch1);
% plot(Fast4d2_WndT2.FB.Time, Fast4d2_WndT2.FB.BldPitch1);
% % plot(FBFF.Time,     FBFF.BldPitch1);
% ylabel({'BldPitch1'; '[deg]'});
% legend('WT 4 (binary)','WT 2 (ascii)','Interpreter','none','Location','best')
% 
% subplot(4,1,3);
% hold on; grid on; box on
% plot(Fast4d2_WndT4.FB.Time, Fast4d2_WndT4.FB.RotSpeed);
% plot(Fast4d2_WndT2.FB.Time, Fast4d2_WndT2.FB.RotSpeed);
% % plot(FBFF.Time,     FBFF.RotSpeed);
% ylabel({'RotSpeed';'[rpm]'});
% legend('WT 4 (binary)','WT 2 (ascii)','Interpreter','none','Location','best')
% 
% subplot(4,1,4);
% hold on; grid on; box on
% plot(Fast4d2_WndT4.FB.Time, Fast4d2_WndT4.FB.TwrBsMyt/1e3);
% plot(Fast4d2_WndT2.FB.Time, Fast4d2_WndT2.FB.TwrBsMyt/1e3);
% % plot(FBFF.Time,     FBFF.TwrBsMyt/1e3);
% ylabel({'TwrBsMyt';'[MNm]'});
% legend('WT 4 (binary)','WT 2 (ascii)','Interpreter','none','Location','best')

xlabel('time [s]')
linkaxes(findobj(gcf, 'Type', 'Axes'),'x');
% xlim([0 50])
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % Plot 
% figure('Name','Comparison FAST WT 4 vs 2, wind components')
% subplot(3,1,1);
% hold on; grid on; box on
% plot(Fast4d2_WndT4.FB.Time, Fast4d2_WndT4.FB.Wind1VelX);
% plot(Fast4d2_WndT2.FB.Time, Fast4d2_WndT2.FB.Wind1VelX);
% ylabel({'[m/s]';'Wind1VelX'});
% legend('WT 4 (binary)','WT 2 (ascii)','Interpreter','none','Location','best')
% 
% subplot(3,1,2);
% hold on; grid on; box on
% plot(Fast4d2_WndT4.FB.Time, Fast4d2_WndT4.FB.Wind1VelY);
% plot(Fast4d2_WndT2.FB.Time, Fast4d2_WndT2.FB.Wind1VelY);
% ylabel({'[m/s]';'Wind1VelY'});
% legend('WT 4 (binary)','WT 2 (ascii)','Interpreter','none','Location','best')
% 
% subplot(3,1,3);
% hold on; grid on; box on
% plot(Fast4d2_WndT4.FB.Time, Fast4d2_WndT4.FB.Wind1VelZ);
% plot(Fast4d2_WndT2.FB.Time, Fast4d2_WndT2.FB.Wind1VelZ);
% ylabel({'[m/s]';'Wind1VelZ'});
% legend('WT 4 (binary)','WT 2 (ascii)','Interpreter','none','Location','best')


%% Get steady state values

% average over last 3 revolutions
% Omega_end   = FB.RotSpeed(end)/60;          % [1/s]
% t_3Rev      = 3 * Omega_end^-1;             % [s]
% dt_FAST     = FB.Time(3)-FB.Time(2);        % [s]
% index_t     = round(t_3Rev/dt_FAST);        % [-]
% 
% SteadyStatesFAST.RotSpeed = mean(FB.RotSpeed((length(FB.RotSpeed)-index_t):end));
% SteadyStatesFAST.TTDspFA = mean(FB.TTDspFA((length(FB.TTDspFA)-index_t):end));
% SteadyStatesFAST.BldPitch1 = mean(FB.BldPitch1((length(FB.BldPitch1)-index_t):end));
% 
% fprintf("SteadyState RotSpeed: %.4f\n",SteadyStatesFAST.RotSpeed);
% fprintf("SteadyState TTDspFA: %.4f\n",SteadyStatesFAST.TTDspFA);
% fprintf("SteadyState BldPitch1: %.4f\n",SteadyStatesFAST.BldPitch1);
%% cost comparison
SgBaseCost = 0.931899858651808;
delta = (Cost - SgBaseCost);
deltaPercent = (delta / ((Cost+SgBaseCost)/2))*100;
fprintf("--------------------------------------------------\n");
fprintf("Current cost                        : %f\n", Cost);
fprintf("Delta in %% to reference cost  (0.849094) : %f %%\n", deltaPercent);
fprintf("Delta abs. to reference cost   (0.849094): %f\n", abs(delta));
%%
toc