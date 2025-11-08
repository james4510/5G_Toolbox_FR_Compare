fc = 28e9;                             % carrier frequency (Hz)
reflectionsOrder = 1;                 % number of reflections for ray tracing analysis (0 for LOS)
 
% Bandwidth configuration
SCS = 15; % subcarrier spacing
NRB = 52; % number of resource blocks, 10 MHz bandwidth

if exist('viewer','var') && isvalid(viewer)
    clearMap(viewer);
else
    viewer = siteviewer("Basemap","openstreetmap","Buildings","seongnam.osm");    
end

% ============== [BS Configuration] ==============
bsPosition = [37.4554 127.1337];
bsAntSize = [4 4];
bsArrayOrientation = [90 0].';

bsSite = txsite("Name","Base station", ...
    "Latitude",bsPosition(1),"Longitude",bsPosition(2), ...
    "AntennaAngle",bsArrayOrientation(1:2), ...
    "AntennaHeight",4, ...
    "TransmitterFrequency",fc);

show(bsSite);

% ============== [Multiple UE Configuration] ==============
uePositions = [
    37.4555 127.1338;   % UE1
    37.4556 127.1339    % UE2
];
ueAntSize = [2 2];
ueArrayOrientation = [-30 45].';

numUEs = size(uePositions,1);
ueSites = cell(1,numUEs);

for i = 1:numUEs
    ueSites{i} = rxsite("Name",sprintf("UE%d",i), ...
        "Latitude",uePositions(i,1),"Longitude",uePositions(i,2), ...
        "AntennaHeight",1, ...
        "AntennaAngle",ueArrayOrientation(1:2));
    show(ueSites{i});
end

% ============== [Ray Tracing Model] ==============
pm = propagationModel("raytracing","Method","sbr", ...
    "MaxNumReflections",reflectionsOrder,"MaxNumDiffractions",0);

c = physconst('LightSpeed');
lambda = c/fc;

% ============== [Base Station Antenna Array] ==============
bsArray = phased.NRRectangularPanelArray( ...
    'Size',[bsAntSize(1:2) 1 1], ...
    'Spacing',[0.5*lambda*[1 1] 1 1]);
bsArray.ElementSet = {phased.NRAntennaElement};

ofdmInfo = nrOFDMInfo(NRB,SCS);

% ============== [Loop Over UEs] ==============
for i = 1:numUEs
    fprintf("\n===== Processing UE%d =====\n", i);
    
    rays = raytrace(bsSite, ueSites{i}, pm, "Type","pathloss");
    plot(rays{1});
    
    pathToAs = [rays{1}.PropagationDelay] - min([rays{1}.PropagationDelay]);
    avgPathGains = -[rays{1}.PathLoss];
    pathAoDs = [rays{1}.AngleOfDeparture];
    pathAoAs = [rays{1}.AngleOfArrival];
    isLOS = any([rays{1}.LineOfSight]);
    
    % ============== [CDL Channel Configuration] ==============
    channel = nrCDLChannel;
    channel.DelayProfile = 'Custom';
    channel.PathDelays = pathToAs;
    channel.AveragePathGains = avgPathGains;
    channel.AnglesAoD = pathAoDs(1,:);
    channel.AnglesZoD = 90 - pathAoDs(2,:);
    channel.AnglesAoA = pathAoAs(1,:);
    channel.AnglesZoA = 90 - pathAoAs(2,:);
    channel.HasLOSCluster = isLOS;
    channel.CarrierFrequency = fc;
    channel.NormalizeChannelOutputs = false;
    channel.NormalizePathGains = false;
    channel.SampleRate = ofdmInfo.SampleRate;
    channel.ChannelFiltering = false;

    % UE Array
    ueArray = phased.NRRectangularPanelArray( ...
        'Size',[ueAntSize(1:2) 1 1], ...
        'Spacing',[0.5*lambda*[1 1] 1 1]);
    ueArray.ElementSet = {phased.IsotropicAntennaElement};
    
    channel.ReceiveAntennaArray = ueArray;
    channel.ReceiveArrayOrientation = [ueArrayOrientation(1); (-1)*ueArrayOrientation(2); 0];
    channel.TransmitAntennaArray = bsArray;
    channel.TransmitArrayOrientation = [bsArrayOrientation(1); (-1)*bsArrayOrientation(2); 0];
    
    % ============== [Channel Simulation] ==============
    [pathGains,sampleTimes] = channel();
    
    pg = permute(pathGains,[2 1 3 4]);
    if isLOS
        pg = [sum(pg(1:2,:,:,:)); pg(3:end,:,:,:)];
    end
    pg = abs(pg).^2;
    
    figure;
    plot(pow2db(pg(:,1,1,1)),'o-.'); hold on;
    plot(avgPathGains,'x-.'); hold off;
    legend("Instantaneous","Average (Ray Tracing)");
    xlabel("Path number"); ylabel("Gain (dB)");
    title(sprintf("UE%d Path Gains",i));
    
    % ============== [Channel Estimation] ==============
    pathFilters = getPathFilters(channel);
    nSlot = 0;
    [offset,~] = nrPerfectTimingEstimate(pathGains,pathFilters);
    hest = nrPerfectChannelEstimate(pathGains,pathFilters,NRB,SCS,nSlot,offset,sampleTimes);
    
    figure;
    surf(pow2db(abs(hest(:,:,1,1)).^2));
    shading('flat');
    xlabel('OFDM Symbols'); ylabel('Subcarriers'); zlabel('Magnitude Squared (dB)');
    title(sprintf('UE%d Channel Magnitude Response', i));
    
    % ============== [Beamforming Weights] ==============
    nLayers = 1; scOffset = 0; noRBs = 1;
    [wbs,wue,~] = getBeamformingWeights(hest,nLayers,scOffset,noRBs);
    
    % Plot UE radiation pattern
    ueSites{i}.Antenna = clone(channel.ReceiveAntennaArray);
    ueSites{i}.Antenna.Taper = wue;
    pattern(ueSites{i},fc,"Size",4);
    
    % Plot BS radiation pattern
    bsSite.Antenna = clone(channel.TransmitAntennaArray);
    bsSite.Antenna.Taper = wbs;
    pattern(bsSite,fc,"Size",5);
end


% ============== [Function: Beamforming Weights] ==============
function [wtx,wrx,D] = getBeamformingWeights(hEst,nLayers,scOffset,noRBs)
[~,~,R,P] = size(hEst);
scNo = scOffset+1;
hEst = hEst(scNo:scNo+(12*noRBs-1),:,:,:);
H = permute(mean(reshape(hEst,[],R,P)),[2 3 1]);
[U,D,V] = svd(H);
wtx = V(:,1:nLayers).';
wrx = U(:,1:nLayers)';
end