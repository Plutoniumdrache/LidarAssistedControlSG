% ========================================================================
% File Name: ApplyMethodMLtoTS8.m
% Author: Julius Preuschoff
% Date Created: 14-10-2025
% Last Modified: 14-10-2025
% Version: 1.0
%
% Description:
%   Script to apply ML model to simulation data as SequenceToSequence
%   analysis a Filter is hereby no longer necessary
%   network state is kept over iterations
% Revision History:
%   14.10.2025 Updated Version of MLtoTS4 similar to MLtoTS6 with chunkwise future
%   predcition (JP)
%   05-Sep-2025 - Initial version (JP)
%
% ========================================================================
function [v_0L_fb] = ApplyMethodMLtoTS8(lineOfSightWindSpeed,MethodParameters)
%ApplyMethodMLtoTS Applying the method 'ApplyMethodMLtoTS'
%   Detailed explanation goes here

% load Parameters
normsetX = MethodParameters.normsetX;
normsetT = MethodParameters.normsetT;

% load wind data
v_0L = lineOfSightWindSpeed;

% function handle for network
fun = MethodParameters.MethodHandle;

chunkSize = 1200;  % number of timesteps per batch
nSteps = length(v_0L);
output = NaN(size(v_0L));

fun = resetState(fun); % reset network

for i = 1:chunkSize:nSteps
    idx = i:min(i+chunkSize-1, nSteps);
    xChunkNorm = v_0L(idx)';

    % Normalize
    xChunkNorm = normalizeData(xChunkNorm, normsetX)';
    xChunkNorm = xChunkNorm(:);   % features × time

    % Predict all timesteps in chunk
    [yPred, state] = predict(fun, xChunkNorm);
    fun.State = state;

    % De-normalize
    output(idx) = dnormalizeData(yPred, normsetT);
end

v_0L_fb = output; % return back predicted REWS

end
