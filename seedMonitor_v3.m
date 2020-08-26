function seedMonitor_v3
%SEEDMONITOR_NOLOGS Summary of this function goes here
% Authors: Cora Fujiwara and Max Prichard
% Edited: 7/9/2019
% The purpose of this gui is to display the output power and power
% setpoint of the laser as well as the temperature of the internal components
% of the laser. 

%% Load default settings
config.port='COM7';%COM port of the 
config.numPoints=500;
config.Period=1;
config.LaserSetPointTemp=36.4;
config.LaserSetPoint=80;
config.XLIM=[0 600];   

%% Load configuation file
disp('Loading config.txt ...');
config_text=fileread('config.txt');
eval(config_text);
clear config_text;

disp(config);

disp('Configuration file loaded.');
disp(['GUI starting at ' datestr(now)]);

%% Initialize Data Structures

disp('Initializing data structures;lkj...');
numPoints=config.numPoints;
timeVector=[0];
dataCounter=1;

%% Initialize GUI and Axes
disp('Initializing GUI and subsequent objects...');

mygui=figure('Name' ,'Seed Monitor', ...
    'Position', [100 400 1000 400], ...
    'CloseRequestFcn', @closeFcn, ...
    'Visible', 'Off');
set(mygui,'Resize','Off');
set(mygui,'MenuBar','none');
set(mygui,'NumberTitle','Off');
set(mygui,'Color','w');

power_axes=subplot(212);
title(power_axes, 'Power Monitor');
xlabel(power_axes,'Time');
ylabel(power_axes,'Power (mW)'); 
hold(power_axes, 'on');
grid on
set(power_axes, 'XMinorGrid', 'On', 'YMinorGrid', 'On', ...
    'XMinorTick', 'On', 'YMinorTick', 'On', 'Box', 'On');
set(power_axes,'FontSize',8);
xlim(power_axes,config.XLIM);

pPower=scatter(power_axes,0,0);
pPower.Marker='o';
pPower.MarkerFaceColor='r';
pPower.MarkerEdgeColor='r';

power_lg_str={'Power'};
power_lg=legend(power_axes, power_lg_str, 'Location', 'northeast');

temp_axes=subplot(211);
title(temp_axes, 'Temperature Monitor');
xlabel(temp_axes, 'Time');
ylabel(temp_axes, 'Laser Temperature (C)');  
hold(temp_axes, 'on');
grid on
set(temp_axes, 'XMinorGrid', 'On', 'YMinorGrid', 'On', ...
    'XMinorTick', 'On', 'YMinorTick', 'On', 'Box', 'On');
set(temp_axes,'FontSize',8);
xlim(temp_axes,config.XLIM);

pLaserTemp=scatter(temp_axes,0,0);
pLaserTemp.Marker='o';
pLaserTemp.MarkerFaceColor='r';
pLaserTemp.MarkerEdgeColor='r';

pCaseTemp=scatter(temp_axes,0,0);
pCaseTemp.Marker='o';
pCaseTemp.MarkerFaceColor='b';
pCaseTemp.MarkerEdgeColor='b';

pPumpTemp=scatter(temp_axes,0,0);
pPumpTemp.Marker='o';
pPumpTemp.MarkerFaceColor='k';
pPumpTemp.MarkerEdgeColor='k';
temp_lg_str={'Laser Temp (C)', 'Case Temp (C)', 'Pump Temp (C)'};
temp_lg=legend(temp_axes, temp_lg_str, 'Location', 'northeast');

%% Connect to Serial connection
try
    disp(['Attemping connection on ' config.port]);    
    Serial_Seed=establishConnection(config.port,config.LaserSetPointTemp, config.LaserSetPoint);

catch
    disp('No PORT found available!')
    delete(instrfind(config.port));
end

disp("successful connection")

%% Helper functions

function update()     
    if Serial_Seed.BytesAvailable
        fread(Serial_Seed,Serial_Seed.BytesAvailable);
    end
    
    [power, caseTemp, laserTemp, pumpTemp, laserSP, laserTempSP]=getStatus(Serial_Seed);    
    
   
    temp_lg.String{1}=[temp_lg_str{1} ': ' num2str(laserTemp) ' C (' num2str(laserTempSP) ' C SP)'];
    temp_lg.String{2}=[temp_lg_str{2} ': ' num2str(caseTemp) ' C'];
    temp_lg.String{3}=[temp_lg_str{3} ': ' num2str(pumpTemp) ' C'];  
    
    power_lg.String{1}=[power_lg_str{1} ': ' num2str(power) ' mW (' num2str(laserSP) ' bit SP)'];
    
    tnow=now*24*60*60;
    pPower.XData=tnow-timeVector;
    pCaseTemp.XData=tnow-timeVector;
    pLaserTemp.XData=tnow-timeVector;
    pPumpTemp.XData=tnow-timeVector;   
    
    pPower.YData(dataCounter)=power;
    pCaseTemp.YData(dataCounter)=caseTemp;
    pLaserTemp.YData(dataCounter)=laserTemp;
    pPumpTemp.YData(dataCounter)=pumpTemp;
    
    pPower.XData(dataCounter)=0;
    pCaseTemp.XData(dataCounter)=0;
    pLaserTemp.XData(dataCounter)=0;
    pPumpTemp.XData(dataCounter)=0;   
    
    timeVector(dataCounter)=now*24*60*60;
    
    if dataCounter==numPoints
        dataCounter=1;
    else
        dataCounter=dataCounter+1;
    end
    
    if Serial_Seed.BytesAvailable
        fread(Serial_Seed,Serial_Seed.BytesAvailable);
    end    
