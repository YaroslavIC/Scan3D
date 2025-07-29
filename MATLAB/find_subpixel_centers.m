function [all_centers]=find_subpixel_centers(filename)
    % Загрузка изображения
    if filename==""
      [filename, pathname] = uigetfile('*.jpg', 'Выберите изображение JPEG');
      if isequal(filename, 0)
          disp('Загрузка отменена');
          return;
      end

      filename = fullfile(pathname, filename);
    end
    
    % Чтение изображения
    img = imread(filename);
    
    % Преобразование в градации серого, если изображение цветное
    if size(img, 3) == 3
        img_gray = rgb2gray(img);
    else
        img_gray = img;
    end
    
    % Преобразование в двойную точность
    img_double = im2double(img_gray);
    
    % Нахождение локальных максимумов (пиков)
    peaks = find_local_peaks(img_double);
    
    % Визуализация исходного изображения
     
    imshow(img_double, []);
    hold on;
    title('Найденные центры точек');
    
    % Массив для хранения всех субпиксельных центров
    all_centers = [];
    
    % Обработка каждого найденного пика
    for i = 1:size(peaks, 1)
        y0 = peaks(i, 1);
        x0 = peaks(i, 2);
        
        % Находим субпиксельный центр для этой точки
        [x_sub, y_sub] = find_single_subpixel_center(img_double, x0, y0);
        
        if ~isnan(x_sub) && ~isnan(y_sub)
            % Сохраняем результат
            all_centers = [all_centers; x_sub, y_sub];
            
            % Отображаем результаты
            plot(x0, y0, 'ro', 'MarkerSize', 8, 'LineWidth', 2); % Пиксельный центр
            plot(x_sub, y_sub, 'b+', 'MarkerSize', 15, 'LineWidth', 2); % Субпиксельный центр
            text(x_sub + 5, y_sub, sprintf('(%.2f, %.2f)', x_sub, y_sub), ...
                 'Color', 'yellow', 'FontSize', 8, 'BackgroundColor', 'black');
        end
    end
    
    hold off;
    
    % Вывод результатов в командное окно
    fprintf('Найдено %d центров точек:\n', size(all_centers, 1));
    for i = 1:size(all_centers, 1)
        fprintf('Точка %d: (%.3f, %.3f)\n', i, all_centers(i, 1), all_centers(i, 2));
    end
    
    % Сохранение результатов (опционально)
    save('centers.mat', 'all_centers');
    fprintf('Результаты сохранены в файл centers.mat\n');
end
