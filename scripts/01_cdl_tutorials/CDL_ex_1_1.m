fc = 28e9;
bsPosition = [37.4536, 127.1369];
bsAntSize = [8 8];
bsArrayOrientation = [90 0].';

uePositions = [
    37.4555000 127.1338000  % UE1
    37.4554000 127.1345000  % UE2
    37.4556000 127.1357000  % UE3
    37.4527000 127.1346000  % UE4
    37.4526000 127.1337000  % UE5
];
nUE = size(uePositions,1);

ueAntSize = [2 2];
ueArrayOrientation = [270 90].';
reflectionsOrder = 1;

SCS = 15;      % kHz
NRB = 52;      % ~10 MHz

%% Site Viewer & Sites
if exist('viewer','var') && isvalid(viewer)
    clearMap(viewer);
else
    viewer = siteviewer("Basemap","openstreetmap","Buildings","seongnam.osm");
end

bsSite = txsite("Name","Base station", ...
    "Latitude",bsPosition(1),"Longitude",bsPosition(2), ...
    "AntennaAngle",bsArrayOrientation(1:2), ...
    "AntennaHeight",4, ...
    "TransmitterFrequency",fc);

ueSites = repmat(rxsite,1,nUE);
for i = 1:nUE
    ueSites(i) = rxsite("Name",sprintf("UE%d",i), ...
        "Latitude",uePositions(i,1),"Longitude",uePositions(i,2), ...
        "AntennaHeight",1, ...
        "AntennaAngle",ueArrayOrientation(1:2));
end

show(bsSite);
show(ueSites);

%% Arrays & Channel Template (once)
c = physconst('LightSpeed'); lambda = c/fc;

ueArray = phased.NRRectangularPanelArray('Size',[ueAntSize(1:2) 1 1], ...
    'Spacing',[0.5*lambda*[1 1] 1 1]);
ueArray.ElementSet = {phased.IsotropicAntennaElement};

bsArray = phased.NRRectangularPanelArray('Size',[bsAntSize(1:2) 1 1], ...
    'Spacing',[0.5*lambda*[1 1] 1 1]);
bsArray.ElementSet = {phased.NRAntennaElement};

ofdmInfo = nrOFDMInfo(NRB,SCS);

channelTemplate = nrCDLChannel;
channelTemplate.DelayProfile = 'Custom';
channelTemplate.CarrierFrequency = fc;
channelTemplate.NormalizeChannelOutputs = false;
channelTemplate.NormalizePathGains  = false;
channelTemplate.ReceiveAntennaArray = ueArray;
channelTemplate.ReceiveArrayOrientation = [ueArrayOrientation(1); -ueArrayOrientation(2); 0];
channelTemplate.TransmitAntennaArray = bsArray;
channelTemplate.TransmitArrayOrientation = [bsArrayOrientation(1); -bsArrayOrientation(2); 0];
channelTemplate.SampleRate = ofdmInfo.SampleRate;
channelTemplate.ChannelFiltering = false;

%% Ray Tracing (Site Viewer 전용)
pm = propagationModel("raytracing","Method","sbr", ...
    "MaxNumReflections",reflectionsOrder,"MaxNumDiffractions",0);
raysAll = raytrace(bsSite, ueSites, pm, "Type","pathloss");

for i = 1:nUE
    if isempty(raysAll{i}), continue; end
    for k = 1:numel(raysAll{i})
        plot(raysAll{i}(k)); % Site Viewer에 렌더링
    end
end