end

function callbackUpdateTimer(~,~)
    update();
end

function closeFcn(~,~)
    disp('Closing GUI...');
    disp('Stopping timer and waiting...');
    stop(updateTimer);
    pause(3);
    disp('Closing the serial connection.');
    fclose(Serial_Seed);
    disp(['Deleting serial connections on PORT ' config.port]);
    delete(instrfind('Name', ['Serial-' config.port]));
    disp('Deleting the figure...');
    delete(mygui);    
    delete(updateTimer);
end

%% Initialize Timer Object
update();
disp('Starting timer...');
updateTimer=timer('Period', config.Period, ...
    'ExecutionMode', 'fixedSpacing', ...
    'TimerFcn', @callbackUpdateTimer); %how the gui actually runs is 
%that the time ovject periodically calls @callbackUpdateTimer, which then
%runs @update to update all of the values from the laser
start(updateTimer);
disp('Showing GUI...');
mygui.Visible='On';  

end

function s=establishConnection(PORT,TEMPSP,POWSP)
delete(instrfind('Name', ['Serial-' PORT]))
port=PORT;
baud=9600;
databits=8;
stopbits=1;
parity='none';
flowcontrol='none';
% timeout=2;
terminator = 'CR/LF';


disp(sprintf('Opening %s...', port));
s = serial(port, 'BaudRate', baud, ...
    'Parity', parity, 'StopBits', stopbits, ...
    'DataBits', databits, 'FlowControl', flowcontrol);

set(s, 'terminator', terminator);
% set(s, 'timeout', timeout);
fopen(s);
disp('Connection has been opened.  Reading settings...');

a=get(s, 'StopBits');
b=get(s, 'DataBits');
c=get(s, 'BaudRate');
d=get(s, 'FlowControl');
e=get(s, 'Parity');
f=get(s, 'port');

disp(['Port         : ' f]); 
disp(['Stop Bits    : ' num2str(a)]);
disp(['Data Bits    : ' num2str(b)]);
disp(['Baud Rate    : ' num2str(c)]);
disp(['Flow Control : ' d]);
disp(['Parity       : ' e]);
disp(' ');
disp('Rewriting settings...');
pause(1);

fprintf(s, '%s\r', 'MSG OFF');
pause(0.1);
fprintf(s, '%s\r', 'PROMPT OFF');
pause(0.1);
fprintf(s, '%s\r', ['WTECTEMP ' num2str(TEMPSP)]);
pause(0.1);
fprintf(s, '%s\r', ['WDPOTWIPER ' num2str(POWSP)]);
pause(0.1);
fprintf(s, '%s\r', ['WDPOTWIPER ' num2str(POWSP)]);
pause(0.1);

disp('Flushing memory....');
while (s.BytesAvailable>0)
    disp("here there were bytes available")
    fread(s, s.BytesAvailable);
end

end


function  [power, caseTemp, laserTemp, pumpTemp, laserSP, laserTempSP]=getStatus(s)
    warning(''); %reset the warning buffer (the last warning sent by matlab)
    delay=0.5;   
    while (s.BytesAvailable>0)
        disp("There were bytes available")
        fread(s, s.BytesAvailable);
    end        
    pause(delay);
    fprintf(s, '%s\r', 'RPOWER');        
    pause(delay);      
%     disp("reading power")
    power=str2num(strtrim(fscanf(s)));               

    while (s.BytesAvailable>0)
        fread(s, s.BytesAvailable);
    end
    pause(delay);
    fprintf(s, '%s\r', 'RCASETEMP');
    pause(delay);
%     disp("reading case temp")
    caseTemp=str2num(strtrim(fscanf(s))); 

    while (s.BytesAvailable>0)
        fread(s, s.BytesAvailable);
    end
    pause(delay);
    fprintf(s, '%s\r', 'RETHTEC');
    pause(delay);
%     disp("reading laser temp")
    laserTemp=str2num(strtrim(fscanf(s)));

    while (s.BytesAvailable>0)
        fread(s, s.BytesAvailable);
    end
    pause(delay);
    fprintf(s, '%s\r', 'RTECTEMP');
    pause(delay);
%     disp("pump temp")
    pumpTemp=str2num(strtrim(fscanf(s)));         

    while (s.BytesAvailable>0)
        fread(s, s.BytesAvailable);
    end
    pause(delay);
    fprintf(s, '%s\r', 'RDPOTWIPER');
    pause(delay);
%     disp("power set point")
    laserSP=str2num(strtrim(fscanf(s)));

    while (s.BytesAvailable>0)
        fread(s, s.BytesAvailable);
    end
    pause(delay);
%     disp("laser temp set")
    fprintf(s, '%s\r', 'RTECSP');
    pause(0.1);        
    laserTempSP=str2num(strtrim(fscanf(s)));  
    
    if ~isempty(lastwarn) %if the warning buffer is now not empty, then something
        %went wrong with reding the data and just set everything to zero
        %temporarily. Sometimes this happens.
        disp('Something went wrong temporarily with reading the data')
        power=0;
        caseTemp=0;
        laserTemp=0;
        pumpTemp=0;
        laserSP=0;
        laserTempSP=0;
    end
    

end



