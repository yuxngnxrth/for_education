clear; close all; clc;
EbNo_dB = 0:2:10;
maxErrs = 500;
maxBits = 1e7;

ber_hard_sc = zeros(size(EbNo_dB));
ber_hard_no_sc = zeros(size(EbNo_dB));
ber_soft_sc = zeros(size(EbNo_dB));
ber_soft_no_sc = zeros(size(EbNo_dB));

for i = 1:length(EbNo_dB)
    fprintf('Eb/No = %d dB\n', EbNo_dB(i));
    ber_hard_sc(i) = lab2_ex01(EbNo_dB(i), maxErrs, maxBits, true);
    ber_hard_no_sc(i) = lab2_ex01(EbNo_dB(i), maxErrs, maxBits, false);
    ber_soft_sc(i) = lab2_ex02(EbNo_dB(i), maxErrs, maxBits, true);
    ber_soft_no_sc(i) = lab2_ex02(EbNo_dB(i), maxErrs, maxBits, false);
end

figure('Name', 'Сравнение влияния скремблирования', 'Color', 'w', 'Position', [100, 100, 1000, 400]);
subplot(1,2,1);
semilogy(EbNo_dB, ber_hard_sc, 'r-o', 'LineWidth', 1.5); hold on;
semilogy(EbNo_dB, ber_hard_no_sc, 'k--s', 'LineWidth', 1.5);
grid on;
title('Жёсткое декодирование (Hard Decision)');
xlabel('Eb/N0 (дБ)');
ylabel('BER');
legend('Со скремблированием', 'Без скремблирования', 'Location', 'northeast');
subplot(1,2,2);
semilogy(EbNo_dB, ber_soft_sc, 'b-o', 'LineWidth', 1.5); hold on;
semilogy(EbNo_dB, ber_soft_no_sc, 'k--s', 'LineWidth', 1.5);
grid on;
title('Мягкое декодирование (Soft Decision)');
xlabel('Eb/N0 (дБ)');
ylabel('BER');
legend('Со скремблированием', 'Без скремблирования', 'Location', 'northeast');
sgtitle('Влияние скремблирования на BER для 64-QAM');
