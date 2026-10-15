%% Urban Link and Coverage Analysis Using Ray Tracing
% - Import and visualize 3-D buildings data into Site Viewer
% - Define transmitter sites and ray tracing propagation model
% - Analyze links in two frequency bands: 4.7 GHz and 28 GHz
% - Compare coverage and performance between frequency bands

%% Import and Visualize buildings Data
viewer = siteviewer(Buildings="seongnam.osm",Basemap="topographic");

%% =======================================================
%%           EXPERIMENT 1: 4.7 GHz Band
%% =======================================================
fprintf('\n\n');
fprintf('##########################################################\n');
fprintf('##                                                      ##\n');
fprintf('##        EXPERIMENT 1: 4.7 GHz Band Analysis          ##\n');
fprintf('##        Bandwidth: 100 MHz, Power: 80 W              ##\n');
fprintf('##                                                      ##\n');
fprintf('##########################################################\n\n');

%% Define Transmitter Sites for 4.7 GHz
tx1_4p7 = txsite(Name="TX1 (4.7GHz)", ...
    Latitude=37.455715, ...
    Longitude=127.133562, ...
    AntennaHeight=80, ...
    TransmitterPower=80, ...  % 80 W
    TransmitterFrequency=4.7e9);

tx2_4p7 = txsite(Name="TX2 (4.7GHz)", ...
    Latitude=37.4541, ...
    Longitude=127.1210, ...
    AntennaHeight=80, ...
    TransmitterPower=80, ...  % 80 W
    TransmitterFrequency=4.7e9);

show(tx1_4p7); show(tx2_4p7);

%% Ray Tracing Propagation Model
rtpm_4p7 = propagationModel("raytracing", ...
    Method="sbr", ...
    MaxNumReflections=2, ...
    BuildingsMaterial="PEC", ...
    TerrainMaterial="PEC");

%% Coverage Maps for 4.7 GHz
coverage(tx1_4p7, rtpm_4p7, ...
    SignalStrengths=-120:-5, ...
    MaxRange=300, ...
    Resolution=3, ...
    Transparency=0.6)

coverage(tx2_4p7, rtpm_4p7, ...
    SignalStrengths=-120:-5, ...
    MaxRange=300, ...
    Resolution=3, ...
    Transparency=0.6)

%% Define Receiver Sites
rx1_1 = rxsite(Name="Rx1-1", ...
    Latitude=37.456715, Longitude=127.132562, AntennaHeight=1);
rx1_2 = rxsite(Name="Rx1-2", ...
    Latitude=37.4576, Longitude=127.1328, AntennaHeight=1);
rx1_3 = rxsite(Name="Rx1-3", ...
    Latitude=37.4563, Longitude=127.1321, AntennaHeight=1);
rx2_1 = rxsite(Name="Rx2-1", ...
    Latitude=37.4551, Longitude=127.1210, AntennaHeight=1);
rx2_2 = rxsite(Name="Rx2-2", ...
    Latitude=37.4544, Longitude=127.1228, AntennaHeight=1);
rx2_3 = rxsite(Name="Rx2-3", ...
    Latitude=37.4528, Longitude=127.1219, AntennaHeight=1);

%% Beam Steering Configuration for 4.7 GHz
azvec = -180:180;
elvec = -90:90;
SLA = 30;
tilt = 0;
az3dB = 65;
el3dB = 65;
lambda_4p7 = physconst("lightspeed")/tx1_4p7.TransmitterFrequency;

[az,el] = meshgrid(azvec,elvec);
azMagPattern = -min(12*(az/az3dB).^2,SLA);
elMagPattern = -min(12*((el-tilt)/el3dB).^2,SLA);
combinedMagPattern = -min(-(azMagPattern + elMagPattern), SLA);

antennaElement_4p7 = phased.CustomAntennaElement(MagnitudePattern=combinedMagPattern);
tx1_4p7.Antenna = phased.URA(Size=[8 8], ...
    Element=antennaElement_4p7, ...
    ElementSpacing=[lambda_4p7/2 lambda_4p7/2]);
tx2_4p7.Antenna = phased.URA(Size=[8 8], ...
    Element=antennaElement_4p7, ...
    ElementSpacing=[lambda_4p7/2 lambda_4p7/2]);

tx1_4p7.AntennaAngle = 90;
tx2_4p7.AntennaAngle = 90;

