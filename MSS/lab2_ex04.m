function [ber, numBits]=lab2_ex04(EbNo, maxNumErrs, maxNumBits)
%% Constants
clear functions;
maxIter=6; % actual number of turbo decoder iterations
FRM=2432-24; % Size of bit frame
Kplus=FRM+24;
Indices = lteIntrlvrIndices(Kplus);
ModulationMode=1;
k=2*ModulationMode;
CodingRate=Kplus/(3*Kplus+12);
snr = EbNo + 10*log10(k) + 10*log10(CodingRate);
noiseVar = 10.^(-snr/10);
%% Processsing loop modeling transmitter, channel model and receiver
numErrs = 0; numBits = 0; nS=0;
while ((numErrs < maxNumErrs) && (numBits < maxNumBits))
 % Transmitter
 u = randi([0 1], FRM,1); % Randomly generated input bits
 data= CbCRCGenerator(u); % Code block CRC generator
 t0 = TurboEncoder(data, Indices); % Turbo Encoder
 t1 = Scrambler(t0, nS); % Scrambler
 t2 = Modulator(t1, ModulationMode); % Modulator
 % Channel
 c0 = AWGNChannel(t2, snr); % AWGN channel
 % Receiver
 r0 = DemodulatorSoft(c0, ModulationMode, noiseVar); % Demodulator
 r1 = DescramblerSoft(r0, nS); % Descrambler
 r2 = TurboDecoder(-r1, Indices,maxIter); % Turbo Deocder
 y = CbCRCDetector(r2); % Code block CRC dtector
 % Measurements
 numErrs = numErrs + sum(y~=u); % Update number of bit errors
 numBits = numBits + FRM; % Update number of bits processed
 % Manage slot number with each subframe processed
 nS = nS + 2; nS = mod(nS, 20);
end
%% Clean up & collect results
ber = numErrs/numBits; % Compute Bit Error Rate (BER)