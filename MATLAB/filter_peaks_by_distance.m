function filtered_peaks = filter_peaks_by_distance(peaks, min_dist)
    % Простая фильтрация пиков по минимальному расстоянию
    filtered_peaks = peaks(1, :); % Первый пик всегда сохраняем
    
    for i = 2:size(peaks, 1)
        current_peak = peaks(i, :);
        distances = sqrt(sum((filtered_peaks - current_peak).^2, 2));
        
        % Если текущий пик достаточно далеко от всех уже сохраненных
        if all(distances > min_dist)
            filtered_peaks = [filtered_peaks; current_peak];
        end
    end
end