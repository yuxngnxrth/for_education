function [ber, numBits] = lab2_ex02(EbNo, maxNumErrs, maxNumBits, scramblingFlag)
%% Constants
FRM = 2400; % Size of bit frame
clear functions

%% Установка значения по умолчанию для scramblingFlag
if nargin < 4
    scramblingFlag = true; % По умолчанию скремблирование включено
end

%% Modulation Mode
%ModulationMode=1; % QPSK
%ModulationMode=2; % QAM16
ModulationMode = 3; % QAM64
k = 2 * ModulationMode; % Number of bits per modulation symbol
snr = EbNo + 10*log10(k);
noiseVar = 10.^(0.1 .* (-snr));

%% Processsing loop: transmitter, channel model and receiver
numErrs = 0;
numBits = 0;
nS = 0;

while ((numErrs < maxNumErrs) && (numBits < maxNumBits))
    % Transmitter
    u = randi([0 1], FRM, 1);
    
    if scramblingFlag
        t0 = Scrambler(u, nS);
    else
        t0 = u;
    end
    
    t1 = Modulator(t0, ModulationMode);
    
    % Channel
    c0 = AWGNChannel(t1, snr);
    
    % Receiver
    r0 = DemodulatorSoft(c0, ModulationMode, noiseVar);
    
    if scramblingFlag
        r1 = DescramblerSoft(r0, nS);
    else
        r1 = r0;
    end
    
    y = double(r1 < 0); % Recover output bits
    
    % Measurements
    numErrs = numErrs + sum(y ~= u);
    numBits = numBits + FRM;
end

ber = numErrs / numBits;
end