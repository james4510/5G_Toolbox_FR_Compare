% == Create a wireless network simulator ==
rng("default");  % Reset the random number generator
numFrameSimulation = 20;  % Simulation time in terms of number of 10 ms frames
networkSimulator = wirelessNetworkSimulator.init;

% == Specify the positions of 3 gNBs and the gNB of interest for
% visualizing metrics == 
gNBPositions = [1700 600 30; 3000 600 30; 2500 2000 30];
gNBOfInterestIdx = 3;  % Specify an integer value in the range [1, number of gNBs]

% == Create the gNB Nodes by specifying their name, position, carrier
% frequency, channel bandwidth, subcarrier spacing, transmit power, and
% receive again.
gNBNames = "gNB-"+(1:size(gNBPositions,1));
gNBs = nrGNB(Name=gNBNames,Position=gNBPositions,CarrierFrequency=2.5e9,ChannelBandwidth=10e6, ...
    SubcarrierSpacing=30e3,TransmitPower=32,ReceiveGain=11,SRSPeriodicityUE=5);

% == Set the scheduler parameter ResourceAllocationType by using the
% configureScheduler function
for gNBIdx = 1:numel(gNBs)
    % Resource allocation type value 0 indicates a noncontiguous allocation
    % of frequency-domain resources in terms of RBGs
    configureScheduler(gNBs(gNBIdx),ResourceAllocationType=0)
end

% == Generate the positions of UE nodes in each cell
numCells = numel(gNBs);
cellRadius = 500;  % Radius of each cell (in meters)
numUEsPerCell = 4;
uePositions = generateUEPositions(cellRadius,gNBPositions,numUEsPerCell);

% == Create UE nodes and connect them to a gNB. Set the DL (Down Link)
% channel status information (CSI) report periodicity to 10 slots and
% configure full buffer traffic in the DL direction.
UEs = cell(numCells,1);
for cellIdx = 1:numCells
    ueNames = "UE-"+(1:size(uePositions{cellIdx},1));
    UEs{cellIdx} = nrUE(Name=ueNames,Position=uePositions{cellIdx},ReceiveGain=11);
    connectUE(gNBs(cellIdx),UEs{cellIdx},CSIReportPeriodicity=10,FullBufferTraffic="DL")
end

% == Add gNBs and UEs to the network simulator
addNodes(networkSimulator,gNBs);
for cellIdx = 1:numCells
    addNodes(networkSimulator,UEs{cellIdx})
end

% == Use 3GPP TR 38.901 channel model for all links
channelModel = "3GPP TR 38.901";

if strcmp(channelModel,"3GPP TR 38.901")
    % Define scenario boundaries
    pos = [reshape([gNBs.Position],3,[])];
    minX = min(pos(1,:));          % x-coordinate of the left edge of the scenario in meters
    minY = min(pos(2,:));          % y-coordinate of the bottom edge of the scenario in meters
    width = max(pos(1,:)) - minX;  % Width (right edge of the 2D scenario) in meters, given as maxX - minX
    height = max(pos(2,:)) - minY; % Height (top edge of the 2D scenario) in meters, given as maxY - minY
  
    % Create the channel model
    channel = h38901Channel(Scenario="UMa",ScenarioExtents=[minX minY width height]);
    % Add the channel model to the simulator
    addChannelModel(networkSimulator,@channel.channelFunction);
    connectNodes(channel,networkSimulator,InterfererHasSmallScale=true);
end

% == Get the cell ID for the gNB of interest
cellToAnalyze = gNBs(gNBOfInterestIdx).ID;

% == Set the enableTraces as true to log the traces
enableTraces = true;

% Create objects to log MAC and PHY traces
linkDir = 0; % Indicates DL
if enableTraces
    simSchedulingLogger = cell(numCells,1);
    simPhyLogger = cell(numCells,1);

    for cellIdx = 1:numCells
        % Create an object for MAC DL scheduling traces logging
        simSchedulingLogger{cellIdx} = helperNRSchedulingLogger(numFrameSimulation, ...
            gNBs(cellToAnalyze),UEs{cellToAnalyze},LinkDirection=linkDir);

        % Create an object for PHY layer traces logging
        simPhyLogger{cellIdx} = helperNRPhyLogger(numFrameSimulation,gNBs(cellToAnalyze), ...
            UEs{cellToAnalyze});
    end
end

