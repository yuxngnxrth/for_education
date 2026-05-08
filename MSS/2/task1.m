clear; close all; clc;

EbNo_dB = 0:2:12;
maxErrs = 500;
maxBits = 1e7;

hard_ber = zeros(size(EbNo_dB));
soft_ber = zeros(size(EbNo_dB));

fprintf('BER для QAM-64 в канале AWGN\n');
for i = 1:length(EbNo_dB)
    fprintf('Eb/No = %d dB\n', EbNo_dB(i));
    
    [hard_ber(i), ~] = lab2_ex01(EbNo_dB(i), maxErrs, maxBits);
    [soft_ber(i), ~] = lab2_ex02(EbNo_dB(i), maxErrs, maxBits);
    
    fprintf('  Hard BER: %.2e\n', hard_ber(i));
    fprintf('  Soft BER: %.2e\n', soft_ber(i));
end

figure;
semilogy(EbNo_dB, hard_ber, 'r-o', 'LineWidth', 1.5, 'MarkerSize', 8);
hold on;
semilogy(EbNo_dB, soft_ber, 'b-s', 'LineWidth', 1.5, 'MarkerSize', 8);
grid on;

xlabel('Eb/N0 (dB)');
ylabel('BER');
legend('Жёсткое декодирование', 'Мягкое декодирование', 'Location', 'northeast');
title('BER для QAM-64 в канале AWGN');