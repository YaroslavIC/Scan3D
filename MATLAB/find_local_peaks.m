function peaks = find_local_peaks(img)
    % Нахождение локальных максимумов с использованием imregionalmax
    binary_peaks = imregionalmax(img);
    
    % Можно также использовать дополнительную фильтрацию по порогу
    threshold = graythresh(img) * 0.5; % Адаптивный порог
    bw = img > threshold;
    
    % Комбинируем результаты
    binary_peaks = binary_peaks & bw;
    
    % Получаем координаты пиков
    [y, x] = find(binary_peaks);
    peaks = [y, x];
    
    % Фильтрация пиков по минимальному расстоянию (опционально)
    if size(peaks, 1) > 1
        min_distance = 4; % Минимальное расстояние между пиками
        peaks = filter_peaks_by_distance(peaks, min_distance);
    end
    
    fprintf('Найдено %d потенциальных точек\n', size(peaks, 1));
end