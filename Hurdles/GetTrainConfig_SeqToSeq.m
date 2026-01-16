function config = GetTrainConfig_SeqToSeq()
% files
% config.filepath = fullfile("TempREWS","M_PredictDataTS_norm.mat");
% config.Xname = "X";
% config.Yf_name = "Yf";
% config.YT_name = "YT";
% config.DataFiles = "DataFiles";
% config.normsetX = "normsetX";
% config.normsetYf = "normsetYf";
% config.normsetYT = "normsetYT";
%% WindowSize
config.WindowSize = 8; % [s]
% [s] % 1;2;3;4;5;6;8;10;12;15;20;24;25;
                        % 30;40;50;60;75;100;120;150;200;300;600)
                        % measurements only
% 1;2;4;8;16;32;64;128;256;512;1024 (for simulation only)
%% architecture
config.numFeatures = 1; % input dimension (only REWS = 1; Temp. & REWS = 2) 
config.numResponses = 1; % output mapping per LSTM layer
config.numHiddenUnits = 10; 
config.numHiddenUnits2 = 10;
config.dropoutRate = 0.2;


config.layers = [
    sequenceInputLayer(config.numFeatures,Name="input")

    % Optional: try with or without convolution layer
    convolution1dLayer(5, 32, Padding="same") % larger filter & more channels
    reluLayer

    lstmLayer(config.numHiddenUnits, OutputMode="sequence", Name="lstm1")
    dropoutLayer(config.dropoutRate, Name="drop1")

    lstmLayer(config.numHiddenUnits2, OutputMode="sequence", Name="lstm2")
    dropoutLayer(config.dropoutRate, Name="drop2")
    
    fullyConnectedLayer(config.numResponses,Name="fc")
];
%% Training options
config.MaxEpochs = 100;
config.InitialLearnRate = 0.001;
config.LossFcn = "mse";
config.ValFreq = 50;
config.ValPatience = 5;
config.SequenceLength = "longest";
config.Metrics = "rmse";
config.optimizer = "adam";
config.Shuffle = "every-epoch";
% save options
config.ID = "M5000";
end