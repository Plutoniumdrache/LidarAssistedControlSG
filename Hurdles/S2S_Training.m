clearvars;close all;clc;

% select LidarType
LidarType           = '4BeamPulsed'; % [4BeamPulsed/CircularCW]

% Seeds (can be adjusted, but will provide different results)
nSeed               = 7:30;                     % [-]	    number of stochastic turbulence field samples
Seed_vec            = [nSeed(1):nSeed(end)]+18*100;         % [-]  	    vector of seeds

% Parameters postprocessing (can be adjusted, but will provide different results)
t_start             = 60;                       % [s] 	    ignore data before for STD and spectra
TMax                = 660;                      % [s]       total run time
DT                  = 0.01;                     % [s]       time step
time                = [0:DT:TMax]';             % [s]       time vector

% Parameter for Cost (Summer Games 2025)
tau                 = 2;                        % [s]       time to overcome pitch actuator, from Example 1: tau = T_Taylor - T_buffer, since there T_filter = T_scan = 0

switch LidarType
    case '4BeamPulsed'
        % configuration from LDP_v1_4BeamPulsed.IN and FFP_v1_4BeamPulsed.IN
        LDP.NumberOfBeams       = 4;            % [-]       Number of beams measuring at different directions               
        LDP.AngleToCenterline   = 19.176;       % [deg]     Angle around centerline
        LDP.IndexGate           = 6;            % [-]       IndexGate
        LDP.FlagLPF             = 1;            % [0/1]     Enable low-pass filter (flag)
        LDP.omega_cutoff        = 0.13;         % [rad/s]   Corner frequency (-3dB) of the low-pass filter
        LDP.T_buffer            = 0.2;          % [s]       Buffer time for filtered REWS signal
    case 'CircularCW'
        % configuration from LDP_v1_CircularCW.IN and FFP_v1_CircularCW.IN
        LDP.NumberOfBeams       = 50;           % [-]       Number of beams measuring at different directions               
        LDP.AngleToCenterline   = 15;           % [deg]     Angle around centerline
        LDP.IndexGate           = 1;            % [-]       IndexGate
        LDP.FlagLPF             = 1;            % [0/1]     Enable low-pass filter (flag)
        LDP.omega_cutoff        = 0.20;         % [rad/s]   Corner frequency (-3dB) of the low-pass filter
        LDP.T_buffer            = 4.2;          % [s]       Buffer time for filtered REWS signal        
end

% Files (should not be be changed)
SimulationFolderLAC     = 'solis_lidar_data';

%% Load Training Data

SolisData_DT            = 0.25; % [s]
nDataFiles              = length(nSeed);    
Store_Seed                    = NaN(1,nDataFiles);
Store_WindFileName            = NaN(1,nDataFiles);
Store_SolisResultFile         = NaN(1,nDataFiles);
% Store_SolisData               = NaN(TMax/SolisData_DT,nDataFiles);
Store_beamID                  = NaN(length(time),nDataFiles);
Store_isValid                 = NaN(length(time),nDataFiles);
Store_lineOfSightWindSpeed    = NaN(length(time),nDataFiles);
Store_RewsFile                = NaN(1,nDataFiles);
Store_REWS_WindField          = NaN(length(time),nDataFiles);
Store_REWS_WindField_shifted  = NaN(length(time),nDataFiles);

% Loop over all seeds
for iSeed = 1:length(nSeed)
    % Load data
    Seed                 = Seed_vec(iSeed);
	WindFileName         = ['URef_18_Seed_',num2str(Seed,'%02d')];
    SolisResultFile      = fullfile(SimulationFolderLAC,[WindFileName,'_lidar_data_',LidarType,'.csv']);
    SolisData            = readtable(SolisResultFile);    
    beamID               = interp1(SolisData.time,SolisData.beamID,time,'previous','extrap');
    isValid              = interp1(SolisData.time,SolisData.("isValid"+LDP.IndexGate),time,'previous','extrap');
    lineOfSightWindSpeed = interp1(SolisData.time,SolisData.("lineOfSightWindSpeed"+LDP.IndexGate),time,'previous','extrap');

    % Get REWS from the wind field 
    RewsFile                = ['TurbulentWind\URef_18_Seed_',num2str(Seed,'%02d'),'.csv'];  
    RewsData                = readtable(RewsFile);
    REWS_WindField          = interp1([RewsData.time;RewsData.time+600],[RewsData.REWS;RewsData.REWS],time); % REWS is circular 
    REWS_WindField_shifted  = interp1([RewsData.time;RewsData.time+600],[RewsData.REWS;RewsData.REWS],time+tau);

    Store_Seed(iSeed)                       = Seed;                
    Store_WindFileName(iSeed)               = string(WindFileName);   
    Store_SolisResultFile(iSeed)            = string(SolisResultFile);     
    % Store_SolisData(:,iSeed)                = SolisData;           
    Store_beamID(:,iSeed)                   = beamID;              
    Store_isValid(:,iSeed)                  = isValid;             
    Store_lineOfSightWindSpeed(:,iSeed)     = lineOfSightWindSpeed;
    
    Store_RewsFile(iSeed)                   = string(RewsFile);
    Store_REWS_WindField(:,iSeed)           = REWS_WindField;    
    Store_REWS_WindField_shifted(:,iSeed)   = REWS_WindField_shifted;
end

%% Prep Training Data

% Shorten weird time series length for training
Store_beamID(2,:)                   = [];
Store_isValid(2,:)                  = [];
Store_lineOfSightWindSpeed(2,:)     = [];
Store_REWS_WindField_shifted(2,:)   = [];

X_beamID                    = Store_beamID;
X_isValid                   = Store_isValid;
X_lineOfSightWindSpeed      = Store_lineOfSightWindSpeed;
T_REWS_WindField_shifted    = Store_REWS_WindField_shifted;

[Xnorm, normsetX] = normalizeData(reshape(X_lineOfSightWindSpeed,1,[]));
[Tnorm, normsetT] = normalizeData(reshape(T_REWS_WindField_shifted,1,[]));

% Determine windowsize
[cols,rows] = size(X_lineOfSightWindSpeed);
nWindow = 660;

X = reshape(Xnorm,nWindow,[]);
T = reshape(Tnorm,nWindow,[]);


%% get training setup
config = GetTrainConfig_SeqToSeq();

%% Run Training
TrainSeqToSeq_config