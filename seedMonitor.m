function seedMonitor
%SEEDMONITOR_NOLOGS Summary of this function goes here
%   Detailed explanation goes here
disp('Loading config.txt ...');
config=struct;
config_text=fileread('config.txt');
eval(config_text);
clear config_text;

disp('Configuration file loaded.');
disp(['GUI starting at ' datestr(now)]);

%% Initialize Data Structures
numPoints=config.numPoints;
Data=zeros(numPoints,5);

shifter=gallery('tridiag', numPoints, 0, 0, 1);
%% Initialize GUI
disp('Initializing GUI...');

mygui=figure('Name' ,'Seed Monitor','Position', [100 400 1900 400],'CloseRequestFcn', @closeFcn, 'Visible', 'Off');
set(mygui,'Resize','Off');
set(mygui,'MenuBar','none');
set(mygui,'NumberTitle','Off');
set(mygui,'Color','w');

mytable=uitable('Parent', mygui, 'Units', 'Normalized', 'Position', [.85 .25 .1275 .4125]);
set(mytable,'RowName',{})
set(mytable,'ColumnName',{});
set(mytable,'ColumnWidth',{180, 60});
set(mytable,'FontSize',14);
data={'String', '1';'String', '1';'String', '1';'String', '1';'String', '1'};
set(mytable,'Data',data);

power_axes=axes('Parent', mygui,'Position', [.025 .1 .8 .325]);    
title(power_axes, 'Power Monitor');
xlabel(power_axes,'Time');
ylabel(power_axes,'Power (mW)');  
datetick('x');
hold(power_axes, 'on');

temp_axes=axes('Parent', mygui,'Position', [.025 .6 .8 .325]);
title(temp_axes, 'Temperature Monitor');
xlabel(temp_axes, 'Time');
ylabel(temp_axes, 'Laser Temperature (C)');  
datetick('x');
hold(temp_axes, 'on');

n=1;

%% Update and Start Timer
PORT='COM1';
try
    disp(['Attemping connection on ' PORT]);    
    Serial_Seed=establishConnection(PORT,config.LaserSetPointTemp, config.LaserSetPoint);

catch
    disp('No PORT found')
    delete(instrfindall);
    error('No PORT found!');
end

getStatus(Serial_Seed);
update();
disp('Starting timer...');
updateTimer=timer('Period', config.Period, 'ExecutionMode', 'fixedSpacing', 'TimerFcn', @callbackUpdateTimer);
start(updateTimer);
disp('Showing GUI...');

mygui.Visible='On';  
    
function update()     
    [power, caseTemp, laserTemp, pumpTemp, laserSP, laserTempSP]=getStatus(Serial_Seed);         
    data={'Power (mW)', num2str(power); ...
    'Case Temp (C)', num2str(caseTemp); ...
    'Laser Temp (C)', num2str(laserTemp); ...
    'Pump Temper (C)', num2str(pumpTemp); ...       
    'Laser SP (bits)', num2str(laserSP); ...
    'Laser Temp. SP (C)', num2str(laserTempSP)};   
    
    set(mytable,'Data',data);
    dataVector=[now power caseTemp laserTemp pumpTemp];     
    if n<numPoints
        Data(n,:)=dataVector;
        n=n+1;
    else
        Data=shifter*Data;
        Data(n,:)=dataVector;%shift and add the current temperatures
    end       

    cla(power_axes);
    axes(power_axes);    
    plot(power_axes,Data(1:n,1),Data(1:n,2),'or','MarkerFaceColor','r'); 
    xlim([now-1200/(24*60*60) now])
    datetick('x','HH:MM:SS', 'keeplimits')    
    
    cla(temp_axes);
    axes(temp_axes);  
    plot(temp_axes,Data(1:n,1),Data(1:n,3),'or','MarkerFaceColor','r'); 
    plot(temp_axes,Data(1:n,1),Data(1:n,4),'ob','MarkerFaceColor','b'); 
    plot(temp_axes,Data(1:n,1),Data(1:n,5),'ok','MarkerFaceColor','k');
    xlim([now-1200/(24*60*60) now])
    datetick('x','HH:MM:SS', 'keeplimits')

    legend(temp_axes, 'Laser Temp', 'Case Temp', 'Pump Temp', 'Location', 'southwest');
end

function callbackUpdateTimer(~,~)
    update();
end

function closeFcn(~,~)
    disp('Closing GUI...');
    disp('Stopping timer and waiting...');
    stop(updateTimer);
    pause(2);
    disp('Closing the serial connection.');
    fclose(Serial_Seed);
    disp(['Deleting serial connections on PORT ' PORT]);
    delete(instrfind('Name', ['Serial-' PORT]));
    disp('Deleting the figure...');
    delete(mygui);        
end

end



function s=establishConnection(PORT,TEMPSP,POWSP)
delete(instrfind('Name', ['Serial-' PORT]))
port=PORT;
baud=9600;
databits=8;
stopbits=1;
parity='none';
flowcontrol='none';
timeout=2;

display(sprintf('Opening %s...', port));
s = serial(port, 'BaudRate', baud, 'Parity', parity, 'StopBits', stopbits, 'DataBits', databits, 'FlowControl', flowcontrol);

set(s, 'terminator', 'CR');
set(s, 'timeout', timeout);
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
    fread(s, s.BytesAvailable);
end

end

function  [power, caseTemp, laserTemp, pumpTemp, laserSP, laserTempSP]=getStatus(s)
    delay=0.05;   
    while (s.BytesAvailable>0)
        fread(s, s.BytesAvailable);
    end        
    pause(delay);
    fprintf(s, '%s\r', 'RPOWER');        
    pause(delay);      

    power=str2num(strtrim(fscanf(s)));               

    while (s.BytesAvailable>0)
        fread(s, s.BytesAvailable);
    end
    pause(delay);
    fprintf(s, '%s\r', 'RCASETEMP');
    pause(delay);
    caseTemp=str2num(strtrim(fscanf(s))); 

    while (s.BytesAvailable>0)
        fread(s, s.BytesAvailable);
    end
    pause(delay);
    fprintf(s, '%s\r', 'RETHTEC');
    pause(delay);
    laserTemp=str2num(strtrim(fscanf(s)));

    while (s.BytesAvailable>0)
        fread(s, s.BytesAvailable);
    end
    pause(delay);
    fprintf(s, '%s\r', 'RTECTEMP');
    pause(delay);
    pumpTemp=str2num(strtrim(fscanf(s)));         

    while (s.BytesAvailable>0)
        fread(s, s.BytesAvailable);
    end
    pause(delay);
    fprintf(s, '%s\r', 'RDPOTWIPER');
    pause(delay);
    laserSP=str2num(strtrim(fscanf(s)));

    while (s.BytesAvailable>0)
        fread(s, s.BytesAvailable);
    end
    pause(delay);
    fprintf(s, '%s\r', 'RTECSP');
    pause(0.1);        
    laserTempSP=str2num(strtrim(fscanf(s)));  
end


