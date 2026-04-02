function y = Modulator(u, Mode)
    % Приведение к double обязательно для корректной работы qammod/pskmod
    u = double(u); 
    
    % Используем persistent для хранения таблиц соответствия
    persistent map16 map64
    if isempty(map16)
        map16 = [11 10 14 15 9 8 12 13 1 0 4 5 3 2 6 7];
        map64 = [47 46 42 43 59 58 62 63 45 44 40 41 57 56 60 61 ...
                 37 36 32 33 49 48 52 53 39 38 34 35 51 50 54 55 7 6 2 3 19 18 22 23 ...
                 5 4 0 1 17 16 20 21 13 12 8 9 25 24 28 29 15 14 10 11 27 26 30 31];
    end
    
    switch Mode
        case 1
            % QPSK: Custom mapping [0 2 3 1]
            y = pskmod(u, 4, pi/4, [0 2 3 1], 'InputType', 'bit');
        case 2
            % 16-QAM
            y = qammod(u, 16, map16, 'UnitAveragePower', true, 'InputType', 'bit');
        case 3
            % 64-QAM
            y = qammod(u, 64, map64, 'UnitAveragePower', true, 'InputType', 'bit');
    end
end