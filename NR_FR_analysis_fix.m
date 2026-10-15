clear; clc; close all;

fr1 = 4.7e9;                           % carrier frequency (Hz) - FR1(4.7 GHz)
fr2 = 28e9;                            % carrier frequency (Hz) - FR2(28 GHz)
bsPosition1 = [37.455715, 127.133562]; % BS1(Tx1) - Gachon University
bsPosition2 = [37.4528, 127.1139];     % BS2(Tx2) - Seoul Airport
bsArrayOrientation1 = [-30 0].';       % azimuth (0 deg is East, 90 deg is North) and elevation (positive points upwards) in deg
bsArrayOrientation2 = [-30 0].';       % azimuth and elevation for BS2
uePosition1 = [37.4552 127.1334];
uePosition2 = [37.4537 127.1122];
ueAntSize=[2 2];
ueArrayOrientation=[180 45].';
reflectionOrder=1;

% Bandwidth configuration, required to set the channel sampling rate and
% for perfect channel estimation
SCS = 15; % subcarrier spacing
NRB = 52; % number of resource blocks, 10 MHz bandwidth

if exist('viewer','var') && isvalid(viewer) % viewer handle exists and viewer window is open
    clearMap(viewer);
else
    viewer = siteviewer("Basemap","openstreetmap","Buildings","_seongnam_map.osm");
end

bsSite1 = txsite("Name","BS1 - Gachon Univ(NLoS+LoS)",...
    "Latitude",bsPosition1(1), "Longitude", bsPosition1(2), ...
    "AntennaAngle",bsArrayOrientation1(1:2), ...
    "AntennaHeight",30, ...% in m
    "TransmitterFrequency",fr1);

bsSite2 = txsite("Name","BS2 - Seoul Airport(LoS)",...
    "Latitude",bsPosition2(1), "Longitude", bsPosition2(2), ...
    "AntennaAngle",bsArrayOrientation2(1:2), ...
    "AntennaHeight",30, ...% in m
    "TransmitterFrequency",fr1);

ueSite1 = rxsite("Name","UE1", ...
    "Latitude",uePosition1(1),"Longitude",uePosition1(2),...
    "AntennaHeight",1,...
    "AntennaAngle",ueArrayOrientation(1:2));

ueSite2 = rxsite("Name","UE2", ...
    "Latitude",uePosition2(1),"Longitude",uePosition2(2),...
    "AntennaHeight",1,...
    "AntennaAngle",ueArrayOrientation(1:2));

show(bsSite1); show(bsSite2);
show(ueSite1); show(ueSite2);

pm = propagationModel("raytracing","Method","sbr","MaxNumReflections",reflectionOrder,"MaxNumDiffractions",0);
rays1 = raytrace(bsSite1, ueSite1, pm, "Type","pathloss");
rays2 = raytrace(bsSite2, ueSite2, pm, "Type", "pathloss");

plot(rays1{1}); plot(rays2{1});

pathToAs1 = [rays1{1}.PropagationDelay]-min([rays1{1}.PropagationDelay]);  % Time of arrival of each ray (normalized to 0 sec)
avgPathGains1  = -[rays1{1}.PathLoss];                                    % Average path gains of each ray
pathAoDs1 = [rays1{1}.AngleOfDeparture];                                  % AoD of each ray
pathAoAs1 = [rays1{1}.AngleOfArrival];                                    % AoA of each ray
isLOS1 = any([rays1{1}.LineOfSight]);                                     % Line of sight flag

pathToAs2 = [rays2{1}.PropagationDelay]-min([rays2{1}.PropagationDelay]);  % Time of arrival of each ray (normalized to 0 sec)
avgPathGains2  = -[rays2{1}.PathLoss];                                    % Average path gains of each ray
pathAoDs2 = [rays2{1}.AngleOfDeparture];                                  % AoD of each ray
pathAoAs2 = [rays2{1}.AngleOfArrival];                                    % AoA of each ray
isLOS2 = any([rays2{1}.LineOfSight]);                                     % Line of sight flag

channel1 = nrCDLChannel;
channel1.DelayProfile = 'Custom';
channel1.PathDelays = pathToAs;
channel1.AveragePathGains = avgPathGains;
channel1.AnglesAoD = pathAoDs(1,:);       % azimuth of departure
channel1.AnglesZoD = 90-pathAoDs(2,:);    % channel uses zenith angle, rays use elevation
channel1.AnglesAoA = pathAoAs(1,:);       % azimuth of arrival
channel1.AnglesZoA = 90-pathAoAs(2,:);    % channel uses zenith angle, rays use elevation
channel1.HasLOSCluster = isLOS;
channel1.CarrierFrequency = fc;
channel1.NormalizeChannelOutputs = false; % do not normalize by the number of receive antennas, this would change the receive power
channel1.NormalizePathGains = false;      % set to false to retain the path gains

channel2 = nrCDLChannel;
channel2.DelayProfile = 'Custom';
channel2.PathDelays = pathToAs;
channel2.AveragePathGains = avgPathGains;
channel2.AnglesAoD = pathAoDs(1,:);       % azimuth of departure
channel2.AnglesZoD = 90-pathAoDs(2,:);    % channel uses zenith angle, rays use elevation
channel2.AnglesAoA = pathAoAs(1,:);       % azimuth of arrival
channel2.AnglesZoA = 90-pathAoAs(2,:);    % channel uses zenith angle, rays use elevation
channel2.HasLOSCluster = isLOS;
channel2.CarrierFrequency = fc;
channel2.NormalizeChannelOutputs = false; % do not normalize by the number of receive antennas, this would change the receive power
channel2.NormalizePathGains = false;      % set to false to retain the path gains

c = physconst('LightSpeed');
lambda = c/fc;

% UE array (single panel)
ueArray = phased.NRRectangularPanelArray('Size',[ueAntSize(1:2) 1 1],'Spacing', [0.5*lambda*[1 1] 1 1]);
ueArray.ElementSet = {phased.IsotropicAntennaElement};   % isotropic antenna element
channel.ReceiveAntennaArray = ueArray;
channel.ReceiveArrayOrientation = [ueArrayOrientation(1); (-1)*ueArrayOrientation(2); 0];  % the (-1) converts elevation to downtilt

% Base station array (single panel)
bsArray = phased.NRRectangularPanelArray('Size',[bsAntSize(1:2) 1 1],'Spacing', [0.5*lambda*[1 1] 1 1]);
bsArray.ElementSet = {phased.NRAntennaElement};
channel.TransmitAntennaArray = bsArray;
channel.TransmitArrayOrientation = [bsArrayOrientation(1); (-1)*bsArrayOrientation(2); 0];   % the (-1) converts elevation to downtilt