%% Compare two FAST sprint runs FB, FBFF

% load first set of results and assign name for legend
FastResult_A = load("results\Fast4d2SinglePoint_ROSCO2d6_InflowWt4.mat");
LegendEntry_A = "Wind Type 4";

% load first set of results and assign name for legend
FastResult_B = load("results\Fast4d2SinglePoint_ROSCO2d6_InflowWt2.mat");
LegendEntry_B = "Wind Type 2";

% Figure Names
FigureName_FB   = "wt4 vs wt2";
FigureName_FBFF = FigureName_FB;

LegendEntries = [LegendEntry_A LegendEntry_B];
%% Plot FB 
figure('Name',"Comparison FAST FB " + FigureName_FB)

subplot(4,1,1);
hold on; grid on; box on
plot(FastResult_A.FB.Time, FastResult_A.FB.Wind1VelX);
plot(FastResult_B.FB.Time, FastResult_B.FB.Wind1VelX);
% plot(FBFF_R.Time,   FBFF_R.REWS_b);
ylabel({'[m/s]';'Wind1VelX'});
legend(LegendEntries,'Interpreter','none','Location','best')

subplot(4,1,2);
hold on; grid on; box on
plot(FastResult_A.FB.Time, FastResult_A.FB.BldPitch1);
plot(FastResult_B.FB.Time, FastResult_B.FB.BldPitch1);
% plot(FBFF.Time,     FBFF.BldPitch1);
ylabel({'BldPitch1'; '[deg]'});
legend(LegendEntries,'Interpreter','none','Location','best')

subplot(4,1,3);
hold on; grid on; box on
plot(FastResult_A.FB.Time, FastResult_A.FB.RotSpeed);
plot(FastResult_B.FB.Time, FastResult_B.FB.RotSpeed);
% plot(FBFF.Time,     FBFF.RotSpeed);
ylabel({'RotSpeed';'[rpm]'});
legend(LegendEntries,'Interpreter','none','Location','best')

subplot(4,1,4);
hold on; grid on; box on
plot(FastResult_A.FB.Time, FastResult_A.FB.TwrBsMyt/1e3);
plot(FastResult_B.FB.Time, FastResult_B.FB.TwrBsMyt/1e3);
% plot(FBFF.Time,     FBFF.TwrBsMyt/1e3);
ylabel({'TwrBsMyt';'[MNm]'});
legend(LegendEntries,'Interpreter','none','Location','best')

xlabel('time [s]')
linkaxes(findobj(gcf, 'Type', 'Axes'),'x');
% xlim([0 30])

%% Plot FBFF 
figure('Name',"Comparison FAST FBFF " + FigureName_FB)

subplot(4,1,1);
hold on; grid on; box on
plot(FastResult_A.FBFF.Time, FastResult_A.FBFF.Wind1VelX);
plot(FastResult_B.FBFF.Time, FastResult_B.FBFF.Wind1VelX);
% plot(FBFF_R.Time,   FBFF_R.REWS_b);
ylabel({'[m/s]';'Wind1VelX'});
legend(LegendEntries,'Interpreter','none','Location','best')

subplot(4,1,2);
hold on; grid on; box on
plot(FastResult_A.FBFF.Time, FastResult_A.FBFF.BldPitch1);
plot(FastResult_B.FBFF.Time, FastResult_B.FBFF.BldPitch1);
% plot(FBFF.Time,     FBFF.BldPitch1);
ylabel({'BldPitch1'; '[deg]'});
legend(LegendEntries,'Interpreter','none','Location','best')

subplot(4,1,3);
hold on; grid on; box on
plot(FastResult_A.FBFF.Time, FastResult_A.FBFF.RotSpeed);
plot(FastResult_B.FBFF.Time, FastResult_B.FBFF.RotSpeed);
% plot(FBFF.Time,     FBFF.RotSpeed);
ylabel({'RotSpeed';'[rpm]'});
legend(LegendEntries,'Interpreter','none','Location','best')

subplot(4,1,4);
hold on; grid on; box on
plot(FastResult_A.FBFF.Time, FastResult_A.FBFF.TwrBsMyt/1e3);
plot(FastResult_B.FBFF.Time, FastResult_B.FBFF.TwrBsMyt/1e3);
% plot(FBFF.Time,     FBFF.TwrBsMyt/1e3);
ylabel({'TwrBsMyt';'[MNm]'});
legend(LegendEntries,'Interpreter','none','Location','best')

xlabel('time [s]')
linkaxes(findobj(gcf, 'Type', 'Axes'),'x');
% xlim([0 30])

%% Rotor averaged wind velocity
figure('Name',"Comparison FAST FB " + FigureName_FB)

subplot(4,1,1);
hold on; grid on; box on
plot(FastResult_A.FB.Time, FastResult_A.FB.Wind1VelX);
plot(FastResult_B.FB.Time, FastResult_B.FB.Wind1VelX);
% plot(FBFF_R.Time,   FBFF_R.REWS_b);
ylabel({'[m/s]';'Wind1VelX'});
legend(LegendEntries,'Interpreter','none','Location','best')

subplot(4,1,2);
hold on; grid on; box on
plot(FastResult_A.FB.Time, FastResult_A.FB.BldPitch1);
plot(FastResult_B.FB.Time, FastResult_B.FB.BldPitch1);
% plot(FBFF.Time,     FBFF.BldPitch1);
ylabel({'BldPitch1'; '[deg]'});
legend(LegendEntries,'Interpreter','none','Location','best')

subplot(4,1,3);
hold on; grid on; box on
plot(FastResult_A.FB.Time, FastResult_A.FB.RotSpeed);
plot(FastResult_B.FB.Time, FastResult_B.FB.RotSpeed);
% plot(FBFF.Time,     FBFF.RotSpeed);
ylabel({'RotSpeed';'[rpm]'});
legend(LegendEntries,'Interpreter','none','Location','best')

subplot(4,1,4);
hold on; grid on; box on
plot(FastResult_A.FB.Time, FastResult_A.FB.RtVAvgxh);
plot(FastResult_B.FB.Time, FastResult_B.FB.RtVAvgxh);
% plot(FBFF.Time,     FBFF.TwrBsMyt/1e3);
ylabel({'RtVAvgxh';'[m/s]'});
legend(LegendEntries,'Interpreter','none','Location','best')

xlabel('time [s]')
linkaxes(findobj(gcf, 'Type', 'Axes'),'x');
% xlim([0 30])