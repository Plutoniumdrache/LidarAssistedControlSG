function [DataFiles,PostProcessingConfig] = SimDataMLSequenceConfig
% Function to set up the simulation of the Online Brute Force Algorithm
% paths needed
addpath(genpath('methods'))
addpath(genpath('functions'))
addpath(genpath(fullfile("SpectraReconstruction", "MM92_SLOW")))
addpath(genpath(fullfile("SpectraReconstruction", "Tools")))

% DataFiles
Seeds           = [101:200]';             % number of seeds to be computed. Can not be more then rsult files
SeedsStr        = num2str(Seeds,'%03d');
WindSpeeds      = [12:24]';
Alphas          = [0.0, 0.1]';

DataFiles = {};
% Select input folder
for iWindSpeed = 1:length(WindSpeeds)
    for iAlpha = 1:length(Alphas)
        fn          = fullfile("WindInput", "MolasConfig_x_064_alpha_("+num2str(Alphas(iAlpha),'%.1f')+" )_URef_("+num2str(WindSpeeds(iWindSpeed))+" )_results", "InputTS_Seed_");
        tmpDataFiles   = cellstr(fn+SeedsStr+".mat");
        DataFiles = [DataFiles; tmpDataFiles];
    end
end

% CollectTimeResults
TMax                = 2047.9;                  % [s]       total run time
DT                  = 0.1;                     % [s]       time step
time                = [0:DT:TMax]';            % [s]       time vector


% AddDerivedTimeResults
% setup WT Slow Simulation
WT_Parameter = DefaultParameterMM92_SLOW;
WT_Parameter = DefaultParameterMM92_SimplifiedServos(WT_Parameter);

% setup OnlineBF
% Parameter =        ParameterMethodMLtoTS('M0001');
Parameter.tau =    0.3;    % [s]
tokensURef =            regexp(DataFiles{1},'_URef_\(([^)]+)\)','tokens');
Parameter.URef =   str2num(string(tokensURef{1}));
tokensAlpha =           regexp(DataFiles{1},'_alpha_\(([^)]+)\)','tokens');
Parameter.alpha =  str2num(string(tokensAlpha{1}));
PostProcessingConfig.URef = Parameter.URef;
PostProcessingConfig.tau = Parameter.tau;
Parameter.method = 'dummy';

PostProcessingConfig.AddDerivedTimeResults = {
    % apply lidar data processing from summer games
    @(TimeResults) ApplyLDP_vGrayBox(TimeResults,Parameter,WT_Parameter,ResetAfterEachFile=true); % reset, since independent files
    % calculate Error
    @(TimeResults) ApplyFunctionToTwoChannels(TimeResults,'v_0L_fb','v_0_s',...
        @(Time,Data1,Data2) Data2-Data1 ,'Error')   
        };

% PlotTimeResults
% ---
ID = 1; 
PostProcessingConfig.Plots.ComparisonTimePlot{ID}.Enable    = 0;
PostProcessingConfig.Plots.ComparisonTimePlot{ID}.Channels  = {'v_0_s';'v_0L';'v_0L_fb'};
PostProcessingConfig.Plots.ComparisonTimePlot{ID}.IndicesConsideredDataFiles  = round(linspace(1,Seeds(end),5));
% ---
ID = 2; 
PostProcessingConfig.Plots.ComparisonTimePlot{ID}.Enable    = 0;
PostProcessingConfig.Plots.ComparisonTimePlot{ID}.Channels  = {'REWS_b';'REWS_WindField'};   
% ---
ID = 2; 
PostProcessingConfig.Plots.ComparisonTimePlot{ID}.Enable    = 0;
PostProcessingConfig.Plots.ComparisonTimePlot{ID}.Channels  = {'Error'};
PostProcessingConfig.Plots.ComparisonTimePlot{ID}.IndicesConsideredDataFiles  = round(linspace(1,Seeds(end),5));
% CalculateStatistics
t_start             = 0;                       % [s] 	    ignore data before for STD and spectra
PostProcessingConfig.CalculateStatistics = {
    % 'MeanAbsDetrend' @(Data,Time) mean(abs(detrend(Data(Time>=t_start),'constant')))  {'Error'}
    'MeanStd' @(Data,Time) mean(std(Data(Time>=t_start)))+abs(mean(Data(Time>=t_start)))  {'Error'};
    'Std' @(Data,Time) std(Data(Time>=t_start)) {'Omega_FF'};
    'Std' @(Data,Time) std(Data(Time>=t_start)) {'Omega_FB'};
    'Std' @(Data,Time) std(Data(Time>=t_start)) {'M_yT_FF'};
    'Std' @(Data,Time) std(Data(Time>=t_start)) {'M_yT_FB'}
    };

% PlotStatistics
% ---
ID = 1;
PostProcessingConfig.Plots.BasicStatisticsPlot{ID}.Enable       = 0;
PostProcessingConfig.Plots.BasicStatisticsPlot{ID}.Variables    = {'MeanStd_Error'};
PostProcessingConfig.Plots.BasicStatisticsPlot{ID}.x            = Seeds'; 
PostProcessingConfig.Plots.BasicStatisticsPlot{ID}.gca.LineStyleOrder   = 'o-';
PostProcessingConfig.Plots.BasicStatisticsPlot{ID}.xlabel       = 'seed [-]';
PostProcessingConfig.Plots.BasicStatisticsPlot{ID}.ylabel       = 'mean std error [m/s]';

% CalculateProcessResults
PostProcessingConfig.CalculateProcessResults = {
    @(ProcessResults,FrequencyResults,Statistics) setfield(ProcessResults,'Cost',mean(Statistics.MeanStd_Error));
    @(ProcessResults,FrequencyResults,Statistics) setfield(ProcessResults,'MeanStdOmega',mean((Statistics.Std_Omega_FF ./ Statistics.Std_Omega_FB ))-1);
    @(ProcessResults,FrequencyResults,Statistics) setfield(ProcessResults,'MeanStdM_yT',mean((Statistics.Std_M_yT_FF ./  Statistics.Std_M_yT_FB ))-1)
    };

% Save Results
% Generate file name
SaveFileHead = 'MLtoTS_alpha_(';              % Adjust for each method !!! TO DO: Automate to select the used Algorithm
SaveFileAlpha = sprintf('%.1f %.1f',Parameter.alpha);
SaveFileMid = ')_URef_(';
SaveFileWind = sprintf('%d %d',Parameter.URef);
SaveFileEnd = ')_results.mat';
PostProcessingConfig.SaveResults.FileName = append(SaveFileHead,SaveFileAlpha,SaveFileMid,SaveFileWind,SaveFileEnd);
PostProcessingConfig.SaveResults.FolderName = 'PostProcessingResults_Simulations'; % TO DO: use cases for simulation and real data result folders
PostProcessingConfig.SaveResults.SaveFlag = true;       % Flag to save/not save
end

