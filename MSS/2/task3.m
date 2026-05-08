clear; close all; clc;

EbNo_dB = 0:2:10;
maxErrs = 500; 
maxBits = 1e7;
Mode = 3;

ber_hard_with = zeros(size(EbNo_dB));
ber_hard_no   = zeros(size(EbNo_dB));
ber_soft_with = zeros(size(EbNo_dB));
ber_soft_no   = zeros(size(EbNo_dB));

for i = 1:length(EbNo_dB)
    fprintf('Eb/No = %d dB\n', EbNo_dB(i));
    
    ber_hard_with(i) = run_sim(EbNo_dB(i), maxErrs, maxBits, Mode, 'hard', true);
    ber_hard_no(i)   = run_sim(EbNo_dB(i), maxErrs, maxBits, Mode, 'hard', false);
    
    ber_soft_with(i) = run_sim(EbNo_dB(i), maxErrs, maxBits, Mode, 'soft', true);
    ber_soft_no(i)   = run_sim(EbNo_dB(i), maxErrs, maxBits, Mode, 'soft', false);
end

figure('Name', 'Сравнение влияния скремблирования', 'Color', 'w', 'Position', [100, 100, 1000, 400]);

subplot(1,2,1);
semilogy(EbNo_dB, ber_hard_with, 'r-o', 'LineWidth', 1.5); hold on;
semilogy(EbNo_dB, ber_hard_no, 'k--s', 'LineWidth', 1.5);
grid on;
title('Жёсткое декодирование (Hard Decision)');
xlabel('Eb/N0 (дБ)');
ylabel('BER');
legend('Со скремблированием', 'Без скремблирования', 'Location', 'northeast');

subplot(1,2,2);
semilogy(EbNo_dB, ber_soft_with, 'b-o', 'LineWidth', 1.5); hold on;
semilogy(EbNo_dB, ber_soft_no, 'k--s', 'LineWidth', 1.5);
grid on;
title('Мягкое декодирование (Soft Decision)');
xlabel('Eb/N0 (дБ)');
ylabel('BER');
legend('Со скремблированием', 'Без скремблирования', 'Location', 'northeast');

sgtitle('Влияние скремблирования на BER для QAM-64');

function ber = run_sim(EbNo, maxErrs, maxBits, Mode, type, useScr)
    %% Constants
    FRM = 2400; k = 2*Mode; snr = EbNo + 10*log10(k);
    %% Processsing loop: transmitter, channel model and receiver
    noiseVar = 10.^(0.1.*(-snr));
    numErrs = 0; numBits = 0; nS = 0;
    while (numErrs < maxErrs && numBits < maxBits)
        u = randi([0 1], FRM, 1);
        % Transmitter
        if useScr, t = Scrambler(u, nS);
        else, t = u; end
        tx = Modulator(t, Mode);
        % Channel
        rx = AWGNChannel(tx, snr);
        % Receiver
        if strcmp(type, 'hard')
            r = DemodulatorHard(rx, Mode);
            if useScr, y = DescramblerHard(r, nS); else, y = r(1:FRM); end
        else
            r = DemodulatorSoft(rx, Mode, noiseVar);
            if useScr, r_dec = DescramblerSoft(r, nS);
            else, r_dec = r; end
            y = double(r_dec < 0); % Recover output bits
        end
        % Measurements
        numErrs = numErrs + sum(y ~= u);
        numBits = numBits + FRM;
    end
    ber = numErrs / numBits;
end