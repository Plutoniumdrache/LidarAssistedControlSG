%% REWS Forecasting with LSTM Network
% training on simulation and measurement data
% Multi output, mapping cut-off frequency and buffer time

numFeatures  = config.numFeatures;        % Example: 1 main parameter + 1 extra parameter
numSequences = size(X,2);      % Number of sequences in dataset
%% Prepare input and target sequences
dsXTrain = arrayDatastore(X, 'IterationDimension', 2);
dsT = arrayDatastore(T, 'IterationDimension', 2);
ds = combine(dsXTrain, dsT);
dsrand = shuffle(ds);

%Load Sequence Data
numObservations = numSequences;
numResponses = config.numResponses; % output mapping

% split into training and validation data set
idx = 1:numObservations;
nTrain = round(0.85 * numObservations);
nVal   = numObservations - nTrain; 

idxTrain = idx(1:nTrain);
idxVal   = idx(nTrain+1 : nTrain+nVal);

dsTrain = subset(dsrand, idxTrain);
dsVal   = subset(dsrand, idxVal);

% create template network
net = dlnetwork;
%% Define LSTM network
net = addLayers(net,config.layers);
% show graph of model
% figure
% plot(net)
%% add options
config.options = trainingOptions(config.optimizer, ...
    MaxEpochs = config.MaxEpochs, ...
    ValidationData = dsVal, ...
    ValidationFrequency = config.ValFreq, ...
    ValidationPatience = config.ValPatience, ...
    InitialLearnRate = config.InitialLearnRate, ...
    SequenceLength = config.SequenceLength, ...
    Metrics = config.Metrics, ...
    Shuffle=config.Shuffle, ...
    Plots="training-progress", ...
    Verbose=false);
%% Train the LSTM
[net, TrainInfo] = trainnet(dsTrain,net,config.LossFcn,config.options);

%% save trained model for later
WindowSize = config.WindowSize;
testflag = 1;
if testflag
    timestr = "atest";
    % save everything
    filename = fullfile("models", timestr + "_netSeq_TI");
    save(filename, "net", "config", "TrainInfo", ...
    "normsetX", "normsetT", "WindowSize","-v7.3");
    
    % save without training info and options to save disk space
    filename = fullfile("models", timestr + "_netSeq");
    save(filename, "net", "config", ...
        "normsetX", "normsetT", "WindowSize","-v7.3");
else
    % save everything
    timestr = string(datetime('now', 'Format','yyyyMMdd_HHmm'));
    filename = fullfile("models", timestr + "_netSeq_TI");
    save(filename, "net", "config", "TrainInfo", "DataFiles", ...
    "normsetX", "normsetT", "WindowSize","-v7.3");
    
    % save without training info and options to save disk space
    filename = fullfile("models", timestr + "_netSeq");
    save(filename, "net", "config","DataFiles", ...
        "normsetX", "normsetT", "WindowSize","-v7.3");
end



