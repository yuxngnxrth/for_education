% Параметры
blockSize = 1000; % Длина информационного блока
uLength = 3 * blockSize + 12; % Корректная длина LLR для LTE
iters = [1, 2, 4, 6, 8, 10]; % Количество итераций

% Подготовка данных
u = randn(uLength, 1); 
indices = randperm(blockSize)'; 
times = zeros(length(iters), 1);

fprintf('Итерации | Время (с)\n');
fprintf('-------------------\n');

for i = 1:length(iters)
    clear TurboDecoder; 
    
    tic;
    y = TurboDecoder(u, indices, iters(i));
    times(i) = toc;
    
    fprintf('%8d | %.6f\n', iters(i), times(i));
end
