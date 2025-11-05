%stereoCameraCalibrator('C:\Users\HeroPC\git\misc\Scan3D\3DEndo\camL','C:\Users\HeroPC\git\misc\Scan3D\3DEndo\camR',17.8)

load 'C:\Users\HeroPC\git\misc\Scan3D\MATLAB\stparams.mat'

leftImagesDir  = 'C:\Users\HeroPC\git\misc\Scan3D\3DEndo\stereopair\cam_L*.png';    % Папка с изображениями левой камеры
rightImagesDir = 'C:\Users\HeroPC\git\misc\Scan3D\3DEndo\stereopair\cam_R*.png';   % Папка с изображениями правой камеры

filesL = dir(leftImagesDir);
filesR = dir(rightImagesDir);

Ja =[];
for i=1:length(filesL)

    imgR = imread(strcat(filesR(i).folder,'\',filesR(i).name));
    imgL = imread(strcat(filesL(i).folder,'\',filesL(i).name));


    [frameLeftRect, frameRightRect, reprojectionMatrix] = ...
        rectifyStereoImages(imgR, imgL, stereoParams);

    figure(1);
    imshow(stereoAnaglyph(frameLeftRect, frameRightRect));
    title("Rectified Video Frames");
    axis equal

    frameLeftGray  = im2gray(frameLeftRect);
    frameRightGray = im2gray(frameRightRect);

    disparityMap = disparitySGM(frameLeftGray, frameRightGray);
    figure(2);
    imshow(disparityMap, [0, 64],'InitialMagnification',50);
    axis equal
    title("Disparity Map");
    colormap jet
    colorbar



    xyzPoints = reconstructScene(disparityMap,reprojectionMatrix);
    Z = xyzPoints(:,:,3);

    [J1, J2, reprojectionMatrix] = rectifyStereoImages(imgR,imgL,stereoParams);

    maxDepth  = 10000;

    validDepth = (Z > 0) & (Z < maxDepth) & isfinite(Z);
    mask = repmat(validDepth, [1, 1, 3]);
    
     Ja(i).J1 = J1;
     J1(~mask) = 0;

    figure(3);
    imshow(J1,'InitialMagnification',50);

    Ja(i).Z = Z;
    Ja(i).mask = mask(:,:,1);

end

mask_a= zeros(10,size(Ja(1).mask,1), size(Ja(1).mask,2) );
z_a = zeros(10,size(Ja(1).mask,1), size(Ja(1).mask,2) );
for i=1:10 
  mask_a(i,:,:) =  Ja(i).mask;
  z_a(i,:,:) =  Ja(i).Z;
end  

figure(5);
imagesc(squeeze(mean(mask_a,1)));

z_combined = zeros(size(Ja(1).mask,1),size(Ja(1).mask,2));
image_combined = uint8(zeros(size(Ja(1).mask,1),size(Ja(1).mask,2),3));
for x=1:size(Ja(1).mask,1)
  x / size(Ja(1).mask,1)  
  for y=1:size(Ja(1).mask,2)
   mask_a_v =  mask_a(:,x,y) ;
   z_a_v = z_a( : , x,y);
   z_combined(x,y) = mean(z_a_v ((mask_a_v)>0));

   if z_combined(x,y)>0 
     image_combined(x,y,:) = uint8(Ja(1).J1(x,y,:));
   end  
  end    
end
figure(6);
imagesc(z_combined);
figure(7);
imagesc(image_combined);

 