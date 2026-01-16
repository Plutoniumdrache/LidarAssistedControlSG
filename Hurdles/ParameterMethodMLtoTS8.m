% ========================================================================
% File Name: ParameterMethodMLtoTS8.m
% Author: Julius Preuschoff
% Date Created: 14.10-2025
% Last Modified: 14.10-2025
% Version: 1.0
%
% Description:
%   Briefly describe what this script/function does.
%   Mention the context or problem it solves.
% Revision History:
%   14.10-2025 - created MLtoTS8 from MLtoTS4
%   05-Sep-2025 - Initial version (JP)
%
% ========================================================================
function MethodParameters = ParameterMethodMLtoTS8(ID)
%ParameterMethodMLtoTS3 Parameter function for method 'MLtoTS3'
%   Loading of all necessary parameters.

WindowSize = 8; % [s]
dt = 0.1;
n_Window = WindowSize/dt;
normsetX = [];
normsetT = [];
switch ID
    case '20250905_1633_netSeq_TI'
        filename = "20250905_1633_netSeq_TI";
        vars = {"net","normsetX", "normsetT"};
        s = load(filename + ".mat", vars{:});
        MethodHandle = s.net;
        channels = cellstr('v_0L'); % necessary if only one element
        normsetX = s.normsetX;
        normsetT = s.normsetT;
   case 'atest_netSeq'
        filename = "atest_netSeq";
        vars = {"net","normsetX", "normsetT"};
        s = load(filename + ".mat", vars{:});
        MethodHandle = s.net;
        channels = cellstr('v_0L'); % necessary if only one element
        normsetX = s.normsetX;
        normsetT = s.normsetT;
   case '20251014_1340_netSeq'
        filename = "20251014_1340_netSeq";
        vars = {"net","normsetX", "normsetT"};
        s = load(filename + ".mat", vars{:});
        MethodHandle = s.net;
        channels = cellstr('v_0L'); % necessary if only one element
        normsetX = s.normsetX;
        normsetT = s.normsetT;
    otherwise
        error("No method with this ID found.");
end

MethodParameters = struct( ...
    'MethodHandle', MethodHandle, ...
    'WindowSize', WindowSize, ...
    'n_Window', n_Window, ...
    'dt', dt, ...
    'channels',channels, ...
    'normsetX', normsetX, ...
    'normsetT',normsetT, ...
    'ID',ID);
end