%% Antenna Directivity for 4.7 GHz
fprintf('\n========================================================\n')
fprintf('        Antenna Directivity (4.7 GHz)           \n')
fprintf('========================================================\n')
antennaDirectivity_tx1_4p7 = pattern(tx1_4p7.Antenna, tx1_4p7.TransmitterFrequency);
antennaDirectivityMax_tx1_4p7 = max(antennaDirectivity_tx1_4p7(:));
fprintf('TX1 Peak antenna directivity: %.2f dBi\n', antennaDirectivityMax_tx1_4p7);
antennaDirectivity_tx2_4p7 = pattern(tx2_4p7.Antenna, tx2_4p7.TransmitterFrequency);
antennaDirectivityMax_tx2_4p7 = max(antennaDirectivity_tx2_4p7(:));
fprintf('TX2 Peak antenna directivity: %.2f dBi\n', antennaDirectivityMax_tx2_4p7);

%% Signal Strength Analysis for 4.7 GHz
fprintf('\n========================================================\n')
fprintf('        Received Power (4.7 GHz)                \n')
fprintf('========================================================\n')
ss_rx1_1_4p7 = sigstrength(rx1_1,tx1_4p7,rtpm_4p7);
ss_rx1_2_4p7 = sigstrength(rx1_2,tx1_4p7,rtpm_4p7);
ss_rx1_3_4p7 = sigstrength(rx1_3,tx1_4p7,rtpm_4p7);
ss_rx2_1_4p7 = sigstrength(rx2_1,tx2_4p7,rtpm_4p7);
ss_rx2_2_4p7 = sigstrength(rx2_2,tx2_4p7,rtpm_4p7);
ss_rx2_3_4p7 = sigstrength(rx2_3,tx2_4p7,rtpm_4p7);

fprintf('Rx1_1 from TX1: %.2f dBm\n', ss_rx1_1_4p7);
fprintf('Rx1_2 from TX1: %.2f dBm\n', ss_rx1_2_4p7);
fprintf('Rx1_3 from TX1: %.2f dBm\n', ss_rx1_3_4p7);
fprintf('Rx2_1 from TX2: %.2f dBm\n', ss_rx2_1_4p7);
fprintf('Rx2_2 from TX2: %.2f dBm\n', ss_rx2_2_4p7);
fprintf('Rx2_3 from TX2: %.2f dBm\n', ss_rx2_3_4p7);

%% Noise Power and SNR for 4.7 GHz
bandwidth_4p7_MHz = 100;
bandwidth_4p7_Hz = bandwidth_4p7_MHz*1e6;
NF = 9;
thermal_noise_4p7_dBm = -174 + 10*log10(bandwidth_4p7_Hz);
noise_power_4p7_dBm = thermal_noise_4p7_dBm + NF;

fprintf('\n========================================================\n');
fprintf('        Noise Power (4.7 GHz, BW=100MHz)        \n');
fprintf('========================================================\n');
fprintf('Bandwidth: %.1f MHz\n', bandwidth_4p7_MHz);
fprintf('Noise Figure: %.1f dB\n', NF);
fprintf('Thermal Noise: %.2f dBm\n', thermal_noise_4p7_dBm);
fprintf('Total Noise Power: %.2f dBm\n', noise_power_4p7_dBm);

fprintf('\n========================================================\n');
fprintf('              SNR (4.7 GHz)                     \n');
fprintf('========================================================\n');
snr_rx1_1_4p7 = ss_rx1_1_4p7 - noise_power_4p7_dBm;
snr_rx1_2_4p7 = ss_rx1_2_4p7 - noise_power_4p7_dBm;
snr_rx1_3_4p7 = ss_rx1_3_4p7 - noise_power_4p7_dBm;
snr_rx2_1_4p7 = ss_rx2_1_4p7 - noise_power_4p7_dBm;
snr_rx2_2_4p7 = ss_rx2_2_4p7 - noise_power_4p7_dBm;
snr_rx2_3_4p7 = ss_rx2_3_4p7 - noise_power_4p7_dBm;

fprintf('Rx1_1 from TX1: %.2f dB\n', snr_rx1_1_4p7);
fprintf('Rx1_2 from TX1: %.2f dB\n', snr_rx1_2_4p7);
fprintf('Rx1_3 from TX1: %.2f dB\n', snr_rx1_3_4p7);
fprintf('Rx2_1 from TX2: %.2f dB\n', snr_rx2_1_4p7);
fprintf('Rx2_2 from TX2: %.2f dB\n', snr_rx2_2_4p7);
fprintf('Rx2_3 from TX2: %.2f dB\n', snr_rx2_3_4p7);

