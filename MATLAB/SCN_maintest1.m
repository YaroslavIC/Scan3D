
% Запуск функции
filename = "APDE-BELICE-850-2019.jpg";
 all_centers = find_subpixel_centers(filename);

I=imread(filename);
figure(1); hold on;
imshow(I);
 hold on;

distance = [];
angle  = [];
fpoint=[];

for i=1:size(all_centers,1)
  for j=1:size(all_centers,1)
    distance(i,j) = sqrt((all_centers(i,1) - all_centers(j,1))^2+(all_centers(i,1) - all_centers(j,1))^2);
    fpoint(i,j).d=distance(i,j);
    
    if (i~=j) 
        angle(i,j) =  atan2(all_centers(i,1) - all_centers(j,1),all_centers(i,2) - all_centers(j,2))/pi*180;
        fpoint(i,j).a=angle(i,j);
    end   

  end    
end  

% for i=1:size(all_centers,1)-1
%   for j=i+1:size(all_centers,1)
%   if distance(i,j)<10
% end

for i=1:size(all_centers,1)
  plot(all_centers(i,1),all_centers(i,2),'+g')
end  