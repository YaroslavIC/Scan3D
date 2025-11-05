%% =================== ПАРАМЕТРЫ ДЛЯ ПОЛЬЗОВАТЕЛЯ ===================
% Укажите пути к папкам с изображениями (обязательно)
leftImagesDir  = 'C:\Users\HeroPC\git\misc\Scan3D\3DEndo\camL';    % Папка с изображениями левой камеры
rightImagesDir = 'C:\Users\HeroPC\git\misc\Scan3D\3DEndo\camR';   % Папка с изображениями правой камеры

% Параметры шахматной доски (обязательно)
patternWidth  = 10;    % Количество внутренних углов по горизонтали (например, 9)
patternHeight = 7;    % Количество внутренних углов по вертикали (например, 6)
squareSize    = 25;   % Физический размер квадрата в миллиметрах (например, 25 мм)

% Форматы изображений для поиска (по умолчанию — jpg, jpeg, png)
imageExtensions = {'*.jpg', '*.jpeg', '*.png'};

% Опции калибровки (можно оставить по умолчанию)
estimateSkew                = false;
estimateTangentialDistortion = true;
% ================================================================

%% 1. Загрузка и сортировка имён файлов
fprintf('Поиск изображений в папках...\n');

imageFilesLeft  = {};
imageFilesRight = {};

% Собираем файлы из всех указанных расширений
for e = 1:length(imageExtensions)
    filesL = dir(fullfile(leftImagesDir,  imageExtensions{e}));
    filesR = dir(fullfile(rightImagesDir, imageExtensions{e}));
    imageFilesLeft  = [imageFilesLeft;  {filesL.name}];
    imageFilesRight = [imageFilesRight; {filesR.name}];
end

% Сортируем лексикографически (встроенная сортировка)
imageFilesLeft  = sort(imageFilesLeft);
imageFilesRight = sort(imageFilesRight);

% Приводим к одинаковой длине (берём минимальное общее количество)
numPairs = min(length(imageFilesLeft), length(imageFilesRight));

if numPairs == 0
    error('Не найдено изображений в одной из папок. Проверьте пути и расширения.');
end

fprintf('Найдено %d изображений в левой папке и %d в правой.\n', ...
    length(imageFilesLeft), length(imageFilesRight));
if length(imageFilesLeft) ~= length(imageFilesRight)
    fprintf('Внимание: количество изображений не совпадает. Будет использовано %d пар.\n', numPairs);
end

%% 2. Подготовка мировых координат шахматной доски
worldPoints = generateCheckerboardPoints([patternWidth, patternHeight], squareSize);
numExpectedCorners = patternWidth * patternHeight;

%% 3. Обработка всех пар изображений
imagePointsLeft  = [];
imagePointsRight = [];
worldPointsCell  = {};

fprintf('Обработка изображений...\n');
for i = 1:numPairs
    % Загрузка изображений
    imgL = imread(fullfile(leftImagesDir,  imageFilesLeft{i}));
    imgR = imread(fullfile(rightImagesDir, imageFilesRight{i}));

    % Детекция углов шахматной доски
    % В R2024a detectCheckerboardPoints возвращает [imagePoints, boardSize, imagesUsed]
    % Но при подаче одного изображения — удобнее использовать упрощённый синтаксис
    [cornersL, boardSizeL] = detectCheckerboardPoints(imgL);
    [cornersR, boardSizeR] = detectCheckerboardPoints(imgR);

    % Проверка: найдена ли полная доска нужного размера?
    foundL = ~isempty(cornersL) && ...
             isequal(boardSizeL, [patternHeight, patternWidth]); % обратите внимание: [H, W]
    foundR = ~isempty(cornersR) && ...
             isequal(boardSizeR, [patternHeight, patternWidth]);

    if foundL && foundR
        imagePointsLeft  = [imagePointsLeft,  cornersL];
        imagePointsRight = [imagePointsRight, cornersR];
        worldPointsCell{end+1} = worldPoints; %#ok<AGROW>
        fprintf('Пара %d: успешно обработана.\n', i);
    else
        fprintf('Пара %d: шахматная доска не найдена или неверного размера.\n', i);
    end
end

if isempty(worldPointsCell)
    error('Ни одна пара изображений не содержит полной шахматной доски указанного размера.');
end

fprintf('Всего успешно обработано %d пар.\n', length(worldPointsCell));

%% 4. Стереокалибровка
fprintf('Выполняется калибровка стереосистемы...\n');

% Настройки
opts = stereoCameraCalibrator('EstimateSkew', estimateSkew, ...
                              'EstimateTangentialDistortion', estimateTangentialDistortion);

% Выполняем калибровку
stereoParams = estimateStereoCameraParameters(...
    imagePointsLeft, imagePointsRight, worldPointsCell, ...
    'EstimateSkew', estimateSkew, ...
    'EstimateTangentialDistortion', estimateTangentialDistortion);

%% 5. Вывод результатов
reprojErrors = stereoParams.ReprojectionErrors;
meanErrorL = mean(reprojErrors(:,1));
meanErrorR = mean(reprojErrors(:,2));

fprintf('\n=== Результаты калибровки ===\n');
fprintf('Средняя ошибка репроекции:\n');
fprintf('  Левая камера:  %.3f пикс.\n', meanErrorL);
fprintf('  Правая камера: %.3f пикс.\n', meanErrorR);
fprintf('База (baseline): %.2f мм\n', stereoParams.TranslationOfCamera2(1)); % X-смещение в мм

%% 6. Сохранение параметров
save('stereoParams.mat', 'stereoParams');
fprintf('\nПараметры калибровки сохранены в файл: stereoParams.mat\n');

%% 7. Визуализация (опционально)
figure;
showExtrinsics(stereoParams, 'Camera', 'left');
title('Положения шахматной доски — левая камера');

figure;
showExtrinsics(stereoParams, 'Camera', 'right');
title('Положения шахматной доски — правая камера');

% Пример ректификации последней пары
if ~isempty(imageFilesLeft)
    imgL = imread(fullfile(leftImagesDir,  imageFilesLeft{end}));
    imgR = imread(fullfile(rightImagesDir, imageFilesRight{end}));
    
    % Ректифицируем
    [imgL_rect, imgR_rect] = rectifyStereoImages(imgL, imgR, stereoParams);
    
    % Отображаем ректифицированные изображения
    figure;
    imshow(stereoAnaglyph(imgL_rect, imgR_rect));
    title('Ректифицированная анаглиф-пара (красный-голубой)');
end