% Set the number of updates per second for the metric plots
numMetricPlotUpdates = 100; % Updates plots every 10 ms

% Create an object for MAC and PHY metrics visualization
showSchedulerMetrics = true;
showPhyMetrics = true;
metricsVisualizer = helperNRMetricsVisualizer(gNBs(cellToAnalyze),UEs{cellToAnalyze}, ...
    CellOfInterest=cellToAnalyze,RefreshRate=numMetricPlotUpdates, ...
    PlotSchedulerMetrics=showSchedulerMetrics,PlotPhyMetrics=showPhyMetrics,LinkDirection=linkDir);

% Write the logs to MAT-files
simulationLogFile = "simulationLogs"; % For logging the simulation traces

% Add a mobility model to the UE node of interest in the cell of interest
enableMobility = false;
if enableMobility
    ueSpeedRange = [1 1000]; % In meters per second
    ueWithMobility = UEs{cellToAnalyze}(2); % Get UE-2 in the cell of interest
    % Add random waypoint mobility to the selected UE
    addMobility(ueWithMobility,SpeedRange=ueSpeedRange,BoundaryShape="circle",Bounds=[gNBs(cellToAnalyze).Position(1:2) cellRadius])
end

% Display the network topology
enableMobility = false;
if enableMobility
    ueSpeedRange = [1 1000]; % In meters per second
    ueWithMobility = UEs{cellToAnalyze}(2); % Get UE-2 in the cell of interest
    % Add random waypoint mobility to the selected UE
    addMobility(ueWithMobility,SpeedRange=ueSpeedRange,BoundaryShape="circle",Bounds=[gNBs(cellToAnalyze).Position(1:2) cellRadius])
end

% Run the simulation for the specified numFrameSimulation frames
% Calculate the simulation duration (in seconds)
simulationTime = numFrameSimulation*1e-2;
% Run the simulation
run(networkSimulator,simulationTime);

% Read per-node statistics
gNBStats = statistics(gNBs);
ueStats = cell(numCells, 1);
for cellIdx = 1:numCells
    ueStats{cellIdx} = statistics(UEs{cellIdx});
end

displayPerformanceIndicators(metricsVisualizer)

if enableTraces
    % Obtain the logs
    simulationLogs = cell(numCells, 1);
    for cellIdx = 1:numCells
        if gNBs(cellIdx).DuplexMode == "FDD"
            logInfo = struct(NCellID=[],DLTimeStepLogs=[], ...
                SchedulingAssignmentLogs=[],PhyReceptionLogs=[]);
            logInfo.DLTimeStepLogs = getSchedulingLogs(simSchedulingLogger{cellIdx});
        else % TDD
            logInfo = struct(NCellID=[],TimeStepLogs=[], ...
                SchedulingAssignmentLogs=[],PhyReceptionLogs=[]);
            logInfo.TimeStepLogs = getSchedulingLogs(simSchedulingLogger{cellIdx});
        end
        logInfo.NCellID = gNBs(cellIdx).ID;
        % Obtain the scheduling assignments log
        logInfo.SchedulingAssignmentLogs = getGrantLogs(simSchedulingLogger{cellIdx});
        % Obtain the Phy reception logs
        logInfo.PhyReceptionLogs = getReceptionLogs(simPhyLogger{cellIdx});
        simulationLogs{cellIdx} = logInfo;
    end
    % Save simulation logs in a MAT-file
    save(simulationLogFile,"simulationLogs")
end

function uePositions = generateUEPositions(cellRadius,gNBPositions,numUEsPerCell)
%generateUEPositions Return the position of UE nodes in each cell

numCells = size(gNBPositions,1);
uePositions = cell(numCells,1);
ueHeight = 3; % In meters
for cellIdx=1:numCells
    gnbXCo = gNBPositions(cellIdx,1); % gNB X-coordinate
    gnbYCo = gNBPositions(cellIdx,2); % gNB Y-coordinate
    theta = rand(numUEsPerCell,1)*(2*pi);
    % Use these expressions to calculate the position of UE nodes within the cell. By default,
    % the placement of the UE nodes is random within the cell
    r = sqrt(rand(numUEsPerCell,1))*cellRadius;
    x = round(gnbXCo + r.*cos(theta));
    y = round(gnbYCo + r.*sin(theta));
    z = ones(numUEsPerCell,1) * ueHeight;
    uePositions{cellIdx} = [x y z];
end
end