%% Per-UE: Path Gains, Channel Mag Response, Radiation Pattern
for i = 1:nUE
    if isempty(raysAll{i})
        fprintf("[UE%d] Rays: 0 (skip)\n", i);
        continue;
    end

    rays = raysAll{i};
    % Ray -> CDL params
    pathToAs     = [rays.PropagationDelay] - min([rays.PropagationDelay]);
    avgPathGains = -[rays.PathLoss];                % dB
    pathAoDs     = [rays.AngleOfDeparture];
    pathAoAs     = [rays.AngleOfArrival];
    isLOS        = any([rays.LineOfSight]);

    ch = clone(channelTemplate);
    ch.PathDelays       = pathToAs;
    ch.AveragePathGains = avgPathGains;
    ch.AnglesAoD        = pathAoDs(1,:);
    ch.AnglesZoD        = 90 - pathAoDs(2,:);
    ch.AnglesAoA        = pathAoAs(1,:);
    ch.AnglesZoA        = 90 - pathAoAs(2,:);
    ch.HasLOSCluster    = isLOS;

    % Channel response & perfect estimate
    [pathGains, sampleTimes] = ch();
    pg = permute(pathGains,[2 1 3 4]);           
    if isLOS && size(pg,1) >= 2
        pg = [sum(pg(1:2,:,:,:)); pg(3:end,:,:,:)];
    end
    instPathG_dB = pow2db(abs(pg(:,1,1,1)).^2);

    pathFilters = getPathFilters(ch);
    [offset,~] = nrPerfectTimingEstimate(pathGains, pathFilters);
    hest = nrPerfectChannelEstimate(pathGains, pathFilters, NRB, SCS, 0, offset, sampleTimes);
    H2_dB = pow2db(abs(hest(:,:,1,1)).^2);

    % === Plots ===
    % Path Gains (dark theme)
    fig1 = figure('Name', sprintf('UE%d Path Gains', i), 'Color', 'k');
    ax1  = axes(fig1); hold(ax1,'on'); grid(ax1,'on');
    plot(ax1, instPathG_dB,'o-','DisplayName','Instantaneous (1^{st} tx - 1^{st} rx antenna)');
    plot(ax1, avgPathGains,'x--','DisplayName','Average (from ray tracing)');
    xlabel(ax1,"Path number"); ylabel(ax1,"Gain (dB)");
    title(ax1, sprintf("UE%d Path gains", i));
    legend(ax1,'Location','best');
    stylizeAxesDark(ax1);
    hold(ax1,'off');

    % Channel Magnitude Response (dark theme)
    fig2 = figure('Name', sprintf('UE%d Channel Mag Resp', i), 'Color', 'k');
    ax2  = axes(fig2);
    surf(ax2, H2_dB, 'EdgeColor','none'); shading(ax2,'flat'); view(ax2,45,25);
    colormap(ax2, parula); colorbar(ax2);
    caxis(ax2, [prctile(H2_dB(:),5), prctile(H2_dB(:),95)]);
    xlabel(ax2,'Subcarriers'); ylabel(ax2,'OFDM Symbols'); zlabel(ax2,'Magnitude Squared (dB)');
    title(ax2,'Channel Magnitude Response (1^{st} tx - 1^{st} rx antenna)');
    stylizeAxesDark(ax2);

    % === Beamforming weights & Radiation pattern ===
    nLayers = 1; scOffset = 0; noRBs = 1;
    [wbs,wue,~] = getBeamformingWeights(hest,nLayers,scOffset,noRBs);

    % Plot BS radiation pattern 
    bsSite.Antenna = clone(ch.TransmitAntennaArray); % need a clone, otherwise setting the Taper weights would affect the channel array
    bsSite.Antenna.Taper = wbs;
    pattern(bsSite,fc,"Size",5);

    % UE 패턴 (요소 수 = 2x2 = 4 확인)
    if numel(wue) == prod(ueAntSize) || isscalar(wue)
        ueSites(i).Antenna = clone(ueArray);
        ueSites(i).Antenna.Taper = wue(:).';     % row vector
        pattern(ueSites(i), fc, "Size", 4);
        title(sprintf("UE%d Radiation Pattern", i));
    else
        warning('UE%d: wue length %d does not match %d elements', i, numel(wue), prod(ueAntSize));
    end

    % (옵션) BS 패턴 (요소 수 = 8x8 = 64 확인) — 원하면 주석 해제
    if numel(wbs) == prod(bsAntSize) || isscalar(wbs)
        bsSite.Antenna = clone(bsArray);
        bsSite.Antenna.Taper = wbs(:).';         % row vector
        % pattern(bsSite, fc, "Size", 5);        % ← 필요할 때만 표시
    else
        warning('UE%d: wbs length %d does not match %d elements', i, numel(wbs), prod(bsAntSize));
    end
end

%% ===== Helper Functions =====
function stylizeAxesDark(ax)
    set(ax,'Color','k','XColor','w','YColor','w','ZColor','w', ...
        'GridColor',[0.5 0.5 0.5],'MinorGridColor',[0.3 0.3 0.3], ...
        'LineWidth',1.0,'Box','on');
    ax.FontName = 'Helvetica'; ax.FontSize = 12;
    if ~isempty(ax.Title),  ax.Title.Color  = 'w'; end
    if ~isempty(ax.XLabel), ax.XLabel.Color = 'w'; end
    if ~isempty(ax.YLabel), ax.YLabel.Color = 'w'; end
    if ~isempty(ax.ZLabel), ax.ZLabel.Color = 'w'; end
    cb = findobj(ax.Parent,'Type','ColorBar'); if ~isempty(cb), set(cb,'Color','w'); end
end

function [wtx,wrx,D] = getBeamformingWeights(hEst,nLayers,scOffset,noRBs)
    [~,~,R,P] = size(hEst);
    scNo = scOffset+1;
    hEstWin = hEst(scNo:scNo+(12*noRBs-1),:,:,:);
    H = permute(mean(reshape(hEstWin,[],R,P)),[2 3 1]);
    [U,D,V] = svd(H);
    wtx = V(:,1:nLayers).';
    wrx = U(:,1:nLayers)';
end