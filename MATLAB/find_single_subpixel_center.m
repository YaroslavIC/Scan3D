function [x_subpixel, y_subpixel] = find_single_subpixel_center(img, x0, y0)
    % Размер окна вокруг пика
    win_size = 7; % Нечетное число
    half_win = floor(win_size / 2);
    
    % Границы подобласти
    x_start = max(1, x0 - half_win);
    x_end = min(size(img, 2), x0 + half_win);
    y_start = max(1, y0 - half_win);
    y_end = min(size(img, 1), y0 + half_win);
    
    % Извлечение подобласти
    subregion = img(y_start:y_end, x_start:x_end);
    
    % Проверка размера подобласти
    if size(subregion, 1) < 3 || size(subregion, 2) < 3
        x_subpixel = NaN;
        y_subpixel = NaN;
        return;
    end
    
    % Создание координатной сетки для подобласти
    [Y_sub, X_sub] = meshgrid(1:size(subregion, 2), 1:size(subregion, 1));
    
    % Преобразование в векторы
    x_data = X_sub(:);
    y_data = Y_sub(:);
    z_data = subregion(:);
    
    % Смещение координат относительно всего изображения
    x_data = x_data + x_start - 1;
    y_data = y_data + y_start - 1;
    
    % Исключение нулевых значений
    valid_idx = z_data > 0;
    x_data = x_data(valid_idx);
    y_data = y_data(valid_idx);
    z_data = z_data(valid_idx);
    
    if length(z_data) < 5
        x_subpixel = NaN;
        y_subpixel = NaN;
        return;
    end
    
    % Начальные приближения
    max_val = max(z_data(:));
    initial_guess = [max_val, x0, y0, 1.5, 1.5, median(z_data(:))]; % [A, x0, y0, sigma_x, sigma_y, offset]
    
    % Ограничения параметров
    lb = [0, x0-3, y0-3, 0.1, 0.1, 0]; % Нижние границы
    ub = [inf, x0+3, y0+3, 5, 5, max_val]; % Верхние границы
    
    % Модель 2D-гауссианы
    gauss2D = @(params, x, y) params(1) * exp(-((x - params(2)).^2 / (2*params(4)^2) + ...
                                                (y - params(3)).^2 / (2*params(5)^2))) + params(6);
    
    % Функция ошибки
    objective = @(params) gauss2D(params, x_data, y_data) - z_data;
    
    % Оптимизация
    try
        options = optimoptions('lsqnonlin', 'Display', 'off', 'MaxFunctionEvaluations', 1000);
        params_fitted = lsqnonlin(objective, initial_guess, lb, ub, options);
        
        % Результаты
        x_subpixel = params_fitted(2);
        y_subpixel = params_fitted(3);
        
        % Проверка адекватности подгонки (опционально)
        fitted_values = gauss2D(params_fitted, x_data, y_data);
        r_squared = 1 - sum((z_data - fitted_values).^2) / sum((z_data - mean(z_data)).^2);
        
        if r_squared < 0.5 % Плохая подгонка
            x_subpixel = NaN;
            y_subpixel = NaN;
        end
        
    catch
        % Если оптимизация не удалась
        x_subpixel = NaN;
        y_subpixel = NaN;
    end
end