%% =======================================================
%%           EXPERIMENT 2: 28 GHz Band
%% =======================================================
fprintf('\n\n');
fprintf('##########################################################\n');
fprintf('##                                                      ##\n');
fprintf('##         EXPERIMENT 2: 28 GHz Band Analysis          ##\n');
fprintf('##        Bandwidth: 400 MHz, Power: 2 W               ##\n');
fprintf('##                                                      ##\n');
fprintf('##########################################################\n\n');

clearMap(viewer)
viewer = siteviewer(Buildings="seongnam.osm",Basemap="topographic");

%% Define Transmitter Sites for 28 GHz
tx1_28 = txsite(Name="TX1 (28GHz)", ...
    Latitude=37.455715, ...
    Longitude=127.133562, ...
    AntennaHeight=80, ...
    TransmitterPower=2, ...  % 2 W
    TransmitterFrequency=28e9);

tx2_28 = txsite(Name="TX2 (28GHz)", ...
    Latitude=37.4541, ...
    Longitude=127.1210, ...
    AntennaHeight=80, ...
    TransmitterPower=2, ...  % 2 W
    TransmitterFrequency=28e9);

show(tx1_28); show(tx2_28);

%% Ray Tracing Propagation Model for 28 GHz
rtpm_28 = propagationModel("raytracing", ...
    Method="sbr", ...
    MaxNumReflections=2, ...
    BuildingsMaterial="PEC", ...
    TerrainMaterial="PEC");

%% Coverage Maps for 28 GHz
coverage(tx1_28, rtpm_28, ...
    SignalStrengths=-120:-5, ...
    MaxRange=300, ...
    Resolution=3, ...
    Transparency=0.6)

coverage(tx2_28, rtpm_28, ...
    SignalStrengths=-120:-5, ...
    MaxRange=300, ...
    Resolution=3, ...
    Transparency=0.6)

%% Beam Steering Configuration for 28 GHz
lambda_28 = physconst("lightspeed")/tx1_28.TransmitterFrequency;

antennaElement_28 = phased.CustomAntennaElement(MagnitudePattern=combinedMagPattern);
tx1_28.Antenna = phased.URA(Size=[8 8], ...
    Element=antennaElement_28, ...
    ElementSpacing=[lambda_28/2 lambda_28/2]);
tx2_28.Antenna = phased.URA(Size=[8 8], ...
    Element=antennaElement_28, ...
    ElementSpacing=[lambda_28/2 lambda_28/2]);

tx1_28.AntennaAngle = 90;
tx2_28.AntennaAngle = 90;

%% Antenna Directivity for 28 GHz
fprintf('\n========================================================\n')
fprintf('        Antenna Directivity (28 GHz)            \n')
fprintf('========================================================\n')
antennaDirectivity_tx1_28 = pattern(tx1_28.Antenna, tx1_28.TransmitterFrequency);
antennaDirectivityMax_tx1_28 = max(antennaDirectivity_tx1_28(:));
fprintf('TX1 Peak antenna directivity: %.2f dBi\n', antennaDirectivityMax_tx1_28);
antennaDirectivity_tx2_28 = pattern(tx2_28.Antenna, tx2_28.TransmitterFrequency);
antennaDirectivityMax_tx2_28 = max(antennaDirectivity_tx2_28(:));
fprintf('TX2 Peak antenna directivity: %.2f dBi\n', antennaDirectivityMax_tx2_28);

%% Signal Strength Analysis for 28 GHz
fprintf('\n========================================================\n')
fprintf('        Received Power (28 GHz)                 \n')
fprintf('========================================================\n')
ss_rx1_1_28 = sigstrength(rx1_1,tx1_28,rtpm_28);
ss_rx1_2_28 = sigstrength(rx1_2,tx1_28,rtpm_28);
ss_rx1_3_28 = sigstrength(rx1_3,tx1_28,rtpm_28);
ss_rx2_1_28 = sigstrength(rx2_1,tx2_28,rtpm_28);
ss_rx2_2_28 = sigstrength(rx2_2,tx2_28,rtpm_28);
ss_rx2_3_28 = sigstrength(rx2_3,tx2_28,rtpm_28);

fprintf('Rx1_1 from TX1: %.2f dBm\n', ss_rx1_1_28);
fprintf('Rx1_2 from TX1: %.2f dBm\n', ss_rx1_2_28);
fprintf('Rx1_3 from TX1: %.2f dBm\n', ss_rx1_3_28);
fprintf('Rx2_1 from TX2: %.2f dBm\n', ss_rx2_1_28);
fprintf('Rx2_2 from TX2: %.2f dBm\n', ss_rx2_2_28);
fprintf('Rx2_3 from TX2: %.2f dBm\n', ss_rx2_3_28);

