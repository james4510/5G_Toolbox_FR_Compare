% gpu = gpuDevice;
% disp(gpu.Name + " GPU detected and available.")

osmFile = "seongnam_map.osm";


if exist(osmFile, 'file')
    viewer = siteviewer("Basemap","openstreetmap","Buildings",osmFile);    
else
    viewer = siteviewer("Basemap", "openstreetmap");
end

bsPositions = [37.455689,127.133490];
bsAntennaHeight = 10;           % 안테나 높이 (m)
txPower = 46;                   % 송신 전력 (dBm)
fc = 28e9;              % 반송파 주파수 (Hz)

tx = txsite(Name="Transmitter", ...
    Latitude=bsPositions(1), ...
    Longitude=bsPositions(2), ...
    AntennaHeight=bsAntennaHeight, ...
    TransmitterPower=txPower, ...
    TransmitterFrequency=fc);
show(tx)

fprintf('\n레이 트레이싱 모델 설정\n');

maxReflections = 2;
maxDiffractions = 1;

% https://kr.mathworks.com/help/comm/ref/propagationmodel.html
rtpm = propagationModel("raytracing", ...
    Method="sbr", ...
    MaxNumReflections=maxReflections, ...
    MaxNumDiffractions=maxDiffractions);

% GPU 없는 경우 주석 처리
% rtpm.UseGPU="on";

coverage(tx,rtpm, ...
   SignalStrengths=-120:-5, ...
   Resolution=3, ...
   MaxRange=250, ...
   Transparency=0.6)
