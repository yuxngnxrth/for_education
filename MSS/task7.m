warning('off','all')

EbNo = 1;
maxNumErrs = 100;
maxNumBits = 1e5;

% tic; 
% [ber_fix, bits_fix] = lab2_ex04(EbNo, maxNumErrs, maxNumBits); 
% t_fix = toc;

% tic; 
% [ber_crc, bits_crc] = lab2_ex04_crc(EbNo, maxNumErrs, maxNumBits); 
% t_crc = toc;

% fprintf('Время (фикс. итерации): %.4f с\n', t_fix);
% fprintf('Время (с CRC): %.4f с\n', t_crc);
% fprintf('Экономия времени: %.1f%%\n', (1 - t_crc/t_fix)*100);

%% Моделирование BER
EbNo_range = 0:0.2:1.2;
ber_fixed = zeros(size(EbNo_range));
ber_early = zeros(size(EbNo_range));

for i = 1:length(EbNo_range)
    en = EbNo_range(i);
    [ber_fixed(i), ~] = lab2_ex04(en, maxNumErrs, maxNumBits);
    [ber_early(i), ~] = lab2_ex04_crc(en, maxNumErrs, maxNumBits);
    fprintf('Eb/No = %.1f dB: ber_fixed = %.2e, ber_early = %.2e\n', en, ber_fixed(i), ber_early(i));
end

figure('Position', [100, 100, 800, 600]);
semilogy(EbNo_range, ber_fixed, '-bo', 'LineWidth', 1.5, 'MarkerSize', 8);
hold on;
semilogy(EbNo_range, ber_early, '--rx', 'LineWidth', 1.5, 'MarkerSize', 8);
grid on;
xlabel('E_b/N_0 (дБ)');
ylabel('Bit Error Rate (BER)');
title('Сравнение BER: фиксированные итерации vs досрочный выход (CRC)');
legend('Фиксированные итерации (6)', 'Досрочный выход (CRC)', 'Location', 'southwest');

ylim([1e-5, 1]);