%% Noise Power and SNR for 28 GHz
bandwidth_28_MHz = 400;
bandwidth_28_Hz = bandwidth_28_MHz*1e6;
thermal_noise_28_dBm = -174 + 10*log10(bandwidth_28_Hz);
noise_power_28_dBm = thermal_noise_28_dBm + NF;

fprintf('\n========================================================\n');
fprintf('        Noise Power (28 GHz, BW=400MHz)         \n');
fprintf('========================================================\n');
fprintf('Bandwidth: %.1f MHz\n', bandwidth_28_MHz);
fprintf('Noise Figure: %.1f dB\n', NF);
fprintf('Thermal Noise: %.2f dBm\n', thermal_noise_28_dBm);
fprintf('Total Noise Power: %.2f dBm\n', noise_power_28_dBm);

fprintf('\n========================================================\n');
fprintf('              SNR (28 GHz)                      \n');
fprintf('========================================================\n');
snr_rx1_1_28 = ss_rx1_1_28 - noise_power_28_dBm;
snr_rx1_2_28 = ss_rx1_2_28 - noise_power_28_dBm;
snr_rx1_3_28 = ss_rx1_3_28 - noise_power_28_dBm;
snr_rx2_1_28 = ss_rx2_1_28 - noise_power_28_dBm;
snr_rx2_2_28 = ss_rx2_2_28 - noise_power_28_dBm;
snr_rx2_3_28 = ss_rx2_3_28 - noise_power_28_dBm;

fprintf('Rx1_1 from TX1: %.2f dB\n', snr_rx1_1_28);
fprintf('Rx1_2 from TX1: %.2f dB\n', snr_rx1_2_28);
fprintf('Rx1_3 from TX1: %.2f dB\n', snr_rx1_3_28);
fprintf('Rx2_1 from TX2: %.2f dB\n', snr_rx2_1_28);
fprintf('Rx2_2 from TX2: %.2f dB\n', snr_rx2_2_28);
fprintf('Rx2_3 from TX2: %.2f dB\n', snr_rx2_3_28);

%% =======================================================
%%              Comparison Summary
%% =======================================================
fprintf('\n\n');
fprintf('##########################################################\n');
fprintf('##                                                      ##\n');
fprintf('##            COMPARISON SUMMARY                       ##\n');
fprintf('##                                                      ##\n');
fprintf('##########################################################\n\n');

fprintf('========================================================\n');
fprintf('    Average Received Power Comparison               \n');
fprintf('========================================================\n');
avg_rx_power_4p7 = mean([ss_rx1_1_4p7, ss_rx1_2_4p7, ss_rx1_3_4p7, ...
                         ss_rx2_1_4p7, ss_rx2_2_4p7, ss_rx2_3_4p7]);
avg_rx_power_28 = mean([ss_rx1_1_28, ss_rx1_2_28, ss_rx1_3_28, ...
                        ss_rx2_1_28, ss_rx2_2_28, ss_rx2_3_28]);
fprintf('4.7 GHz (80W, 100MHz):  %.2f dBm\n', avg_rx_power_4p7);
fprintf('28 GHz  (2W, 400MHz):   %.2f dBm\n', avg_rx_power_28);
fprintf('Difference:             %.2f dB\n', avg_rx_power_4p7 - avg_rx_power_28);

fprintf('\n========================================================\n');
fprintf('         Average SNR Comparison                    \n');
fprintf('========================================================\n');
avg_snr_4p7 = mean([snr_rx1_1_4p7, snr_rx1_2_4p7, snr_rx1_3_4p7, ...
                    snr_rx2_1_4p7, snr_rx2_2_4p7, snr_rx2_3_4p7]);
avg_snr_28 = mean([snr_rx1_1_28, snr_rx1_2_28, snr_rx1_3_28, ...
                   snr_rx2_1_28, snr_rx2_2_28, snr_rx2_3_28]);
fprintf('4.7 GHz (80W, 100MHz):  %.2f dB\n', avg_snr_4p7);
fprintf('28 GHz  (2W, 400MHz):   %.2f dB\n', avg_snr_28);
fprintf('Difference:             %.2f dB\n', avg_snr_4p7 - avg_snr_28);

fprintf('\n========================================================\n\n');